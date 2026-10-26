#!/usr/bin/env python3
"""Mengukur liputan POI (petrol, makan, masjid/surau, tandas, ATM, hospital) di Malaysia daripada dua sumber percuma:
OpenStreetMap (ekstrak Geofabrik yang sama dengan pek tile) dan Overture Maps Places.

Tujuan: memutuskan sumber mana yang layak dimasukkan ke app berdasarkan ukuran, bukan andaian.
Tanda aras luaran: TM ONE SmartMap (2022): ~6,585 masjid + ~17,069 surau.

Penggunaan: .venv/bin/python measure.py <osm.pbf> [overture-release]
"""
import math
import sys
import time

import duckdb
import osmium

PBF = sys.argv[1]
RELEASE = sys.argv[2] if len(sys.argv) > 2 else "2026-10-21.0"

# Kotak Malaysia (barat, selatan, timur, utara). Termasuk sedikit Singapura/Brunei; dilaporkan berasingan di bawah.
W, S, E, N = 99.6, 0.8, 119.3, 7.4


def in_singapore(lat, lon):
    return 1.15 <= lat <= 1.48 and 103.6 <= lon <= 104.1


def region(lat, lon):
    if in_singapore(lat, lon):
        return "SG"
    return "peninsular" if lon < 105 else "borneo"


# ---------------------------------------------------------------- OSM
OSM_RULES = {
    "fuel": lambda t: t.get("amenity") == "fuel",
    "food": lambda t: t.get("amenity") in ("restaurant", "fast_food", "cafe", "food_court"),
    "mosque/surau": lambda t: t.get("amenity") == "place_of_worship" and t.get("religion") == "muslim",
    "toilets": lambda t: t.get("amenity") == "toilets",
    "atm": lambda t: t.get("amenity") == "atm",
    "hospital": lambda t: t.get("amenity") == "hospital",
}


class Collector(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.items = {k: [] for k in OSM_RULES}

    def _add(self, tags, lat, lon):
        t = {x.k: x.v for x in tags}
        for label, ok in OSM_RULES.items():
            if ok(t):
                self.items[label].append((lat, lon, t.get("name") or t.get("name:ms") or t.get("brand") or "", "opening_hours" in t))

    def node(self, n):
        if n.tags and n.location.valid():
            self._add(n.tags, n.location.lat, n.location.lon)

    def way(self, w):
        if not w.tags:
            return
        if not any(k in ("amenity",) for k in (x.k for x in w.tags)):
            return
        try:
            nodes = [n for n in w.nodes if n.location.valid()]
        except osmium.InvalidLocationError:
            return
        if not nodes:
            return
        lat = sum(n.lat for n in nodes) / len(nodes)
        lon = sum(n.lon for n in nodes) / len(nodes)
        self._add(w.tags, lat, lon)


t0 = time.time()
print(f"[OSM] membaca {PBF} ...", flush=True)
h = Collector()
h.apply_file(PBF, locations=True)
print(f"[OSM] siap dalam {time.time() - t0:.0f}s", flush=True)

osm = h.items

# ---------------------------------------------------------------- Overture
print(f"[Overture] pertanyaan {RELEASE} (bbox Malaysia) ...", flush=True)
con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")
src = f"s3://overturemaps-us-west-2/release/{RELEASE}/theme=places/type=place/*"
t0 = time.time()
cats = con.execute(f"""
    SELECT categories.primary AS cat, count(*) AS n
    FROM read_parquet('{src}', hive_partitioning=1)
    WHERE bbox.xmin BETWEEN {W} AND {E} AND bbox.ymin BETWEEN {S} AND {N}
    GROUP BY 1 ORDER BY n DESC
""").fetchall()
print(f"[Overture] senarai kategori dalam {time.time() - t0:.0f}s; jumlah tempat = {sum(n for _, n in cats):,}", flush=True)
interesting = [c for c in cats if any(w in (c[0] or "") for w in ("gas_station", "mosque", "surau", "restaurant", "fast_food", "cafe", "coffee", "toilet", "atm", "hospital", "food_court", "petrol", "fuel"))]
print("[Overture] kategori berkaitan:", [(c, f"{n:,}") for c, n in interesting[:25]])

OVT = {
    "fuel": ("gas_station",),
    "food": ("restaurant", "fast_food_restaurant", "cafe", "coffee_shop", "food_court", "malaysian_restaurant", "halal_restaurant"),
    "mosque/surau": ("mosque",),
    "toilets": ("public_toilet",),
    "atm": ("atm",),
    "hospital": ("hospital",),
}
ovt = {}
for label, names in OVT.items():
    present = [c for c, _ in cats if c in names]
    if label == "food":
        # semua kategori yang mengandungi 'restaurant' atau 'cafe' atau 'food_court' (taksonomi Overture mempunyai ratusan jenis)
        present = [c for c, _ in cats if c and (c.endswith("_restaurant") or c in ("restaurant", "cafe", "coffee_shop", "food_court", "fast_food_restaurant"))]
    if not present:
        ovt[label] = []
        continue
    inlist = ",".join("'" + p + "'" for p in present)
    rows = con.execute(f"""
        SELECT bbox.ymin, bbox.xmin, names.primary, confidence, categories.primary
        FROM read_parquet('{src}', hive_partitioning=1)
        WHERE bbox.xmin BETWEEN {W} AND {E} AND bbox.ymin BETWEEN {S} AND {N}
          AND categories.primary IN ({inlist})
    """).fetchall()
    ovt[label] = rows
    print(f"[Overture] {label}: {len(rows):,} (kategori: {len(present)})", flush=True)


def grid(points, cell=0.0005):
    g = {}
    for lat, lon in points:
        g.setdefault((int(lat / cell), int(lon / cell)), []).append((lat, lon))
    return g


def hav(a, b, c, d):
    r = 6371000.0
    p1, p2 = math.radians(a), math.radians(c)
    dphi = p2 - p1
    dl = math.radians(d - b)
    x = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(x))


