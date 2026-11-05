#!/usr/bin/env python3
"""Membina direktori Masjid & Surau FGMaps daripada senarai rasmi JAKIM (data.gov.my, CC BY).

Data JAKIM tiada koordinat. Koordinat TEPAT hanya diambil daripada OpenStreetMap (ODbL) apabila nama
sepadan dengan masjid/surau OSM berhampiran pusat daerah yang sama. Selebihnya tanpa koordinat: app
mencari alamatnya (Photon/Nominatim) apabila pengguna menekan, dan menandanya "lokasi anggaran".
Tiada geokod pukal (dasar penggunaan Photon/Nominatim): hanya ~190 pusat daerah, dicache dalam
`district_centroids.json`.

Penggunaan:
  python3 tools/jakim/build_jakim.py            # muat turun CSV + OSM, tulis aset app
  python3 tools/jakim/build_jakim.py --masjid m.csv --surau s.csv --osm osm.json   # fail tempatan
"""
from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import math
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
OUT_DIR = os.path.join(ROOT, "app", "assets", "jakim")
CENTROIDS = os.path.join(HERE, "district_centroids.json")

MASJID_URL = (
    "https://archive.data.gov.my/data/dataset/4c22c771-ba28-4ce8-ae16-e5605675261e/resource/"
    "328a7b33-131c-4bd4-a49f-8b2376a7fb78/download/5senarai-masjid-di-malaysia.csv"
)
SURAU_URL = (
    "https://archive.data.gov.my/data/dataset/b6ba1723-106a-4cd7-ac94-ab5706d62a0a/resource/"
    "19f62777-c10f-46b2-be1b-158e9081f17a/download/3senarai-surau-di-malaysia.csv"
)
OVERPASS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.openstreetmap.fr/api/interpreter",
]
OSM_QUERY = (
    '[out:json][timeout:240];area["ISO3166-1"="MY"][admin_level=2]->.my;'
    '(nwr["amenity"="place_of_worship"]["religion"="muslim"](area.my);'
    'nwr["amenity"="prayer_room"](area.my);nwr["building"="mosque"](area.my););out center tags;'
)
UA = "FGMaps-build/1.0 (directory build; contact via app store listing)"

# Nama negeri JAKIM -> nama paparan.
STATES = {
    "JOHOR": "Johor", "KEDAH": "Kedah", "KELANTAN": "Kelantan", "MELAKA": "Melaka",
    "N. SEMBILAN": "Negeri Sembilan", "NEGERI SEMBILAN": "Negeri Sembilan", "PAHANG": "Pahang",
    "PERAK": "Perak", "PERLIS": "Perlis", "PULAU PINANG": "Pulau Pinang", "SABAH": "Sabah",
    "SARAWAK": "Sarawak", "SELANGOR": "Selangor", "TERENGGANU": "Terengganu",
    "W.P. KUALA LUMPUR": "Kuala Lumpur", "W.P. LABUAN": "Labuan", "W.P. PUTRAJAYA": "Putrajaya",
}
# Negeri besar: masjid boleh jauh dari pusat daerah.
WIDE = {"Sabah": 70.0, "Sarawak": 70.0, "Pahang": 45.0}
DEFAULT_RADIUS_KM = 30.0

MISSING = re.compile(r"^\s*(tiada(\s+maklumat)?|-|nil|n/?a|0+)\s*$", re.I)
# Perkataan yang dikekalkan huruf besar selepas title case.
UPPER = {"SAAS", "UIA", "UIAM", "UITM", "UKM", "UM", "UPM", "USM", "UTM", "IPD", "IPK", "JKR", "KLIA",
         "TNB", "PDRM", "ATM", "KEM", "FELDA", "FELCRA", "RISDA", "KPJ", "MRSM", "SMK", "SK", "SBP",
         "LKIM", "TLDM", "TUDM", "BPA", "BPB", "II", "III", "IV", "MPAJ", "MBSA", "MBPJ", "PPR", "KLCC"}
