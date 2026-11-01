#!/usr/bin/env python3
"""Membina indeks carian OFFLINE (SQLite + FTS4) daripada ekstrak OSM yang sama dengan pek tile.

Isi (percuma / boleh diedarkan semula — tiada Google Places API langsung):
  - penempatan: bandar, pekan, kampung, taman/kejiranan (place=*), landuse=residential bernama
  - jalan bernama (satu baris setiap nama jalan setiap ~2 km, titik tengah)
  - POI OSM: minyak, EV, masjid/surau, tandas, R&R, hospital/klinik, sekolah/universiti,
    kedai bernama (termasuk jenis biasa MY), makan, hotel, leisure, pejabat, pengangkutan, dll.
  - lapisan tambahan pilihan: tools/places/extra/*.{geojson,json} (kurasi pemilik atau Overture, dll.)

Keluaran dalam <outdir>:
  places-<versi>.sqlite.gz   pangkalan data (dimampat) untuk dimuat turun oleh app
  manifest.json              (jika ada) ditambah medan `places` {file, sizeBytes, sha256,
                             extractedSizeBytes, extractedSha256, count, schema, extraCount}

Skema (mesti sepadan dengan app/lib/features/search/domain/offline_place.dart):
  place(id INTEGER PRIMARY KEY, name TEXT, alt TEXT, kind TEXT, cat INTEGER, lat REAL, lng REAL,
        area TEXT, rank INTEGER)
  place_fts USING fts4(content="place", name, alt, area, tokenize=simple)
FTS4 + tokenizer `simple` (bukan FTS5/unicode61) kerana hanya itu dijamin ada dalam SQLite sistem
setiap versi Android; app menggunakan SQLite sistem melalui sqflite (tiada pustaka natif tambahan).

Penggunaan: build_places.py <osm.pbf> <outdir> <versi-pek> [extra_dir]
Lihat tools/places/README.md untuk jadual kemas kini dan sumber yang dibenarkan.
"""
import gzip
import hashlib
import json
import math
import os
import sqlite3
import sys
import time

SCHEMA = 1

# Kod kategori: mesti sama dengan OfflinePlaceCategory dalam app.
CAT = {
    "settlement": 0,
    "road": 1,
    "fuel": 2,
    "ev": 3,
    "mosque": 4,
    "toilets": 5,
    "rest_area": 6,
    "hospital": 7,
    "food": 8,
    "shop": 9,
    "lodging": 10,
    "tourism": 11,
    "transport": 12,
    "education": 13,
    "government": 14,
    "parking": 15,
    "other": 16,
}

PLACE_RANK = {
    "city": 100, "town": 85, "suburb": 65, "village": 55, "quarter": 50,
    "neighbourhood": 45, "hamlet": 35, "locality": 30, "island": 60,
}
ROAD_RANK = {
    "motorway": 72, "trunk": 70, "primary": 62, "secondary": 52, "tertiary": 42,
    "unclassified": 28, "residential": 24, "living_street": 20,
}

# Kategori yang tetap berguna tanpa nama (carian berdekatan / sepanjang laluan).
UNNAMED_OK = {"fuel", "ev", "toilets", "rest_area", "mosque", "parking"}


# Kedai bernama yang sering dicari di MY tetapi dulunya digugurkan (saiz kekal terkawal: perlu name/brand).
_SHOP_HIGH = {"mall", "department_store", "supermarket", "wholesale"}
_SHOP_MID = {
    "convenience", "hardware", "electronics", "car_repair", "bakery", "clothes", "fashion",
    "shoes", "mobile_phone", "computer", "furniture", "doityourself", "chemist", "optician",
    "books", "sports", "gift", "laundry", "hairdresser", "beauty", "car", "motorcycle",
    "tyres", "pet", "greengrocer", "butcher", "seafood", "florist", "jewelry", "watches",
}
_LEISURE = {
    "park", "stadium", "sports_centre", "golf_course", "water_park", "fitness_centre",
    "swimming_pool", "pitch", "track", "recreation_ground", "nature_reserve", "marina",
}
_OFFICE = {
    "government", "administrative", "company", "estate_agent", "insurance", "lawyer",
    "telecommunication", "educational_institution", "ngo", "association",
}