def near(g, lat, lon, m=60, cell=0.0005):
    ci, cj = int(lat / cell), int(lon / cell)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            for la, lo in g.get((ci + di, cj + dj), ()):
                if hav(lat, lon, la, lo) <= m:
                    return True
    return False


print()
print(f"{'kategori':14s}{'OSM':>9s}{'  bernama':>11s}{'  jam':>7s}{'Overture':>10s}{'  conf>=.7':>11s}{'  OSM∩OVT':>10s}{'  OVT sahaja':>12s}{'  OSM sahaja':>12s}")
for label in OSM_RULES:
    o = [x for x in osm[label] if not in_singapore(x[0], x[1])]
    v = [x for x in ovt.get(label, []) if not in_singapore(x[0], x[1])]
    named = sum(1 for x in o if x[2])
    hrs = sum(1 for x in o if x[3])
    conf = sum(1 for x in v if x[3] is not None and x[3] >= 0.7)
    og = grid([(x[0], x[1]) for x in o])
    vg = grid([(x[0], x[1]) for x in v])
    both = sum(1 for x in v if near(og, x[0], x[1]))
    ovt_only = len(v) - both
    osm_only = sum(1 for x in o if not near(vg, x[0], x[1]))
    print(f"{label:14s}{len(o):9,d}{named:11,d}{hrs:7,d}{len(v):10,d}{conf:11,d}{both:10,d}{ovt_only:12,d}{osm_only:12,d}")

print("\nPeratus OSM bernama / ada jam buka:")
for label in OSM_RULES:
    o = [x for x in osm[label] if not in_singapore(x[0], x[1])]
    if o:
        print(f"  {label:14s} bernama {100*sum(1 for x in o if x[2])//len(o)}%  jam buka {100*sum(1 for x in o if x[3])//len(o)}%")

print("\nMasjid/surau (tanda aras TM ONE 2022: 6,585 masjid + 17,069 surau = 23,654):")
o = [x for x in osm["mosque/surau"] if not in_singapore(x[0], x[1])]
sur = sum(1 for x in o if any(w in x[2].lower() for w in ("surau", "musolla", "musalla", "suau")))
mas = sum(1 for x in o if any(w in x[2].lower() for w in ("masjid", "mosque")))
print(f"  OSM: {len(o):,} kesemuanya; bernama surau/musolla = {sur:,}; bernama masjid = {mas:,}")
v = [x for x in ovt.get('mosque/surau', []) if not in_singapore(x[0], x[1])]
vs = sum(1 for x in v if x[2] and any(w in x[2].lower() for w in ("surau", "musolla", "musalla")))
print(f"  Overture: {len(v):,} kesemuanya; bernama surau/musolla = {vs:,}")
print("  Gabungan (unik, jarak 60 m):", end=" ")
og = grid([(x[0], x[1]) for x in o])
extra = sum(1 for x in v if not near(og, x[0], x[1]))
print(f"{len(o) + extra:,}  =  {100 * (len(o) + extra) // 23654}% daripada tanda aras 23,654")
