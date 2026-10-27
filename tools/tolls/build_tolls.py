#!/usr/bin/env python3
"""Membina app/assets/tolls/my_tolls.json (skema versi 2) daripada:

  1. Kadar rasmi Lembaga Lebuhraya Malaysia (LLM) bagi setiap pasangan plaza masuk-keluar: JSON statik
     daripada projek mohdsyahid/kadar-tol-malaysia (MIT), yang merangkak kalkulator LLM
     (https://www.llm.gov.my/Calculator). Hanya sistem TERTUTUP ada data; hanya kelas 1 (kereta) disimpan.
  2. Koordinat plaza daripada nod OSM `barrier=toll_booth` (Overpass), dipadankan dengan nama LLM.

Dijalankan dalam GitHub Actions (rangkaian container pembangunan menyekat hos ini). Menulis juga laporan
padanan supaya plaza yang tidak dipadankan dapat disemak dan ditambah ke tools/tolls/aliases.json.

Penggunaan:
  build_tolls.py --dataset-dir DIR --overpass-file FILE --out my_tolls.json --report report.md
  (tanpa --dataset-dir / --overpass-file: dimuat turun)
"""
import argparse
import json
import math
import os
import re
import sys
import urllib.parse
import urllib.request

DATA_BASE = "https://raw.githubusercontent.com/mohdsyahid/kadar-tol-malaysia/main/docs/data"
UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"
SOURCE = (
    "Lembaga Lebuhraya Malaysia (kalkulator tol rasmi, https://www.llm.gov.my/Calculator) "
    "melalui mohdsyahid/kadar-tol-malaysia (MIT); koordinat plaza: OpenStreetMap (ODbL)"
)

# Singkatan umum dalam nama plaza OSM dan LLM.
ABBREVIATIONS = {
    "sg": "sungai", "tg": "tanjung", "kg": "kampung", "bt": "bukit", "pj": "petaling jaya",
    "ayer": "air", "bdr": "bandar", "tmn": "taman", "jln": "jalan", "kl": "kuala lumpur",
}
DIRECTIONS = {
    "s": "selatan", "u": "utara", "b": "barat", "t": "timur",
    "selatan": "selatan", "utara": "utara", "barat": "barat", "timur": "timur",
    "south": "selatan", "north": "utara", "west": "barat", "east": "timur",
}
NOISE = {"plaza", "tol", "toll", "arah", "plazas"}


def http_get(url, data=None, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": UA}, data=data)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8-sig")


def tokens(name):
    """Nama -> (token asas, arah). Arah dikeluarkan daripada kurungan atau perkataan arah."""
    text = name.lower().replace("&", " dan ")
    direction = None
    for m in re.finditer(r"\(([^)]*)\)", text):
        words = re.findall(r"[a-z]+", m.group(1))
        for w in words:
            if w in DIRECTIONS and direction is None:
                direction = DIRECTIONS[w]
    text = re.sub(r"\([^)]*\)", " ", text)
    out = []
    for w in re.findall(r"[a-z0-9]+", text):
        w = ABBREVIATIONS.get(w, w)
        for part in w.split():
            if part in NOISE:
                continue
            if part in DIRECTIONS and len(part) > 1 and direction is None:
                direction = DIRECTIONS[part]
                continue
            out.append(part)
    return tuple(out), direction


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def cluster(nodes, radius=1500):
    clusters = []
    for n in nodes:
        for c in clusters:
            if haversine((n["lat"], n["lon"]), c["center"]) <= radius:
                c["nodes"].append(n)
                c["center"] = (
                    sum(x["lat"] for x in c["nodes"]) / len(c["nodes"]),
                    sum(x["lon"] for x in c["nodes"]) / len(c["nodes"]),
                )
                break
        else:
            clusters.append({"nodes": [n], "center": (n["lat"], n["lon"])})
    return clusters


def in_malaysia(lat, lon):
    return 0.8 <= lat <= 7.5 and 99.0 <= lon <= 120.0


def load_dataset(dataset_dir):
    def read(name):
        if dataset_dir:
            with open(os.path.join(dataset_dir, name), encoding="utf-8") as f:
                return json.load(f)
        return json.loads(http_get(f"{DATA_BASE}/{name}"))

    index = read("highways.json")
    systems = []
    for h in index["highways"]:
        if h["routeCount"] > 0:
            systems.append(read(f"{h['id']}.json"))
    return index, systems


def load_overpass(path):
    if path:
        with open(path, encoding="utf-8") as f:
            return json.load(f)["elements"]
    q = (
        '[out:json][timeout:90];area["ISO3166-1"="MY"]->.a;'
        '(node["barrier"="toll_booth"](area.a);node["highway"="toll_gantry"](area.a););out body;'
    )
    for url in ("https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter"):
        try:
            return json.loads(http_get(url, data=urllib.parse.urlencode({"data": q}).encode()))["elements"]
        except Exception as e:  # noqa: BLE001
            print("Overpass gagal", url, repr(e), file=sys.stderr)
    raise SystemExit("Overpass tidak dapat dicapai")