LOWER = {"bin", "binti", "dan", "di", "ke"}


def missing(v: str | None) -> bool:
    return v is None or not v.strip() or bool(MISSING.match(v))


def clean_text(v: str | None) -> str | None:
    if missing(v):
        return None
    s = re.sub(r"\s*\n\s*", ", ", v.strip())
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"\s*,\s*(,\s*)+", ", ", s)
    s = re.sub(r",\s*$", "", s).strip(" ,")
    return s or None


def title(v: str) -> str:
    out = []
    for i, w in enumerate(re.split(r"(\s+|-|/|\(|\))", v)):
        if not w or re.fullmatch(r"\s+|-|/|\(|\)", w):
            out.append(w)
            continue
        bare = re.sub(r"[^A-Za-z]", "", w).upper()
        if bare in UPPER and bare == re.sub(r"[^A-Za-z]", "", w).upper():
            out.append(w.upper())
        elif w.lower() in LOWER and i > 0:
            out.append(w.lower())
        elif w.lower() in {"al", "ar", "as", "an", "at", "ad", "ash", "asy", "el"} and i > 0:
            out.append(w.capitalize())
        else:
            out.append(w[:1].upper() + w[1:].lower())
    s = "".join(out)
    s = re.sub(r"\bKg\.?\s", "Kg. ", s)
    return s.strip()


def phone(v: str | None) -> str | None:
    if missing(v):
        return None
    first = re.split(r"[/,;]| atau | or ", v.strip(), flags=re.I)[0]
    digits = re.sub(r"\D", "", first)
    if digits.startswith("60"):
        digits = "0" + digits[2:]
    if len(digits) in (9, 10) and not digits.startswith("0"):
        digits = "0" + digits
    if not (9 <= len(digits) <= 11):
        return None
    return digits


def district(v: str) -> str:
    # Kod bahagian pejabat agama Sabah ("BPA - KENINGAU", "PBS - TAMPARULI") bukan sebahagian nama daerah.
    s = re.sub(r"^[A-Z]{2,4}\s*-\s*", "", v.strip().upper())
    s = re.sub(r"^(WILAYAH PERSEKUTUAN|DAERAH)\s+", "", s)
    return title(s)


TYPE_WORDS = {"masjid", "surau", "musolla", "musalla", "musollah", "mosque", "jamek", "jamik",
              "jami", "al", "ar", "as", "an", "at", "ad", "ash", "asy", "el", "dan"}
EXPAND = {"kg": "kampung", "kpg": "kampung", "tmn": "taman", "bdr": "bandar", "jln": "jalan",
          "sg": "sungai", "bt": "batu", "bkt": "bukit", "ptg": "permatang", "pdg": "padang",
          "tg": "tanjung", "lrg": "lorong", "kws": "kawasan", "pkn": "pekan"}


def tokens(name: str) -> frozenset[str]:
    s = name.lower().replace("'", "")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    out = set()
    for w in s.split():
        w = EXPAND.get(w, w)
        if w in TYPE_WORDS or len(w) < 2:
            continue
        out.add(w)
    return frozenset(out)


