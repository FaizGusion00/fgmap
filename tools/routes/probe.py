#!/usr/bin/env python3
"""Probe sementara (Actions): berapa laluan BERBEZA yang sebenarnya dipulangkan oleh Valhalla awam bagi
setiap strategi alternatif? Dibuang selepas keputusan digunakan.

Output: baris `TRIP|strategi|n|...` dan ringkasan penggabungan ketat vs longgar. Simpan JSON mentah ke
tools/routes/out/ supaya boleh dijadikan fixture ujian."""
import json
import math
import os
import time
import urllib.request

URL = "https://valhalla1.openstreetmap.de/route"
UA = "fgmap-routes-probe/0.1 (+https://github.com/FaizGusion00/fgmap)"
OUT = "tools/routes/out"
os.makedirs(OUT, exist_ok=True)

TRIPS = {
    "t04km": ((3.1579, 101.7116), (3.1883, 101.6933)),
    "t08km": ((3.1579, 101.7116), (3.1177, 101.6775)),
    "t25km": ((3.1579, 101.7116), (3.0733, 101.5185)),
    "t60km": ((3.1579, 101.7116), (2.7259, 101.9378)),
    "t140km": ((3.1579, 101.7116), (2.1896, 102.2501)),
    "t330km": ((3.1579, 101.7116), (1.4927, 103.7414)),
    "penang": ((5.4141, 100.3288), (5.3550, 100.2880)),
    "johor": ((1.4927, 103.7414), (1.6550, 103.6000)),
}