def candidate_lines(pname, osm_nodes, limit=6):
    """Calon nod OSM yang berkongsi sekurang-kurangnya satu perkataan bermakna (>= 4 huruf), untuk
    membantu memilih alias secara manual. Hanya paparan; tidak mempengaruhi dataset."""
    want = {w for w in tokens(pname)[0] if len(w) >= 4}
    found = []
    for e in osm_nodes:
        tg = e.get("tags", {})
        nm = tg.get("name") or ""
        if not nm or not in_malaysia(e["lat"], e["lon"]):
            continue
        if want & set(tokens(nm)[0]):
            found.append(e)
    lines = []
    for c in cluster(found)[:limit]:
        names = sorted({x["tags"].get("name", "") for x in c["nodes"]})
        ops = sorted({x["tags"].get("operator", "") for x in c["nodes"] if x["tags"].get("operator")})
        lat, lon = c["center"]
        lines.append(f"    calon: {lat:.5f},{lon:.5f} nama={names[:3]} operator={ops[:2]} nod={len(c['nodes'])}")
    return lines


def build_system(sysdata, osm_nodes, aliases, report):
    name = sysdata["highway"]
    sid = str(sysdata["highwayId"])
    plazas = {}  # id -> name
    for r in sysdata["routes"]:
        plazas[str(r["entryPlazaId"])] = r["entryPlaza"]
        plazas[str(r["exitPlazaId"])] = r["exitPlaza"]
    ids = sorted(plazas, key=lambda x: (len(x), x))
    index = {pid: i for i, pid in enumerate(ids)}
    n = len(ids)
    matrix = [None] * (n * n)
    for r in sysdata["routes"]:
        cls1 = next((x["rateRM"] for x in r["rates"] if x["vehicleClass"] == 1), None)
        if isinstance(cls1, (int, float)) and cls1 > 0:
            matrix[index[str(r["entryPlazaId"])] * n + index[str(r["exitPlazaId"])]] = round(float(cls1), 2)

    hint = set(tokens(name)[0]) | set(re.findall(r"[a-z]+", re.sub(r".*\(|\).*", "", name.lower())))
    out = []
    matched = 0
    for pid in ids:
        pname = plazas[pid]
        key = f"{sid}:{pname}"
        lat = lon = None
        how = ""
        if key in aliases and aliases[key].get("lat") is not None:
            lat, lon, how = aliases[key]["lat"], aliases[key]["lon"], "alias-koordinat"
        else:
            want_tokens, want_dir = tokens(aliases.get(key, {}).get("osmName", pname))
            cands = []
            for e in osm_nodes:
                tg = e.get("tags", {})
                if not tg.get("name") or not in_malaysia(e["lat"], e["lon"]):
                    continue
                t, d = tokens(tg["name"])
                if t != want_tokens:
                    continue
                if want_dir and d and d != want_dir:
                    continue
                cands.append(e)
            if want_dir:
                # Utamakan nod yang arahnya sepadan; jika OSM tiada arah, terima semua.
                exact = [e for e in cands if tokens(e["tags"]["name"])[1] == want_dir]
                cands = exact or cands
            if cands:
                clusters = cluster(cands)
                if len(clusters) > 1:
                    def score(c):
                        ops = " ".join((x.get("tags", {}).get("operator") or "").lower() for x in c["nodes"])
                        return sum(1 for h in hint if h in ops)
                    clusters.sort(key=score, reverse=True)
                    if score(clusters[0]) == score(clusters[1]):
                        report.append(f"- AMBIGU `{key}`: {len(clusters)} kelompok, tiada petunjuk pengendali")
                        clusters = []
                if clusters:
                    lat, lon = clusters[0]["center"]
                    how = f"nama({len(clusters[0]['nodes'])} nod)"
        entry = {"id": pid, "name": pname}
        if lat is not None:
            entry["lat"], entry["lng"] = round(lat, 5), round(lon, 5)
            matched += 1
        else:
            report.append(f"- TIDAK DIPADANKAN `{key}`")
            report.extend(candidate_lines(pname, osm_nodes))
        out.append(entry)
    report.append(f"\n### {name}: {matched}/{n} plaza berkoordinat, {sysdata['routeCount']} laluan\n")
    return {"id": sid, "name": name, "plazas": out, "matrix": matrix}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset-dir")
    ap.add_argument("--overpass-file")
    ap.add_argument("--aliases", default=os.path.join(os.path.dirname(__file__), "aliases.json"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--report", required=True)
    args = ap.parse_args()

    index, systems = load_dataset(args.dataset_dir)
    osm = load_overpass(args.overpass_file)
    aliases = {}
    if os.path.exists(args.aliases):
        with open(args.aliases, encoding="utf-8") as f:
            aliases = json.load(f)

    report = ["# Laporan padanan plaza tol\n"]
    closed = [build_system(s, osm, aliases, report) for s in systems]
    # Sistem tanpa satu pun koordinat tidak berguna dalam app; dilaporkan tetapi tetap ditulis.
    generated = index.get("generatedAt", "")
    doc = {
        "version": 2,
        "currency": "MYR",
        "source": SOURCE,
        "lastVerified": generated[:10] if generated else None,
        "closed": closed,
        "open": [],
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    with open(args.report, "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report))
    print("ditulis", args.out, os.path.getsize(args.out), "bait")


if __name__ == "__main__":
    main()
