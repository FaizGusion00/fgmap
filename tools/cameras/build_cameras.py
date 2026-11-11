#!/usr/bin/env python3
"""Membina app/assets/cameras/cameras_my.json: SATU aset kamera kelajuan Malaysia yang dibundel.

Sumber:
  1. Pin AwAS JPJ yang dikurasi (tools/cameras/awas_curated.json). Banyak pin ialah anggaran KM lebuh raya;
     setiap pin disemak terhadap jalan utama OSM (motorway/trunk/primary):
       - <= 60 m  -> disimpan, confidence 'high' (kecuali koordinat dibundarkan <= 2 perpuluhan -> 'approx')
       - <= 150 m -> disimpan, confidence 'approx'
       - lain     -> DIBUANG (pin di tengah kampung/hutan lebih buruk daripada tiada pin).
  2. Semua nod OSM `highway=speed_camera` dalam Malaysia (Overpass), confidence 'high'.
     - `direction` OSM: darjah atau kardinal (N, NE, ...) -> darjah; forward/backward/both/clockwise -> tiada.
     - "Northbound"/"(NB)" dsb. dalam nama atau `direction` -> `bound`.
     - Darjah yang bercanggah dengan `bound`, atau tidak selari dengan mana-mana jalan dalam 60 m, dibuang
       (arah tidak diketahui = amaran untuk semua arah; lebih selamat daripada menolak kamera sebenar).
     - Nod pendua OSM (<= 120 m, jenis dan arah serasi) digabung.
  3. Nyahpendua: kamera OSM dalam 300 m daripada pin AwAS yang disimpan (jenis dan arah serasi) menjadi satu
     rekod: koordinat OSM, nama/bound AwAS, source 'jpj_awas', confidence 'high'. Pin AwAS tanpa kembar
     dalam 300 m dipadankan MENGIKUT NAMA (KM sama, atau tempat + bound sama) dalam 10 km dengan cara yang sama,
     kerana pin anggaran KM boleh tersasar beberapa km sepanjang jalan.

Penggunaan:
  python3 tools/cameras/build_cameras.py [--osm-file osm.json] [--out app/assets/cameras/cameras_my.json]

Data OSM (c) penyumbang OpenStreetMap, ODbL.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DEFAULT_AWAS = os.path.join(HERE, "awas_curated.json")
DEFAULT_OUT = os.path.join(ROOT, "app", "assets", "cameras", "cameras_my.json")

UA = "map-camera-check/1.0"
MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

OSM_CAMERA_QUERY = (
    '[out:json][timeout:150];area["ISO3166-1"="MY"][admin_level=2]->.my;'
    'node["highway"="speed_camera"](area.my);out body;'
)

MAIN_ROAD_RE = "^(motorway|trunk|primary)$"
ANY_ROAD_RE = (
    "^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|"
    "motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"
)

KEEP_M = 150.0  # pin AwAS disimpan jika sejauh ini dari jalan utama
HIGH_M = 60.0  # ... dan 'high' jika sejauh ini
AWAS_OSM_DEDUPE_M = 300.0
OSM_OSM_DEDUPE_M = 120.0
DIRECTION_ROAD_M = 60.0  # jalan yang digunakan untuk mengesahkan `direction`
DIRECTION_TOL_DEG = 60.0

CARDINALS = {
    "N": 0, "NNE": 22.5, "NE": 45, "ENE": 67.5, "E": 90, "ESE": 112.5, "SE": 135, "SSE": 157.5,
    "S": 180, "SSW": 202.5, "SW": 225, "WSW": 247.5, "W": 270, "WNW": 292.5, "NW": 315, "NNW": 337.5,
}
BOUND_WORDS = [
    (re.compile(r"\bnorth\s*bound\b|\(nb\)|\bnb\b|arah utara", re.I), "NB"),
    (re.compile(r"\bsouth\s*bound\b|\(sb\)|\bsb\b|arah selatan", re.I), "SB"),
    (re.compile(r"\beast\s*bound\b|\(eb\)|\beb\b|arah timur", re.I), "EB"),
    (re.compile(r"\bwest\s*bound\b|\(wb\)|\bwb\b|arah barat", re.I), "WB"),
]
OPPOSITE = {"NB": "SB", "SB": "NB", "EB": "WB", "WB": "EB"}


def log(*a):
    print(*a, file=sys.stderr)


# ---------------------------------------------------------------- geometri

def dist_m(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371008.8 * math.asin(min(1, math.sqrt(h)))


def bearing(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    y = math.sin(lo2 - lo1) * math.cos(la2)
    x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(lo2 - lo1)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def seg_dist(p, a, b):
    kx = 111320 * math.cos(math.radians(p[0]))
    ky = 110540
    ax, ay = (a[1] - p[1]) * kx, (a[0] - p[0]) * ky
    bx, by = (b[1] - p[1]) * kx, (b[0] - p[0]) * ky
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0 if length == 0 else max(0, min(1, -(ax * dx + ay * dy) / length))
    return math.hypot(ax + t * dx, ay + t * dy)


def ang_diff(a, b):
    d = abs((a - b) % 360)
    return 360 - d if d > 180 else d


def in_bound(bound, deg):
    """Sama seperti app: separuh satah. NB = ada komponen ke utara, dsb."""
    b = deg % 360
    return {
        "NB": b > 270 or b < 90,
        "SB": 90 < b < 270,
        "EB": 0 < b < 180,
        "WB": 180 < b < 360,
    }.get(bound, True)


# ---------------------------------------------------------------- tag OSM

def parse_direction(raw):
    """Darjah [0, 360) atau None. forward/backward/both/clockwise/julat -> None (tidak diketahui)."""
    if raw is None:
        return None
    s = str(raw).strip()
    if not s or ";" in s:
        return None
    try:
        return float(s) % 360
    except ValueError:
        pass
    return CARDINALS.get(s.upper())


def bound_from_text(*texts):
    for t in texts:
        if not t:
            continue
        for rx, b in BOUND_WORDS:
            if rx.search(str(t)):
                return b
    return None


def parse_maxspeed(raw):
    if raw is None:
        return None
    m = re.match(r"^\s*(\d+(?:\.\d+)?)\s*(mph|km/h|kmh|kph)?\s*$", str(raw), re.I)
    if not m:
        return None
    v = float(m.group(1))
    if (m.group(2) or "").lower() == "mph":
        v *= 1.609344
    v = int(round(v))
    return v if 5 <= v <= 200 else None


def camera_type(tags):
    enf = (tags.get("enforcement") or "").lower()
    if enf in ("traffic_signals", "red_light_camera"):
        return "red_light"
    return "speed"


# ---------------------------------------------------------------- Overpass

CACHE_DIR = None  # --cache DIR: simpan respons Overpass supaya larian semula tidak memuat turun lagi


def overpass(query, timeout=200):
    cache_file = None
    if CACHE_DIR:
        os.makedirs(CACHE_DIR, exist_ok=True)
        cache_file = os.path.join(CACHE_DIR, hashlib.sha1(query.encode()).hexdigest() + ".json")
        if os.path.exists(cache_file):
            with open(cache_file, encoding="utf-8") as f:
                return json.load(f)
    last = None
    for attempt in range(2):
        for url in MIRRORS:
            try:
                req = urllib.request.Request(
                    url, data=urllib.parse.urlencode({"data": query}).encode(), headers={"User-Agent": UA}
                )
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    data = json.loads(r.read().decode("utf-8"))
                if "elements" not in data:
                    raise ValueError(f"tiada 'elements' daripada {url}")
                # Overpass memulangkan HTTP 200 + `remark` dengan hasil SEPARA bila tamat masa/memori.
                remark = data.get("remark") or ""
                if "error" in remark.lower() or "timed out" in remark.lower():
                    raise ValueError(f"hasil separa: {remark[:120]}")
                if cache_file:
                    with open(cache_file, "w", encoding="utf-8") as f:
                        json.dump(data, f)
                return data
            except Exception as e:  # noqa: BLE001 - cuba cermin seterusnya
                last = e
                log(f"  Overpass gagal ({url}): {e}")
        time.sleep(5)
    raise SystemExit(f"Semua cermin Overpass gagal: {last}")


def roads_around(points, radius, highway_re, chunk=40):
    """Way jalan (dengan geometri) sekitar setiap titik, dipecah supaya pertanyaan tidak terlalu besar."""
    ways = {}
    for i in range(0, len(points), chunk):
        part = points[i:i + chunk]
        q = "[out:json][timeout:180];(" + "".join(
            f'way["highway"~"{highway_re}"](around:{radius},{lat:.7f},{lng:.7f});' for lat, lng in part
        ) + ");out geom;"
        for w in overpass(q)["elements"]:
            if w.get("type") == "way" and w.get("geometry"):
                ways[w["id"]] = w
    return list(ways.values())


def road_profile(p, ways, within):
    """(jarak terdekat, ref terdekat, [arah perjalanan segmen dalam `within` m])."""
    nearest = (math.inf, None)
    travel = []
    for w in ways:
        g = w["geometry"]
        tags = w.get("tags", {})
        oneway = tags.get("oneway") in ("yes", "1", "true") or tags.get("highway") == "motorway"
        reverse = tags.get("oneway") == "-1"
        for i in range(len(g) - 1):
            a = (g[i]["lat"], g[i]["lon"])
            b = (g[i + 1]["lat"], g[i + 1]["lon"])
            d = seg_dist(p, a, b)
            if d < nearest[0]:
                nearest = (d, tags.get("ref") or tags.get("name") or tags.get("highway"))
            if d <= within:
                br = bearing(a, b)
                if reverse:
                    br = (br + 180) % 360
                travel.append(br)
                if not oneway and not reverse:
                    travel.append((br + 180) % 360)
    return nearest[0], nearest[1], travel


# ---------------------------------------------------------------- padanan

def heading_compatible(a, b):
    """Dua rekod mungkin kamera yang sama (arah tidak bercanggah)."""
    da, db = a.get("direction"), b.get("direction")
    ba, bb = a.get("bound"), b.get("bound")
    if da is not None and db is not None:
        return ang_diff(da, db) <= DIRECTION_TOL_DEG
    if da is not None and bb:
        return in_bound(bb, da)
    if db is not None and ba:
        return in_bound(ba, db)
    if ba and bb:
        return OPPOSITE.get(ba) != bb
    return True


def compatible(a, b):
    return a["type"] == b["type"] and heading_compatible(a, b)


NAME_MATCH_M = 10000.0
_GENERIC = {
    "plus", "lebuhraya", "highway", "expressway", "jalan", "aes", "awas", "kamera", "kelajuan", "camera",
    "speed", "northbound", "southbound", "eastbound", "westbound", "arah", "exit", "north", "south", "east",
    "west", "utara", "selatan", "timur", "barat", "terowong", "corridor",
}


def km_marker(name):
    m = re.search(r"\bKM\s*([A-Z]?\d+(?:\.\d+)?)", name or "", re.I)
    return m.group(1).upper() if m else None


def place_tokens(name):
    words = re.findall(r"[a-z]+", (name or "").lower())
    return {w for w in words if len(w) >= 4 and w not in _GENERIC}


def names_match(awas_rec, osm_rec):
    """Kamera yang sama menurut nama: KM sama (dan arah serasi), atau tempat sama + bound sama."""
    if not compatible(awas_rec, osm_rec):
        return False
    ka, ko = km_marker(awas_rec["name"]), km_marker(osm_rec.get("name_tagged"))
    if ka and ko:
        return ka == ko
    shared = place_tokens(awas_rec["name"]) & place_tokens(osm_rec.get("name_tagged"))
    return bool(shared) and awas_rec.get("bound") is not None and awas_rec["bound"] == osm_rec.get("bound")


def info_score(c):
    return sum(1 for k in ("name_tagged", "direction", "bound", "maxspeed") if c.get(k) is not None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--awas", default=DEFAULT_AWAS, help="senarai AwAS dikurasi (JSON)")
    ap.add_argument("--osm-file", help="respons Overpass kamera yang telah dimuat turun (pilihan)")
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--cache", help="direktori cache respons Overpass (pilihan)")
    args = ap.parse_args()
    global CACHE_DIR
    CACHE_DIR = args.cache

    with open(args.awas, encoding="utf-8") as f:
        awas_doc = json.load(f)
    awas = awas_doc["cameras"]

    # 1. Kamera OSM
    if args.osm_file:
        with open(args.osm_file, encoding="utf-8") as f:
            osm_doc = json.load(f)
        log(f"OSM: dibaca daripada {args.osm_file}")
    else:
        log("OSM: memuat turun kamera Malaysia daripada Overpass ...")
        osm_doc = overpass(OSM_CAMERA_QUERY)
    osm_nodes = [e for e in osm_doc["elements"] if e.get("type") == "node" and "lat" in e]
    osm_stamp = (osm_doc.get("osm3s") or {}).get("timestamp_osm_base")
    log(f"OSM: {len(osm_nodes)} nod highway=speed_camera")

    # 2. Jalan: utama sekitar pin AwAS (1.5 km untuk laporan), semua jalan sekitar kamera OSM.
    log("Jalan utama sekitar pin AwAS ...")
    main_ways = roads_around([(c["lat"], c["lng"]) for c in awas], 1500, MAIN_ROAD_RE, chunk=8)
    log("Jalan sekitar kamera OSM ...")
    osm_ways = roads_around([(n["lat"], n["lon"]) for n in osm_nodes], int(DIRECTION_ROAD_M) + 20, ANY_ROAD_RE, chunk=25)

    # 3. AwAS: simpan hanya yang dekat jalan utama.
    kept_awas, dropped = [], []
    for c in awas:
        p = (c["lat"], c["lng"])
        d, ref, _ = road_profile(p, main_ways, 0)
        if d > KEEP_M:
            dropped.append((c["id"], d, ref))
            continue
        rounded = all(abs(v * 100 - round(v * 100)) < 1e-6 for v in p)
        conf = "high" if d <= HIGH_M and not rounded else "approx"
        kept_awas.append({
            "id": c["id"], "name": c["name"], "lat": c["lat"], "lng": c["lng"],
            "type": c.get("type") or "speed", "bound": c.get("bound") or None,
            "direction": None, "maxspeed": None,
            "source": "jpj_awas", "confidence": conf, "road_m": d, "osm": [],
        })

    # 4. OSM: huraikan + sahkan arah.
    osm = []
    dir_dropped = []
    for n in osm_nodes:
        tags = n.get("tags", {})
        name = tags.get("name") or tags.get("name:ms") or tags.get("name:en")
        ctype = camera_type(tags)
        bound = bound_from_text(tags.get("direction"), name, tags.get("name:en"))
        direction = parse_direction(tags.get("direction"))
        p = (n["lat"], n["lon"])
        if direction is not None and bound and not in_bound(bound, direction):
            dir_dropped.append((n["id"], tags.get("direction"), f"bercanggah dengan {bound}"))
            direction = None
        if direction is not None:
            _, _, travel = road_profile(p, osm_ways, DIRECTION_ROAD_M)
            if travel and not any(ang_diff(direction, t) <= DIRECTION_TOL_DEG for t in travel):
                dir_dropped.append((n["id"], tags.get("direction"), "tidak selari dengan jalan"))
                direction = None
        default_name = "Kamera lampu isyarat" if ctype == "red_light" else "Kamera kelajuan"
        osm.append({
            "id": f"osm-{n['id']}", "name": name or default_name, "name_tagged": name,
            "lat": round(n["lat"], 7), "lng": round(n["lon"], 7), "type": ctype,
            "bound": bound, "direction": round(direction, 1) if direction is not None else None,
            "maxspeed": parse_maxspeed(tags.get("maxspeed")),
            "source": "osm", "confidence": "high",
        })

    # 5. Gabung nod pendua OSM.
    osm.sort(key=lambda c: -info_score(c))
    osm_unique, osm_merged = [], []
    for c in osm:
        twin = next(
            (u for u in osm_unique
             if dist_m((u["lat"], u["lng"]), (c["lat"], c["lng"])) <= OSM_OSM_DEDUPE_M and compatible(u, c)),
            None,
        )
        if twin is None:
            osm_unique.append(c)
            continue
        for k in ("bound", "direction", "maxspeed"):
            if twin.get(k) is None and c.get(k) is not None:
                twin[k] = c[k]
        if twin.get("name_tagged") is None and c.get("name_tagged"):
            twin["name"] = twin["name_tagged"] = c["name_tagged"]
        osm_merged.append((c["id"], twin["id"]))

    # 6. Nyahpendua AwAS <-> OSM (setiap OSM ke pin AwAS serasi yang terdekat).
    standalone = []
    for c in osm_unique:
        best = None
        for a in kept_awas:
            d = dist_m((a["lat"], a["lng"]), (c["lat"], c["lng"]))
            if d <= AWAS_OSM_DEDUPE_M and compatible(a, c) and (best is None or d < best[0]):
                best = (d, a)
        if best is None:
            standalone.append(c)
        else:
            best[1]["osm"].append((best[0], c))

    # 6b. Pin AwAS yang tiada kembar dalam 300 m: cari kamera OSM yang sama MENGIKUT NAMA (nombor KM
    #     sama, atau nama tempat sama + bound sama) dalam 10 km. Pin AwAS anggaran KM selalunya beberapa km
    #     tersasar sepanjang jalan; nod OSM ialah kedudukan sebenar.
    name_matched = []
    for a in kept_awas:
        if a["osm"]:
            continue
        best = None
        for c in standalone:
            d = dist_m((a["lat"], a["lng"]), (c["lat"], c["lng"]))
            if d <= NAME_MATCH_M and names_match(a, c) and (best is None or d < best[0]):
                best = (d, c)
        if best is not None:
            standalone.remove(best[1])
            a["osm"].append(best)
            name_matched.append((a["id"], best[1]["id"], round(best[0])))

    merged_pairs = []
    for a in kept_awas:
        if not a["osm"]:
            continue
        a["osm"].sort(key=lambda t: t[0])
        nearest = a["osm"][0][1]
        a["lat"], a["lng"] = nearest["lat"], nearest["lng"]
        a["confidence"] = "high"
        for _, o in a["osm"]:
            if a["direction"] is None and o.get("direction") is not None and (
                not a["bound"] or in_bound(a["bound"], o["direction"])
            ):
                a["direction"] = o["direction"]
            if a["maxspeed"] is None and o.get("maxspeed") is not None:
                a["maxspeed"] = o["maxspeed"]
            if a["bound"] is None and o.get("bound"):
                a["bound"] = o["bound"]
        merged_pairs.append((a["id"], [o["id"] for _, o in a["osm"]], round(a["osm"][0][0])))

    # 7. Tulis aset.
    fields = ("id", "name", "lat", "lng", "type", "bound", "direction", "maxspeed", "source", "confidence")
    out = []
    for c in kept_awas + standalone:
        out.append({k: c[k] for k in fields if c.get(k) is not None})
    out.sort(key=lambda c: (c["source"] != "jpj_awas", c["id"]))

    today = datetime.date.today().isoformat()
    note = (
        f"Kamera kelajuan/lampu isyarat Malaysia, dijana oleh tools/cameras/build_cameras.py pada {today}. "
        f"{len(kept_awas)} daripada {len(awas)} pin AwAS JPJ dikurasi disimpan; {len(dropped)} dibuang kerana "
        f"lebih {int(KEEP_M)} m dari jalan utama OSM (motorway/trunk/primary), iaitu pin anggaran KM yang "
        f"tidak boleh dipercayai: {', '.join(i for i, _, _ in dropped)}. "
        f"{len(merged_pairs)} pin AwAS digabung dengan kamera OSM (koordinat OSM): "
        f"{len(merged_pairs) - len(name_matched)} dalam {int(AWAS_OSM_DEDUPE_M)} m, {len(name_matched)} "
        f"mengikut nama (KM atau tempat + bound sama, <= {int(NAME_MATCH_M / 1000)} km). {len(osm_nodes)} nod OSM highway=speed_camera; {len(osm_merged)} nod pendua OSM "
        f"digabung. 'approx' = pin 60-150 m dari jalan atau koordinat dibundarkan. "
        "'direction' = arah perjalanan (darjah) yang dikuatkuasa; tiada = semua arah. Tidak lengkap: "
        "bukan semua kamera Malaysia (polis bergerak dll.)."
    )
    doc = {
        "asOf": today,
        "sources": [
            {
                "id": "jpj_awas",
                "name": "Senarai lokasi kamera AwAS JPJ (dikurasi)",
                "asOf": awas_doc.get("asOf"),
            },
            {
                "id": "osm",
                "name": "OpenStreetMap highway=speed_camera",
                "license": "ODbL (c) penyumbang OpenStreetMap",
                "asOf": osm_stamp,
            },
        ],
        "note": note,
        "cameras": out,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write("{\n")
        f.write(f'  "asOf": {json.dumps(doc["asOf"])},\n')
        f.write(f'  "sources": {json.dumps(doc["sources"], ensure_ascii=False)},\n')
        f.write(f'  "note": {json.dumps(doc["note"], ensure_ascii=False)},\n')
        f.write('  "cameras": [\n')
        f.write(",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in out))
        f.write("\n  ]\n}\n")

    # Laporan
    print(f"OSM: {len(osm_nodes)} nod, {len(osm_merged)} pendua digabung, {len(standalone)} rekod OSM sahaja")
    print(f"AwAS: {len(kept_awas)} disimpan, {len(dropped)} dibuang, {len(merged_pairs)} digabung dengan OSM")
    for i, d, ref in dropped:
        far = "tiada jalan utama dalam 1.5 km" if math.isinf(d) else f"{d:.0f} m dari {ref}"
        print(f"  DIBUANG {i}: {far}")
    for a in kept_awas:
        print(f"  simpan  {a['id']}: {a['road_m']:.0f} m, {a['confidence']}")
    named = {aid for aid, _, _ in name_matched}
    for aid, oids, d in merged_pairs:
        how = "nama" if aid in named else "jarak"
        print(f"  gabung  {aid} <- {', '.join(oids)} ({d} m, {how})")
    for oid, twin in osm_merged:
        print(f"  pendua  {oid} -> osm {twin}")
    for oid, raw, why in dir_dropped:
        print(f"  arah    osm-{oid} direction={raw} dibuang: {why}")
    print(f"Jumlah: {len(out)} kamera -> {args.out}")


if __name__ == "__main__":
    main()