def post(body, timeout=30):
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
                                 headers={"User-Agent": UA, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except Exception:  # noqa: BLE001
            return e.code, {}
    except Exception as e:  # noqa: BLE001
        return 0, {"error": repr(e)}


def decode(s, p=6):
    i = lat = lng = 0
    out = []
    while i < len(s):
        for k in (0, 1):
            r = sh = 0
            while True:
                b = ord(s[i]) - 63
                i += 1
                r |= (b & 0x1F) << sh
                sh += 5
                if b < 0x20:
                    break
            v = ~(r >> 1) if r & 1 else r >> 1
            if k == 0:
                lat += v
            else:
                lng += v
        out.append((lat / 10 ** p, lng / 10 ** p))
    return out


def dist(a, b):
    return math.hypot((a[0] - b[0]) * 111320, (a[1] - b[1]) * 111320 * math.cos(math.radians(a[0])))


def routes_of(resp):
    trips = []
    if "trip" in resp:
        trips.append(resp["trip"])
    for a in resp.get("alternates", []):
        trips.append(a["trip"])
    out = []
    for t in trips:
        pts = []
        for leg in t["legs"]:
            pts += decode(leg["shape"])
        out.append({"min": t["summary"]["time"] / 60, "km": t["summary"]["length"], "pts": pts})
    return out


def coverage(a, b, n=48, tol=40):
    """Sebahagian sampel `a` yang berada dalam `tol` m daripada polyline `b` (hampiran sampel titik)."""
    idx = [int(i * (len(a) - 1) / (n - 1)) for i in range(n)]
    hit = 0
    for i in idx:
        p = a[i]
        if min(dist(p, q) for q in b[:: max(1, len(b) // 600)]) <= tol:
            hit += 1
    return hit / n


def middle(a, cut=0.15):
    n = len(a)
    return a[int(n * cut): int(n * (1 - cut))] or a


def same(a, b, thr, mid):
    pa, pb = (middle(a), middle(b)) if mid else (a, b)
    return coverage(pa, pb) >= thr and coverage(pb, pa) >= thr


def offset_point(pts, frac, side, meters):
    i = max(1, min(len(pts) - 1, int(len(pts) * frac)))
    a, b = pts[i - 1], pts[i]
    brg = math.atan2((b[1] - a[1]) * math.cos(math.radians(a[0])), b[0] - a[0])
    perp = brg + side * math.pi / 2
    dlat = math.cos(perp) * meters / 111320
    dlng = math.sin(perp) * meters / (111320 * math.cos(math.radians(a[0])))
    return (pts[i][0] + dlat, pts[i][1] + dlng)


def circle(c, r):
    dl = r / 111320
    dg = r / (111320 * math.cos(math.radians(c[0])))
    ring = [[c[1] + dg * math.cos(2 * math.pi * k / 16), c[0] + dl * math.sin(2 * math.pi * k / 16)] for k in range(16)]
    return [ring + [ring[0]]]


def loc(p, **kw):
    d = {"lat": p[0], "lon": p[1]}
    d.update(kw)
    return d


def req(o, d, **kw):
    body = {"locations": [loc(o), loc(d)], "costing": "auto", "alternates": 0,
            "directions_type": "none"}
    body.update(kw)
    return body


summary = []
for name, (o, d) in TRIPS.items():
    cands = []  # (strategi, route)
    log = {}

    def run(strategy, body):
        t0 = time.time()
        st, resp = post(body)
        rs = routes_of(resp) if st == 200 else []
        err = None if st == 200 else (resp.get("error") or resp.get("status_message") or st)
        print(f"PROBE|{name}|{strategy}|http={st}|n={len(rs)}|{time.time()-t0:.1f}s|"
              + ("|".join(f"{r['min']:.0f}min/{r['km']:.1f}km" for r in rs)) + (f"|ERR={err}" if err else ""), flush=True)
        log[strategy] = {"status": st, "err": str(err) if err else None,
                         "routes": [{"min": r["min"], "km": r["km"]} for r in rs]}
        for r in rs:
            cands.append((strategy, r))
        time.sleep(0.4)
        return rs

    base = run("alt2", req(o, d, alternates=2))
    run("alt4", req(o, d, alternates=4))
    main = base[0]["pts"] if base else []
    if main:
        L = base[0]["km"] * 1000
        off = max(500, min(8000, 0.12 * L))
        for frac in (0.35, 0.5, 0.65):
            for side in (1, -1):
                v = offset_point(main, frac, side, off)
                body = req(o, d)
                body["locations"] = [loc(o), loc(v, type="through"), loc(d)]
                run(f"via{int(frac*100)}{'L' if side > 0 else 'R'}", body)
        for frac in (0.5, 0.35, 0.65, 0.2, 0.8):
            c = main[int(len(main) * frac)]
            run(f"excl{int(frac*100)}", req(o, d, exclude_polygons=circle(c, max(250, min(1400, 0.02 * L)))))
    run("nohw", req(o, d, costing_options={"auto": {"use_highways": 0}}))
    run("notoll", req(o, d, costing_options={"auto": {"use_tolls": 0}}))
    run("shortest", req(o, d, costing_options={"auto": {"shortest": True}}))

    # penggabungan: ketat (app semasa) vs longgar (bahagian tengah)
    def merge(mid, thr, limit):
        cs = sorted([c for c in cands], key=lambda x: x[1]["min"])
        if not cs:
            return []
        fast = cs[0][1]["min"]
        lim = max(min(fast * limit[0], fast + limit[1]), fast + 3)
        kept = []
        for s, r in cs:
            if r["min"] > lim:
                continue
            if any(same(r["pts"], k[1]["pts"], thr, mid) for k in kept):
                continue
            kept.append((s, r))
        return kept

    strict = merge(False, 0.75, (1.4, 15))
    relaxed = merge(True, 0.75, (1.6, 25))
    print(f"MERGE|{name}|raw={len(cands)}|strict={len(strict)}|relaxed={len(relaxed)}|"
          f"strict_by={[s for s,_ in strict]}|relaxed_by={[s for s,_ in relaxed]}", flush=True)
    summary.append({"trip": name, "raw": len(cands), "strict": len(strict), "relaxed": len(relaxed), "log": log})
    json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1)
    # simpan respons mentah laluan utama + alternatif untuk fixture
    st, resp = post(req(o, d, alternates=2, directions_type="maneuvers"))
    if st == 200:
        json.dump(resp, open(os.path.join(OUT, f"{name}_alt2.json"), "w"))
