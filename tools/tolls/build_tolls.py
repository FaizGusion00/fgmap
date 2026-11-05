#!/usr/bin/env python3
"""Membina app/assets/tolls/my_tolls.json (skema versi 2) daripada:

  1. Kadar rasmi Lembaga Lebuhraya Malaysia (LLM), dirangkak terus daripada kalkulator LLM
     (https://www.llm.gov.my/Calculator, lihat llm_api.py): matriks masuk-keluar bagi sistem TERTUTUP dan
     satu kadar bagi setiap plaza harga tetap. Hanya kelas 1 (kereta) disimpan. Jika LLM tidak dapat
     dicapai: sumber lama (mohdsyahid/kadar-tol-malaysia + halaman pengendali dalam open_sources.py).
  2. Koordinat plaza daripada nod OSM `barrier=toll_booth` (Overpass), dipadankan dengan nama LLM. Setiap
     plaza membawa `booths`: titik booth OSM sebenar (bukan purata kelompok, yang bagi plaza persimpangan
     jatuh di atas laluan utama).

Menulis juga laporan padanan supaya plaza yang tidak dipadankan dapat disemak dan ditambah ke
tools/tolls/aliases.json.

Penggunaan:
  build_tolls.py --overpass-file FILE --llm-dataset llm.json --out my_tolls.json --report report.md
  (tanpa --llm-dataset: dirangkak terus; --llm-cache FILE untuk menyambung larian terputus)
  build_tolls.py --dataset-dir DIR ...   (sumber lama sahaja)
"""
import argparse
import datetime
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

SOURCE_LLM = (
    "Lembaga Lebuhraya Malaysia (kalkulator tol rasmi, https://www.llm.gov.my/Calculator, dirangkak terus); "
    "koordinat plaza: OpenStreetMap (ODbL)"
)

