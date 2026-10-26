#!/usr/bin/env python3
"""Membina fail POI (petrol, makan, masjid/surau, tandas, ATM, hospital) untuk carian berdekatan secara offline.

Sumber (kedua-duanya percuma):
  1. OpenStreetMap: ekstrak Geofabrik yang sama dengan pek tile. Diutamakan (nama dan tag komuniti).
  2. Overture Maps Places: menambah tempat yang tiada dalam OSM. Hanya confidence >= --min-confidence.

Penyahduaan: tempat Overture dibuang jika ada tempat OSM kategori sama dalam 60 m. Dalam satu sumber, tempat
berkategori sama dan bernama sama dalam 30 m dianggap satu.

Keluaran dalam <outdir>:
  pois-<versi>.ndjson.gz   satu baris JSON setiap tempat: [kod_kategori, lat, lon, "nama"]
  manifest.json            (jika ada) ditambah medan `poi` {file, sizeBytes, sha256, count, counts}

Penggunaan: build_pois.py <osm.pbf> <outdir> <versi-pek> [--overture-release R] [--min-confidence 0.6] [--no-overture]
"""
import argparse
import gzip
import hashlib
import json
import math
import os
import sys

# Kod kategori: mesti sama dengan PoiCategory.code dalam app (app/lib/features/poi/domain/poi.dart).
CATEGORIES = {"fuel": 0, "food": 1, "mosque": 2, "toilets": 3, "atm": 4, "hospital": 5}

# Kotak Malaysia (barat, selatan, timur, utara) dan kotak Singapura (dikecualikan).
W, S, E, N = 99.6, 0.8, 119.3, 7.4
SG = (103.6, 1.15, 104.1, 1.48)

DEDUPE_CROSS_M = 60.0
DEDUPE_SAME_M = 30.0


def in_singapore(lat, lon):
    return SG[0] <= lon <= SG[2] and SG[1] <= lat <= SG[3]


def osm_category(tags):
    """Kategori app daripada tag OSM, atau None."""
    a = tags.get("amenity")
    if a == "fuel":
        return "fuel"
    if a in ("restaurant", "fast_food", "cafe", "food_court"):
        return "food"
    if a == "place_of_worship" and tags.get("religion") == "muslim":
        return "mosque"
    if a == "toilets":
        return "toilets"
    if a == "atm":
        return "atm"
    if a == "hospital":
        return "hospital"
    return None


def overture_category(primary):
    """Kategori app daripada `categories.primary` Overture, atau None."""
    if not primary:
        return None
    if primary == "gas_station":
        return "fuel"
    if primary == "mosque":
        return "mosque"
    if primary == "public_toilet":
        return "toilets"
    if primary == "atm":
        return "atm"
    if primary == "hospital":
        return "hospital"
    if primary in ("restaurant", "cafe", "coffee_shop", "food_court") or primary.endswith("_restaurant"):
        return "food"
    return None