def poi_category(tags):
    a = tags.get("amenity")
    if a == "fuel":
        return "fuel", 40
    if a == "charging_station":
        return "ev", 38
    if a == "place_of_worship" and tags.get("religion") == "muslim":
        return "mosque", 40
    if a == "prayer_room":
        return "mosque", 25
    if a == "toilets":
        return "toilets", 15
    if a in ("hospital",):
        return "hospital", 60
    if a in ("clinic", "doctors", "dentist"):
        return "hospital", 30
    if a in ("restaurant", "fast_food", "cafe", "food_court", "ice_cream", "bar", "pub", "biergarten"):
        return "food", 22
    if a in ("school", "university", "college", "kindergarten", "language_school", "music_school"):
        return "education", 40 if a in ("university", "college") else 28
    if a in ("police", "fire_station", "townhall", "courthouse", "post_office", "library",
             "community_centre", "public_building"):
        return "government", 38
    if a in ("bus_station", "ferry_terminal", "taxi"):
        return "transport", 55
    if a in ("bank", "atm", "pharmacy", "marketplace", "cinema", "theatre", "car_wash",
             "veterinary", "place_of_worship"):
        return "other", 25
    if a == "parking":
        return "parking", 12
    h = tags.get("highway")
    if h in ("services", "rest_area"):
        return "rest_area", 58
    s = tags.get("shop")
    if s in _SHOP_HIGH:
        return "shop", 62 if s in ("mall", "department_store") else 35
    if s in _SHOP_MID or (s and s != "no" and (tags.get("name") or tags.get("brand"))):
        # Kedai bernama lain (termasuk shop=yes): berguna untuk destinasi MY tanpa meletupkan
        # indeks dengan nod tanpa nama.
        return "shop", 18 if s in _SHOP_MID else 14
    t = tags.get("tourism")
    if t in ("hotel", "motel", "resort", "guest_house", "hostel", "chalet", "apartment"):
        return "lodging", 30
    if t in ("attraction", "museum", "theme_park", "zoo", "viewpoint", "aquarium", "gallery",
             "artwork", "information"):
        return "tourism", 55
    if tags.get("aeroway") == "aerodrome":
        return "transport", 80
    if tags.get("railway") in ("station", "halt") or tags.get("public_transport") == "station":
        return "transport", 55
    l = tags.get("leisure")
    if l in _LEISURE:
        return "tourism", 35
    o = tags.get("office")
    if o in _OFFICE or (o and tags.get("name")):
        return "government" if o in ("government", "administrative") else "other", 28
    # Taman perumahan / kawasan kediaman bernama (sering hilang daripada place=* sahaja).
    if tags.get("landuse") == "residential" and tags.get("name"):
        return "settlement", 42
    if tags.get("place") in ("housing_estate", "residential"):
        return "settlement", 45
    return None


def clean(s):
    return " ".join(s.split()) if s else ""


class Grid:
    """Indeks grid ringkas untuk penempatan terdekat (konteks "kawasan")."""

    def __init__(self, cell=0.1):
        self.cell = cell
        self.cells = {}

    def add(self, lat, lon, item):
        k = (int(lat / self.cell), int(lon / self.cell))
        self.cells.setdefault(k, []).append((lat, lon, item))

    def nearest(self, lat, lon, max_m):
        best, best_d = None, max_m
        ci, cj = int(lat / self.cell), int(lon / self.cell)
        for i in range(ci - 2, ci + 3):
            for j in range(cj - 2, cj + 3):
                for plat, plon, item in self.cells.get((i, j), ()):
                    d = haversine_m(lat, lon, plat, plon)
                    if d < best_d:
                        best, best_d = item, d
        return best