# Singkatan umum dalam nama plaza OSM dan LLM.
ABBREVIATIONS = {
    "sg": "sungai", "kampong": "kampung", "tg": "tanjung", "kg": "kampung", "bt": "bukit", "pj": "petaling jaya",
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


# Id nod booth yang ialah nod sebenar pada jalan OSM (`way(bn)`), diisi oleh main() daripada --booth-ways.
ON_WAY_IDS = set()
ON_WAY_POINTS = set()


def booth_points(nodes, center=None, report=None, key=""):
    """Titik booth OSM SEBENAR bagi satu plaza (bukan purata kelompok). Plaza persimpangan ada booth di kedua-dua
    belah lebuh raya; puratanya jatuh di atas laluan utama dan "dipadankan" oleh setiap kenderaan yang lalu.
    Pendua (< 2 m) dibuang, maksimum 16. Bila sebahagian nod ialah nod jalan, hanya itu yang disimpan:
    laluan Valhalla mengikut geometri jalan yang sama dan melalui nod itu (< 1 m), jadi app boleh memadan
    dengan ketat (laluan utama yang lalu 10-20 m di sebelah booth susur tidak dikira)."""
    on_way = [n for n in nodes if n.get("id") in ON_WAY_IDS]
    if on_way:
        nodes = on_way
    out = []
    for n in nodes:
        p = (n["lat"], n["lon"])
        # Hanya pendua tepat dibuang: booth dua arah boleh berjarak < 10 m (cth. Chan Sow Lin, 8 m) dan
        # setiap satu perlu kekal untuk padanan ketat 6 m.
        if all(haversine(p, q) > 2 for q in out):
            out.append(p)
        if len(out) >= 16:
            break
    if center is not None and report is not None and out and min(haversine(center, q) for q in out) > 80:
        report.append(f"- purata jauh daripada booth `{key}` ({min(haversine(center, q) for q in out):.0f} m)")
    pts = [[round(a, 6), round(b, 6)] for a, b in out]
    if on_way:
        ON_WAY_POINTS.update((a, b) for a, b in pts)
    return pts


def mark_on_way(entry):
    """`boothsOnWay: true` bila SEMUA booth entri ialah nod jalan (app memadan dengan toleransi ketat)."""
    booths = entry.get("booths")
    if booths and all((a, b) in ON_WAY_POINTS for a, b in booths):
        entry["boothsOnWay"] = True


def near_booths(osm_nodes, center, radius=150):
    """Nod booth OSM dalam [radius] m daripada koordinat alias (supaya alias juga dipadankan pada booth)."""
    return [e for e in osm_nodes if haversine((e["lat"], e["lon"]), center) <= radius]


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
        booths = []
        how = ""
        if key in aliases and aliases[key].get("lat") is not None:
            lat, lon, how = aliases[key]["lat"], aliases[key]["lon"], "alias-koordinat"
            booths = booth_points(near_booths(osm_nodes, (lat, lon)))
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
            # Utamakan nod yang arahnya sepadan; jika nama LLM tiada arah, utamakan nod OSM tanpa arah
            # (cth. "RAWANG" bukan "Rawang Selatan", yang ialah "RAWANG (S)"). Jika tiada, terima semua.
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
                    booths = booth_points(clusters[0]["nodes"], (lat, lon), report, key)
                    how = f"nama({len(clusters[0]['nodes'])} nod)"
        entry = {"id": pid, "name": pname}
        if lat is not None:
            entry["lat"], entry["lng"] = round(lat, 5), round(lon, 5)
            if booths:
                entry["booths"] = booths
            matched += 1
        else:
            report.append(f"- TIDAK DIPADANKAN `{key}`")
            report.extend(candidate_lines(pname, osm_nodes))
        out.append(entry)
    report.append(f"\n### {name}: {matched}/{n} plaza berkoordinat, {sysdata['routeCount']} laluan\n")
    return {"id": sid, "name": name, "plazas": out, "matrix": matrix}


def name_words(name):
    return {ABBREVIATIONS.get(w, w) for w in re.findall(r"[a-z0-9]+", name.lower())}


def build_open(osm_nodes, aliases, report, verified_on):
    """Plaza harga tetap daripada halaman tambang rasmi pengendali (tools/tolls/open_sources.py)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import open_sources  # noqa: PLC0415

    out = []
    for src in open_sources.SOURCES:
        try:
            rates = src["parse"](open_sources.fetch_text(src["url"]))
        except Exception as e:  # noqa: BLE001 - sumber gagal: dilaporkan, plaza kekal tidak diketahui
            report.append(f"- SUMBER GAGAL `{src['id']}` {src['url']}: {e!r}")
            continue
        for label, rate in rates.items():
            key = f"open:{src['id']}:{label}"
            points = []
            booth_sets = []
            if aliases.get(key, {}).get("lat") is not None:
                points = [(aliases[key]["lat"], aliases[key]["lon"])]
            else:
                prefixes = src["osm"][label]
                cands = [
                    e for e in osm_nodes
                    if e.get("tags", {}).get("name") and in_malaysia(e["lat"], e["lon"])
                    and any(e["tags"]["name"].lower().startswith(pf) for pf in prefixes)
                ]
                clusters = cluster(cands, 600)
                if 1 <= len(clusters) <= 2:
                    points = [c["center"] for c in clusters]
                    booth_sets = [booth_points(c["nodes"]) for c in clusters]
            if not points:
                report.append(f"- TIDAK DIPADANKAN `{key}` (RM{rate:.2f})")
                report.extend(candidate_lines(label, osm_nodes))
                continue
            for i, (lat, lon) in enumerate(points):
                entry = {
                    "id": f"{src['id']}:{label}" + (f"#{i + 1}" if len(points) > 1 else ""),
                    "name": f"{src['name']} - {label}",
                    "lat": round(lat, 5), "lng": round(lon, 5),
                    "type": "open", "ratesRm": {"1": round(rate, 2)},
                    "source": src["url"], "verifiedOn": verified_on,
                }
                if i < len(booth_sets) and booth_sets[i]:
                    entry["booths"] = booth_sets[i]
                out.append(entry)
            report.append(f"- dipadankan `{key}` RM{rate:.2f}: {len(points)} lokasi")
    return out


# Sumber halaman pengendali (open_sources.py / reported_sources.json) -> id lebuh raya LLM. Bila LLM ada kadar
# lebuh raya itu, kadar LLM digunakan; padanan OSM sumber lama (disahkan manual) hanya sandaran koordinat.
SRC_TO_LLM = {
    "ldp": "4", "sprint": "11", "llb": "21", "kesas": "2", "mex": "23", "gce": "20", "lksa": "27",
    "akleh": "13", "silk": "18", "dash": "35", "besraya": "9", "npe": "17", "spe": "36",
}


def _osm_named(osm_nodes):
    return [e for e in osm_nodes if e.get("tags", {}).get("name") and in_malaysia(e["lat"], e["lon"])]


def build_llm_open(llm, osm_nodes, aliases, report, verified_on, taken=frozenset()):
    """Plaza harga tetap daripada kalkulator LLM. Koordinat: alias, nama OSM tepat (petunjuk pengendali bila
    berbilang kelompok), atau kata kunci sumber lama bagi lebuh raya yang sama."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import open_sources  # noqa: PLC0415

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "reported_sources.json"),
              encoding="utf-8") as f:
        reported = json.load(f).get("sources", [])
    legacy = {}  # id LLM -> [(label, prefixes)]
    for src in list(open_sources.SOURCES) + reported:
        hid = SRC_TO_LLM.get(src["id"])
        if hid:
            legacy.setdefault(hid, []).extend(src["osm"].items())

    # Booth yang sudah menjadi plaza sistem tertutup tidak boleh dipakai semula oleh plaza harga tetap yang
    # kebetulan sama nama (cth. "BUKIT RAJA" NKVE/PLUS dan Grand Sepadu ialah dua plaza berbeza).
    named = [e for e in _osm_named(osm_nodes) if (round(e["lat"], 6), round(e["lon"], 6)) not in taken]
    out = []
    # Plaza berarah LLM (cth. SETIAWANGSA SELATAN/UTARA) boleh dipadankan kepada kelompok OSM yang sama:
    # satu entri sahaja bagi setiap (lebuh raya, kelompok, kadar), supaya satu laluan tidak dikira dua kali.
    seen = set()
    for p in llm.get("open", []):
        hid, hname, pname = p["highwayId"], p["highway"], p["plaza"]
        rate = next((r["rateRM"] for r in p["rates"] if r["vehicleClass"] == 1), None)
        if not rate:
            continue
        key = f"llm:{hid}:{pname}"
        clusters = []
        if aliases.get(key, {}).get("lat") is not None:
            center = (aliases[key]["lat"], aliases[key]["lon"])
            clusters = [{"center": center, "nodes": near_booths(osm_nodes, center)}]
        else:
            # 1) Kata kunci sumber lama (disahkan manual) bila label sepadan dengan nama LLM.
            words = name_words(pname)
            for label, prefixes in legacy.get(hid, []):
                if name_words(label) <= words:
                    cands = [e for e in named if any(e["tags"]["name"].lower().startswith(pf) for pf in prefixes)]
                    cl = cluster(cands, 600)
                    if 1 <= len(cl) <= 2:
                        clusters = cl
                        break
            # 2) Nama OSM tepat.
            if not clusters:
                want_tokens, want_dir = tokens(aliases.get(key, {}).get("osmName", pname))
                cands = [e for e in named if tokens(e["tags"]["name"])[0] == want_tokens]
                exact = [e for e in cands if tokens(e["tags"]["name"])[1] == want_dir]
                cl = cluster(exact or cands, 600)
                if len(cl) > 2:
                    hint = set(tokens(hname)[0]) | set(re.findall(r"[a-z]+", re.sub(r".*\(|\).*", "", hname.lower())))

                    def score(c):
                        ops = " ".join(
                            ((x.get("tags", {}).get("operator") or "") + " " + x["tags"].get("name", "")).lower()
                            for x in c["nodes"])
                        return sum(1 for h in hint if len(h) >= 3 and h in ops)
                    cl.sort(key=score, reverse=True)
                    best = score(cl[0])
                    cl = [c for c in cl if score(c) == best] if best > 0 else []
                if 1 <= len(cl) <= 2:
                    clusters = cl
        if not clusters:
            report.append(f"- TIDAK DIPADANKAN `{key}` (RM{rate:.2f})")
            report.extend(candidate_lines(pname, osm_nodes))
            continue
        for i, c in enumerate(clusters):
            lat, lon = c["center"]
            sig = (hid, round(lat, 4), round(lon, 4), round(rate, 2))
            if sig in seen:
                continue
            seen.add(sig)
            entry = {
                "id": f"llm{hid}:{pname}" + (f"#{i + 1}" if len(clusters) > 1 else ""),
                "name": f"{hname} - {pname.title()}",
                "lat": round(lat, 5), "lng": round(lon, 5),
                "type": "open", "ratesRm": {"1": round(rate, 2)},
                "source": "https://www.llm.gov.my/Calculator", "verifiedOn": verified_on,
            }
            booths = booth_points(c["nodes"]) if c["nodes"] else []
            if booths:
                entry["booths"] = booths
            out.append(entry)
        report.append(f"- dipadankan `{key}` RM{rate:.2f}: {len(clusters)} lokasi")
    return out


