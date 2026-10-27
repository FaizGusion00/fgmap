#!/usr/bin/env python3
"""Probe sementara (Actions): berapa laluan BERBEZA yang sebenarnya dipulangkan oleh Valhalla awam bagi
setiap strategi alternatif? Dibuang selepas keputusan digunakan.

Output: baris `TRIP|strategi|n|...` dan ringkasan penggabungan ketat vs longgar. Simpan JSON mentah ke
tools/routes/out/ supaya boleh dijadikan fixture ujian."""
import json
import math
import os
import time
import urllib.parse
import urllib.request

URL = "https://valhalla1.openstreetmap.de/route"
UA = "fgmap-routes-probe/0.1 (+https://github.com/FaizGusion00/fgmap)"
OUT = "tools/promo/data"
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
            "directions_type": "maneuvers"}
    body.update(kw)
    return body



O = (3.1579, 101.7116)  # KLCC
D = (2.7456, 101.7072)  # KLIA
manifest = []


def save(name, body):
    st, resp = post(body, timeout=60)
    print(f"FETCH|{name}|http={st}", flush=True)
    if st == 200 and "trip" in resp:
        json.dump(resp, open(os.path.join(OUT, f"{name}.json"), "w"))
        manifest.append(name)
    time.sleep(0.5)
    return resp if st == 200 else None


base = save("standard", req(O, D, alternates=2))
main = decode(base["trip"]["legs"][0]["shape"])
L = base["trip"]["summary"]["length"] * 1000
save("noTolls", req(O, D, costing_options={"auto": {"use_tolls": 0}}))
save("noHighways", req(O, D, costing_options={"auto": {"use_highways": 0}}))
save("shortest", req(O, D, costing_options={"auto": {"shortest": True}}))
off = max(400, min(5000, 0.07 * L))
for i, (frac, side) in enumerate(((0.35, 1), (0.65, -1), (0.5, 1), (0.5, -1), (0.25, -1), (0.75, 1))):
    v = offset_point(main, frac, side, off)
    body = req(O, D)
    body["locations"] = [loc(O), loc(v, type="through"), loc(D)]
    save(f"via{i}", body)
c = main[int(len(main) * 0.5)]
save("excl", req(O, D, exclude_polygons=circle(c, max(250, min(1400, 0.02 * L)))))
json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"))

# Nod plaza tol OSM (Overpass) untuk menganggar tol sebenar bagi setiap laluan.
q = ('[out:json][timeout:120];area["ISO3166-1"="MY"]->.a;'
     '(node(area.a)["barrier"="toll_booth"];node(area.a)["highway"="toll_gantry"];);out body;')
for host in ("https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"):
    try:
        r = urllib.request.Request(host, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": UA})
        els = json.loads(urllib.request.urlopen(r, timeout=150).read())["elements"]
        json.dump({"elements": [{"type": "node", "id": e["id"], "lat": e["lat"], "lon": e["lon"],
                                 "tags": {k: v for k, v in e.get("tags", {}).items() if k in ("name", "operator")}}
                                for e in els]},
                  open(os.path.join(OUT, "toll_nodes.json"), "w"))
        print("OVERPASS nod:", len(els), flush=True)
        break
    except Exception as e:  # noqa: BLE001
        print("overpass gagal", host, repr(e), flush=True)