def haversine_m(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


class Grid:
    """Indeks grid mudah untuk 'adakah ada titik dalam M meter?'. Sel ~55 m, jadi 3x3 sel meliputi 60 m."""

    CELL = 0.0005

    def __init__(self):
        self.cells = {}

    def _key(self, lat, lon):
        return int(math.floor(lat / self.CELL)), int(math.floor(lon / self.CELL))

    def add(self, lat, lon, name=""):
        self.cells.setdefault(self._key(lat, lon), []).append((lat, lon, name))

    def near(self, lat, lon, meters, same_name=None):
        ci, cj = self._key(lat, lon)
        reach = max(1, int(math.ceil(meters / 55.0)))
        for di in range(-reach, reach + 1):
            for dj in range(-reach, reach + 1):
                for la, lo, nm in self.cells.get((ci + di, cj + dj), ()):
                    if same_name is not None and nm.strip().lower() != same_name.strip().lower():
                        continue
                    if haversine_m(lat, lon, la, lo) <= meters:
                        return True
        return False


def merge(osm_items, overture_items):
    """Menggabungkan senarai (kategori, lat, lon, nama). OSM diutamakan. Memulangkan (hasil, statistik)."""
    result = []
    grids = {c: Grid() for c in CATEGORIES}
    stats = {c: {"osm": 0, "overture_added": 0, "overture_dup": 0} for c in CATEGORIES}

    for cat, lat, lon, name in osm_items:
        if grids[cat].near(lat, lon, DEDUPE_SAME_M, same_name=name) and name:
            continue
        grids[cat].add(lat, lon, name)
        result.append((cat, lat, lon, name))
        stats[cat]["osm"] += 1

    osm_grids = {c: Grid() for c in CATEGORIES}
    for cat, lat, lon, _ in result:
        osm_grids[cat].add(lat, lon)

    for cat, lat, lon, name in overture_items:
        if osm_grids[cat].near(lat, lon, DEDUPE_CROSS_M):
            stats[cat]["overture_dup"] += 1
            continue
        if name and grids[cat].near(lat, lon, DEDUPE_SAME_M, same_name=name):
            stats[cat]["overture_dup"] += 1
            continue
        grids[cat].add(lat, lon, name)
        result.append((cat, lat, lon, name))
        stats[cat]["overture_added"] += 1
    return result, stats


def keep(cat, name):
    """Makan tanpa nama tidak berguna kepada pengguna; kategori lain boleh tanpa nama (UI memaparkan jenis)."""
    return cat != "food" or bool(name)


def read_osm(pbf):
    import osmium

    class H(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            self.items = []

        def _add(self, tags, lat, lon):
            t = {x.k: x.v for x in tags}
            cat = osm_category(t)
            if cat is None or in_singapore(lat, lon):
                return
            name = (t.get("name") or t.get("name:ms") or t.get("brand") or t.get("operator") or "").strip()
            if keep(cat, name):
                self.items.append((cat, lat, lon, name))

        def node(self, n):
            if n.tags and n.location.valid():
                self._add(n.tags, n.location.lat, n.location.lon)

        def way(self, w):
            if not w.tags or "amenity" not in {x.k for x in w.tags}:
                return
            try:
                pts = [(n.lat, n.lon) for n in w.nodes if n.location.valid()]
            except osmium.InvalidLocationError:
                return
            if pts:
                self._add(w.tags, sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))

    h = H()
    h.apply_file(pbf, locations=True)
    return h.items


def read_overture(release, min_confidence):
    import duckdb

    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")
    src = f"s3://overturemaps-us-west-2/release/{release}/theme=places/type=place/*"
    rows = con.execute(
        f"""
        SELECT bbox.ymin, bbox.xmin, names.primary, confidence, categories.primary
        FROM read_parquet('{src}', hive_partitioning=1)
        WHERE bbox.xmin BETWEEN {W} AND {E} AND bbox.ymin BETWEEN {S} AND {N}
          AND confidence >= {min_confidence}
        """
    ).fetchall()
    items = []
    for lat, lon, name, _conf, primary in rows:
        cat = overture_category(primary)
        if cat is None or in_singapore(lat, lon):
            continue
        name = (name or "").strip()
        if keep(cat, name):
            items.append((cat, lat, lon, name))
    return items


def write(result, outdir, version):
    os.makedirs(outdir, exist_ok=True)
    name = f"pois-{version}.ndjson.gz"
    path = os.path.join(outdir, name)
    counts = {c: 0 for c in CATEGORIES}
    with gzip.open(path, "wt", encoding="utf-8", compresslevel=9) as f:
        for cat, lat, lon, nm in sorted(result, key=lambda r: (CATEGORIES[r[0]], r[1], r[2])):
            counts[cat] += 1
            f.write(json.dumps([CATEGORIES[cat], round(lat, 6), round(lon, 6), nm], ensure_ascii=False, separators=(",", ":")) + "\n")
    with open(path, "rb") as f:
        sha = hashlib.sha256(f.read()).hexdigest()
    meta = {"file": name, "sizeBytes": os.path.getsize(path), "sha256": sha, "count": len(result), "counts": counts}
    manifest = os.path.join(outdir, "manifest.json")
    if os.path.exists(manifest):
        m = json.load(open(manifest))
        m["poi"] = meta
        json.dump(m, open(manifest, "w"), indent=2)
        open(manifest, "a").write("\n")
    return meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pbf")
    ap.add_argument("outdir")
    ap.add_argument("version")
    ap.add_argument("--overture-release", default="2026-10-21.0")
    ap.add_argument("--min-confidence", type=float, default=0.6)
    ap.add_argument("--no-overture", action="store_true")
    a = ap.parse_args()

    print("[OSM] membaca ...", flush=True)
    osm = read_osm(a.pbf)
    print(f"[OSM] {len(osm):,} tempat", flush=True)
    ovt = []
    if not a.no_overture:
        print(f"[Overture] {a.overture_release} confidence>={a.min_confidence} ...", flush=True)
        ovt = read_overture(a.overture_release, a.min_confidence)
        print(f"[Overture] {len(ovt):,} tempat", flush=True)
    result, stats = merge(osm, ovt)
    meta = write(result, a.outdir, a.version)
    print(json.dumps({"stats": stats, "poi": meta}, indent=2))
    # Pengawal kewarasan: pembinaan yang menghasilkan sangat sedikit POI hampir pasti gagal senyap.
    if meta["count"] < 20000:
        sys.exit(f"GAGAL: hanya {meta['count']} POI (jangkaan >> 20,000)")


if __name__ == "__main__":
    main()