def build_reported(osm_nodes, report, path):
    """Kadar daripada pengumuman yang dilaporkan (tools/tolls/reported_sources.json): tiada halaman pengendali
    yang boleh dibaca. Setiap entri membawa pautan sumber dan tarikh pengumuman sendiri."""
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    out = []
    for src in doc.get("sources", []):
        for label, prefixes in src["osm"].items():
            cands = [
                e for e in osm_nodes
                if e.get("tags", {}).get("name") and in_malaysia(e["lat"], e["lon"])
                and any(e["tags"]["name"].lower().startswith(pf) for pf in prefixes)
            ]
            clusters = cluster(cands, 600)
            if not 1 <= len(clusters) <= 3:
                report.append(f"- DILAPORKAN TIDAK DIPADANKAN `{src['id']}:{label}` ({len(clusters)} kelompok)")
                continue
            for i, c in enumerate(clusters):
                lat, lon = c["center"]
                out.append({
                    "id": f"{src['id']}:{label}" + (f"#{i + 1}" if len(clusters) > 1 else ""),
                    "name": f"{src['name']} - {label}",
                    "lat": round(lat, 5), "lng": round(lon, 5),
                    "type": "open", "ratesRm": {"1": round(src["rate"], 2)},
                    "source": src["source"], "verifiedOn": src["announcedOn"], "basis": "reported",
                    "booths": booth_points(c["nodes"]),
                })
            report.append(f"- dilaporkan `{src['id']}:{label}` RM{src['rate']:.2f}: {len(clusters)} lokasi")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset-dir")
    ap.add_argument("--overpass-file")
    ap.add_argument("--llm-dataset", help="output llm_api.py (tanpa ini: dirangkak terus daripada LLM)")
    ap.add_argument("--llm-cache", help="cache respons LLM (sambung larian terputus)")
    ap.add_argument("--booth-ways", help="Overpass `way(bn)` bagi nod booth: menandakan booth yang ialah nod jalan")
    ap.add_argument("--aliases", default=os.path.join(os.path.dirname(__file__), "aliases.json"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--report", required=True)
    args = ap.parse_args()

    llm = None
    if args.llm_dataset:
        with open(args.llm_dataset, encoding="utf-8") as f:
            llm = json.load(f)
    elif not args.dataset_dir:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import llm_api  # noqa: PLC0415
            llm = llm_api.crawl(llm_api.Client(args.llm_cache))
        except Exception as e:  # noqa: BLE001 - LLM tidak dapat dicapai: sumber lama
            print("LLM gagal, guna mohdsyahid:", repr(e), file=sys.stderr)
    if llm and llm.get("closed"):
        index, systems = {"generatedAt": llm["generatedAt"]}, llm["closed"]
        source = SOURCE_LLM
    else:
        llm = None
        index, systems = load_dataset(args.dataset_dir)
        source = SOURCE
    osm = load_overpass(args.overpass_file)
    if args.booth_ways:
        with open(args.booth_ways, encoding="utf-8") as f:
            ways = json.load(f).get("elements", [])
        way_nodes = {n for w in ways for n in w.get("nodes", [])}
        ON_WAY_IDS.update(e["id"] for e in osm if e.get("id") in way_nodes)
        print("booth pada jalan:", len(ON_WAY_IDS), "/", len(osm), file=sys.stderr)
    aliases = {}
    if os.path.exists(args.aliases):
        with open(args.aliases, encoding="utf-8") as f:
            aliases = json.load(f)

    report = ["# Laporan padanan plaza tol\n"]
    closed = [build_system(s, osm, aliases, report) for s in systems]
    today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    if llm:
        report.append("\n## Lebuh raya harga tetap (kalkulator LLM)\n")
        taken = {
            (a, b) for sysd in closed for p in sysd["plazas"] for a, b in p.get("booths", [])
        }
        opens = build_llm_open(llm, osm, aliases, report, today, frozenset(taken))
    else:
        report.append("\n## Lebuh raya harga tetap (halaman tambang pengendali)\n")
        opens = build_open(osm, aliases, report, today)
        report.append("\n## Kadar dilaporkan (pengumuman kerajaan/pengendali)\n")
        opens += build_reported(osm, report, os.path.join(os.path.dirname(os.path.abspath(__file__)), "reported_sources.json"))
    for sysd in closed:
        for p in sysd["plazas"]:
            mark_on_way(p)
    for o in opens:
        mark_on_way(o)
    # Sistem tanpa satu pun koordinat tidak berguna dalam app; dilaporkan tetapi tetap ditulis.
    generated = index.get("generatedAt", "")
    doc = {
        "version": 2,
        "currency": "MYR",
        "source": source,
        "lastVerified": generated[:10] if generated else None,
        "closed": closed,
        "open": opens,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    with open(args.report, "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report))
    print("ditulis", args.out, os.path.getsize(args.out), "bait")


if __name__ == "__main__":
    main()