def km(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def fetch(url: str, data: bytes | None = None, timeout: int = 300) -> bytes:
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def read_rows(text: str, kind: str) -> list[dict]:
    rows = []
    for r in csv.DictReader(io.StringIO(text)):
        name = clean_text(r.get("SURAU") or r.get("MASJID"))
        state = STATES.get((r.get("NEGERI") or "").strip().upper())
        if not name or not state:
            continue
        rows.append({
            "type": kind,
            "name": title(name),
            "address": clean_text(r.get("ALAMAT")),
            "postcode": (re.sub(r"\D", "", r.get("POSKOD") or "")[:5] or None),
            "district": district(r.get("DAERAH") or "") or None,
            "state": state,
            "phone": phone(r.get("NO. TELEFON")),
        })
    return rows


def dedupe(rows: list[dict]) -> list[dict]:
    seen: dict[tuple, dict] = {}
    for r in rows:
        key = (r["type"], r["name"].lower(), (r["district"] or "").lower(), r["postcode"])
        prev = seen.get(key)
        # Simpan baris yang lebih lengkap.
        if prev is None or sum(v is not None for v in r.values()) > sum(v is not None for v in prev.values()):
            seen[key] = r
    return list(seen.values())


def centroids(rows: list[dict], offline: bool) -> dict[str, list[float]]:
    cache = json.load(open(CENTROIDS)) if os.path.exists(CENTROIDS) else {}
    wanted = sorted({f"{r['district']}|{r['state']}" for r in rows if r["district"]})
    todo = [k for k in wanted if k not in cache]
    if todo and offline:
        print(f"  {len(todo)} pusat daerah tiada dalam cache (mod luar talian)", file=sys.stderr)
        todo = []
    for i, key in enumerate(todo):
        d, s = key.split("|")
        q = urllib.parse.urlencode({"q": f"{d}, {s}, Malaysia", "format": "json", "limit": 1, "countrycodes": "my"})
        try:
            res = json.loads(fetch(f"https://nominatim.openstreetmap.org/search?{q}", timeout=30))
            cache[key] = [float(res[0]["lat"]), float(res[0]["lon"])] if res else None
        except Exception as e:  # noqa: BLE001
            print(f"  pusat daerah gagal {key}: {e}", file=sys.stderr)
        time.sleep(1.1)  # dasar Nominatim: <= 1 permintaan/saat
        if (i + 1) % 20 == 0:
            print(f"  pusat daerah {i + 1}/{len(todo)}", file=sys.stderr)
    with open(CENTROIDS, "w") as f:
        json.dump(dict(sorted(cache.items())), f, indent=0, ensure_ascii=False)
    return {k: v for k, v in cache.items() if v}


def osm_places(raw: dict) -> list[dict]:
    out = []
    for e in raw.get("elements", []):
        t = e.get("tags", {})
        name = t.get("name") or t.get("name:ms")
        lat = e.get("lat") or (e.get("center") or {}).get("lat")
        lon = e.get("lon") or (e.get("center") or {}).get("lon")
        if not name or lat is None or lon is None:
            continue
        tk = tokens(name)
        if not tk:
            continue
        out.append({"name": name, "tokens": tk, "p": (float(lat), float(lon)),
                    "surau": bool(re.search(r"surau|musol|musal|prayer", name, re.I)) or t.get("amenity") == "prayer_room"})
    return out


def match(rows: list[dict], osm: list[dict], cents: dict[str, list[float]]) -> None:
    # Indeks token -> calon, supaya tidak membandingkan 23k x 7k.
    by_token: dict[str, list[int]] = {}
    for i, o in enumerate(osm):
        for t in o["tokens"]:
            by_token.setdefault(t, []).append(i)
    used: dict[int, float] = {}
    best_for: list[tuple[float, int, int]] = []
    for ri, r in enumerate(rows):
        c = cents.get(f"{r['district']}|{r['state']}")
        tk = tokens(r["name"])
        if not c or not tk:
            continue
        radius = WIDE.get(r["state"], DEFAULT_RADIUS_KM)
        cands = {i for t in tk for i in by_token.get(t, [])}
        scored = []
        for i in cands:
            o = osm[i]
            inter = len(tk & o["tokens"])
            union = len(tk | o["tokens"])
            score = inter / union
            dist = km(c, o["p"])
            # Satu nama terkandung sepenuhnya dalam nama lain ("Masjid Pantai Rombang (Al-Hilal)" vs
            # "Masjid Pantai Rombang"), sekurang-kurangnya dua perkataan, dan dekat: diterima.
            if score < 0.75 and inter >= 2 and inter == min(len(tk), len(o["tokens"])) and dist <= radius * 0.6:
                score = 0.8
            if score < 0.75 or dist > radius:
                continue
            # Jenis bercanggah (masjid vs surau) mengurangkan keyakinan.
            if (r["type"] == "surau") != o["surau"]:
                score -= 0.1
            scored.append((score, i))
        scored.sort(reverse=True)
        if not scored or scored[0][0] < 0.75:
            continue
        # Nama terlalu biasa (cth. "Masjid Al-Falah" di dua tempat dalam radius): tolak jika tidak unik.
        if len(scored) > 1 and scored[1][0] >= scored[0][0] - 0.05:
            continue
        best_for.append((scored[0][0], ri, scored[0][1]))
    # Setiap tempat OSM dipadankan sekali sahaja (skor tertinggi menang).
    best_for.sort(reverse=True)
    for score, ri, oi in best_for:
        if oi in used:
            continue
        used[oi] = score
        rows[ri]["lat"], rows[ri]["lng"] = round(osm[oi]["p"][0], 6), round(osm[oi]["p"][1], 6)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--masjid")
    ap.add_argument("--surau")
    ap.add_argument("--osm")
    ap.add_argument("--offline", action="store_true", help="jangan geokod pusat daerah baharu")
    ap.add_argument("--out", default=OUT_DIR)
    a = ap.parse_args()

    masjid = open(a.masjid, encoding="utf-8", errors="replace").read() if a.masjid else fetch(MASJID_URL).decode("utf-8", "replace")
    surau = open(a.surau, encoding="utf-8", errors="replace").read() if a.surau else fetch(SURAU_URL).decode("utf-8", "replace")
    rows = dedupe(read_rows(masjid, "masjid") + read_rows(surau, "surau"))
    print(f"JAKIM: {len(rows)} tempat selepas buang pendua", file=sys.stderr)

    if a.osm:
        raw = json.load(open(a.osm))
    else:
        raw = None
        for u in OVERPASS:
            try:
                raw = json.loads(fetch(u, urllib.parse.urlencode({"data": OSM_QUERY}).encode()))
                break
            except Exception as e:  # noqa: BLE001
                print(f"  Overpass gagal {u}: {e}", file=sys.stderr)
        if raw is None:
            sys.exit("Overpass tidak tersedia")
    osm = osm_places(raw)
    print(f"OSM: {len(osm)} masjid/surau bernama", file=sys.stderr)

    cents = centroids(rows, a.offline)
    match(rows, osm, cents)

    rows.sort(key=lambda r: (r["state"], r["district"] or "", r["type"], r["name"]))
    compact = [[r["type"][0], r["name"], r["address"], r["postcode"], r["district"], r["state"], r["phone"],
                r.get("lat"), r.get("lng")] for r in rows]
    os.makedirs(a.out, exist_ok=True)
    blob = json.dumps(compact, ensure_ascii=False, separators=(",", ":")).encode()
    with gzip.GzipFile(os.path.join(a.out, "masjid_surau.json.gz"), "wb", compresslevel=9, mtime=0) as f:
        f.write(blob)
    matched = sum(1 for r in rows if r.get("lat") is not None)
    per_state = {}
    for r in rows:
        s = per_state.setdefault(r["state"], [0, 0])
        s[0] += 1
        s[1] += r.get("lat") is not None
    meta = {
        "source": "Jabatan Kemajuan Islam Malaysia (JAKIM) via data.gov.my",
        "licence": "Creative Commons Attribution (CC BY)",
        "urls": [MASJID_URL, SURAU_URL],
        "dataYear": 2019,
        "coordinates": "OpenStreetMap contributors (ODbL), name-matched near district centre",
        "builtAt": time.strftime("%Y-%m-%d"),
        "count": len(rows),
        "masjid": sum(1 for r in rows if r["type"] == "masjid"),
        "surau": sum(1 for r in rows if r["type"] == "surau"),
        "withCoordinates": matched,
    }
    with open(os.path.join(a.out, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    print(json.dumps(meta, indent=2, ensure_ascii=False), file=sys.stderr)
    for s, (n, m) in sorted(per_state.items()):
        print(f"  {s:18} {n:6} tempat, {m:5} koordinat ({100 * m / n:.0f}%)", file=sys.stderr)


if __name__ == "__main__":
    main()