def haversine_m(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def read(pbf):
    import osmium

    settlements, roads, pois = [], {}, []

    class H(osmium.SimpleHandler):
        def node(self, n):
            tags = n.tags
            name = clean(tags.get("name"))
            place = tags.get("place")
            if place in PLACE_RANK and name:
                rank = PLACE_RANK[place]
                pop = tags.get("population", "")
                if pop.isdigit():
                    rank += min(15, int(math.log10(max(1, int(pop)))) * 2)
                settlements.append((name, alt_names(tags), place, n.location.lat, n.location.lon, rank, tags.get("addr:state", "")))
                return
            cat = poi_category(tags)
            if cat:
                self._poi(tags, name, cat, n.location.lat, n.location.lon)

        def way(self, w):
            tags = w.tags
            name = clean(tags.get("name"))
            hw = tags.get("highway")
            if hw in ROAD_RANK and name:
                try:
                    nodes = [(nd.lat, nd.lon) for nd in w.nodes]
                except osmium.InvalidLocationError:
                    return
                if not nodes:
                    return
                lat, lon = nodes[len(nodes) // 2]
                # Satu baris setiap nama setiap petak ~2 km: jalan panjang dipecah kepada banyak way.
                key = (name.lower(), round(lat / 0.02), round(lon / 0.02))
                prev = roads.get(key)
                if prev is None or ROAD_RANK[hw] > prev[4]:
                    roads[key] = (name, alt_names(tags), hw, (lat, lon), ROAD_RANK[hw], tags.get("ref", ""))
                return
            cat = poi_category(tags)
            if cat:
                try:
                    pts = [(nd.lat, nd.lon) for nd in w.nodes]
                except osmium.InvalidLocationError:
                    return
                if not pts:
                    return
                lat = sum(p[0] for p in pts) / len(pts)
                lon = sum(p[1] for p in pts) / len(pts)
                self._poi(tags, name, cat, lat, lon)

        def area(self, a):
            # Hanya kawasan daripada RELATION (multipoligon): way tertutup sudah dikendalikan oleh way().
            # Tapak besar (hospital, universiti, masjid negara, lapangan terbang) kerap dipeta begini.
            if a.from_way():
                return
            tags = a.tags
            cat = poi_category(tags)
            if not cat and not (tags.get("place") in PLACE_RANK):
                return
            pts = []
            try:
                for ring in a.outer_rings():
                    pts.extend((nd.lat, nd.lon) for nd in ring)
            except osmium.InvalidLocationError:
                return
            if not pts:
                return
            lat = sum(p[0] for p in pts) / len(pts)
            lon = sum(p[1] for p in pts) / len(pts)
            name = clean(tags.get("name"))
            if cat:
                self._poi(tags, name, cat, lat, lon)
            elif name:
                place = tags.get("place")
                settlements.append((name, alt_names(tags), place, lat, lon, PLACE_RANK[place], tags.get("addr:state", "")))

        def _poi(self, tags, name, cat, lat, lon):
            kind, rank = cat
            if not name:
                if kind not in UNNAMED_OK:
                    return
                name = clean(tags.get("brand") or tags.get("operator") or "")
            pois.append((name, alt_names(tags), kind, lat, lon, rank,
                         clean(tags.get("addr:city") or tags.get("addr:suburb") or "")))

    H().apply_file(pbf, locations=True, idx="flex_mem")
    return settlements, list(roads.values()), pois


def alt_names(tags):
    names = []
    for k in ("name:en", "name:ms", "alt_name", "official_name", "short_name", "brand", "ref"):
        v = clean(tags.get(k))
        if v and v not in names and v != clean(tags.get("name")):
            names.append(v)
    return " ".join(names)


def _extra_row(pname, alt, kind, lat, lon, rank, area):
    """Normalisasi satu baris tambahan; pulangkan tuple atau None."""
    pname = clean(pname or "")
    if not pname:
        return None
    try:
        lat, lon = float(lat), float(lon)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    kind = clean(kind or "other") or "other"
    if kind not in CAT:
        kind = "other"
    try:
        rank = int(rank) if rank is not None and rank != "" else 36
    except (TypeError, ValueError):
        rank = 36
    return (pname, clean(alt or ""), kind, lat, lon, rank, clean(area or ""))


def _load_extra_geojson(path):
    if path.endswith(".gz"):
        import gzip

        with gzip.open(path, "rt", encoding="utf-8") as f:
            data = json.load(f)
    else:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    features = data.get("features") if isinstance(data, dict) else data
    if not isinstance(features, list):
        features = [data] if isinstance(data, dict) and "name" in data else []
    out = []
    for feat in features:
        props = feat.get("properties", feat) if isinstance(feat, dict) else {}
        if not isinstance(props, dict):
            continue
        geom = feat.get("geometry") if isinstance(feat, dict) else None
        lat = props.get("lat")
        lon = props.get("lon") or props.get("lng")
        if geom and geom.get("type") == "Point" and isinstance(geom.get("coordinates"), list):
            lon, lat = geom["coordinates"][0], geom["coordinates"][1]
        row = _extra_row(
            props.get("name") or props.get("name:en"),
            props.get("alt") or props.get("alt_name"),
            props.get("kind"),
            lat,
            lon,
            props.get("rank"),
            props.get("area") or props.get("city"),
        )
        if row:
            out.append(row)
    return out


def _load_extra_csv(path):
    """CSV berkurasi: name,lat,lon|lng[,alt,kind,area,rank]. Header wajib."""
    import csv

    out = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            return out
        for props in reader:
            if not isinstance(props, dict):
                continue
            # Normalisasi kunci header (case / ruang).
            norm = {((k or "").strip().lower()): (v.strip() if isinstance(v, str) else v)
                    for k, v in props.items()}
            row = _extra_row(
                norm.get("name") or norm.get("name:en"),
                norm.get("alt") or norm.get("alt_name"),
                norm.get("kind"),
                norm.get("lat"),
                norm.get("lon") or norm.get("lng") or norm.get("longitude"),
                norm.get("rank"),
                norm.get("area") or norm.get("city"),
            )
            if row:
                out.append(row)
    return out


def load_extra_places(extra_dir):
    """Lapisan tambahan berjadual (GeoJSON / JSON / CSV) — bukan Google Places.

    Setiap ciri: name (wajib), lat/lng atau geometry Point, kind/cat pilihan, alt, area, rank.
    Fail dalam [extra_dir]: .geojson / .geojson.gz / .json / .csv
    (abaikan *.meta.json). Lihat tools/places/README.md.
    Jangan import data Google Places/Maps (ToS).
    """
    if not extra_dir or not os.path.isdir(extra_dir):
        return []
    out = []
    for name in sorted(os.listdir(extra_dir)):
        if name.startswith(".") or name.endswith(".meta.json"):
            continue
        path = os.path.join(extra_dir, name)
        if name.endswith(".geojson.gz") or name.endswith((".geojson", ".json")):
            out.extend(_load_extra_geojson(path))
        elif name.endswith(".csv"):
            out.extend(_load_extra_csv(path))
    return out


def build(pbf, outdir, version, extra_dir=None):
    t0 = time.time()
    settlements, roads, pois = read(pbf)
    extras = load_extra_places(extra_dir)
    print(
        f">> dibaca: {len(settlements)} penempatan, {len(roads)} jalan, {len(pois)} POI, "
        f"{len(extras)} tambahan ({time.time()-t0:.0f}s)"
    )

    towns = Grid(0.1)
    villages = Grid(0.05)
    for name, _alt, kind, lat, lon, _rank, _state in settlements:
        if kind in ("city", "town"):
            towns.add(lat, lon, name)
        elif kind in ("suburb", "village", "quarter", "neighbourhood"):
            villages.add(lat, lon, name)

    def area(lat, lon, own=None, given=""):
        parts = []
        near = villages.nearest(lat, lon, 2500)
        if near and near != own:
            parts.append(near)
        town = towns.nearest(lat, lon, 20000)
        if town and town != own and town not in parts:
            parts.append(town)
        if given and given not in parts and given != own:
            parts.insert(0, given)
        return ", ".join(parts[:2])

    os.makedirs(outdir, exist_ok=True)
    db_path = os.path.join(outdir, f"places-{version}.sqlite")
    if os.path.exists(db_path):
        os.remove(db_path)
    db = sqlite3.connect(db_path)
    db.executescript(
        """
        PRAGMA page_size=4096;
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE place(id INTEGER PRIMARY KEY, name TEXT NOT NULL, alt TEXT, kind TEXT,
                           cat INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
                           area TEXT, rank INTEGER NOT NULL);
        """
    )
    rows = []
    for name, alt, kind, lat, lon, rank, state in settlements:
        town = towns.nearest(lat, lon, 30000) if kind not in ("city", "town") else None
        a = ", ".join(p for p in (town if town != name else None, state) if p)
        rows.append((name, alt, kind, CAT["settlement"], lat, lon, a, rank))
    for name, alt, hw, (lat, lon), rank, ref in roads:
        rows.append((name, (alt + " " + ref).strip(), hw, CAT["road"], lat, lon, area(lat, lon), rank))
    for name, alt, kind, lat, lon, rank, city in pois:
        # landuse/residential bernama boleh kembali sebagai kind=settlement daripada poi_category.
        cat = CAT.get(kind, CAT["other"])
        rows.append((name, alt, kind, cat, lat, lon, area(lat, lon, given=city), rank))
    for name, alt, kind, lat, lon, rank, city in extras:
        rows.append((name, alt, kind, CAT[kind], lat, lon, area(lat, lon, given=city) or city, rank))
    rows.sort(key=lambda r: -r[7])
    db.executemany(
        "INSERT INTO place(name, alt, kind, cat, lat, lng, area, rank) VALUES (?,?,?,?,?,?,?,?)",
        ((r[0], r[1] or None, r[2], r[3], round(r[4], 6), round(r[5], 6), r[6] or None, r[7]) for r in rows),
    )
    db.executescript(
        """
        CREATE INDEX place_cat_lat ON place(cat, lat);
        CREATE VIRTUAL TABLE place_fts USING fts4(content="place", name, alt, area, tokenize=simple);
        INSERT INTO place_fts(docid, name, alt, area) SELECT id, name, alt, area FROM place;
        INSERT INTO place_fts(place_fts) VALUES('optimize');
        """
    )
    sources = ["OpenStreetMap contributors (ODbL)"]
    if extras:
        sources.append(f"curated extra ({len(extras)})")
    db.executemany(
        "INSERT INTO meta VALUES (?,?)",
        [("schema", str(SCHEMA)), ("version", version), ("count", str(len(rows))),
         ("source", "; ".join(sources)), ("extraCount", str(len(extras)))],
    )
    db.commit()
    db.execute("VACUUM")
    db.close()

    raw_size = os.path.getsize(db_path)
    raw_sha = sha256(db_path)
    gz_name = f"places-{version}.sqlite.gz"
    gz_path = os.path.join(outdir, gz_name)
    with open(db_path, "rb") as src, gzip.open(gz_path, "wb", compresslevel=9) as dst:
        while chunk := src.read(1 << 20):
            dst.write(chunk)
    size = os.path.getsize(gz_path)
    info = {
        "file": gz_name, "sizeBytes": size, "sha256": sha256(gz_path),
        "extractedSizeBytes": raw_size, "extractedSha256": raw_sha,
        "count": len(rows), "schema": SCHEMA, "extraCount": len(extras),
    }
    manifest = os.path.join(outdir, "manifest.json")
    if os.path.exists(manifest):
        with open(manifest) as f:
            m = json.load(f)
        m["places"] = info
        with open(manifest, "w") as f:
            json.dump(m, f, indent=2)
    print(f">> {len(rows)} baris, {raw_size/1e6:.1f} MB -> {size/1e6:.1f} MB gz ({time.time()-t0:.0f}s)")
    print(json.dumps(info, indent=2))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 20):
            h.update(chunk)
    return h.hexdigest()


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        print(__doc__)
        print("Penggunaan: build_places.py <osm.pbf> <outdir> <versi-pek> [extra_dir]")
        sys.exit(2)
    default_extra = os.path.join(os.path.dirname(__file__), "extra")
    extra = sys.argv[4] if len(sys.argv) == 5 else (default_extra if os.path.isdir(default_extra) else None)
    build(sys.argv[1], sys.argv[2], sys.argv[3], extra_dir=extra)
