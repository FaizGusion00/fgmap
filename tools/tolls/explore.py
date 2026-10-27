#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 9: senarai ringkas semua plaza tol OSM Malaysia (nama, pengendali)."""
import json
import math
import urllib.parse
import urllib.request

UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"
q = ('[out:json][timeout:120];area["ISO3166-1"="MY"]->.a;'
     '(node(area.a)["barrier"="toll_booth"];node(area.a)["highway"="toll_gantry"];);out body;')
req = urllib.request.Request("https://overpass-api.de/api/interpreter",
                             data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": UA})
els = json.loads(urllib.request.urlopen(req, timeout=150).read())["elements"]


def d(a, b):
    return math.hypot((a[0] - b[0]) * 111000, (a[1] - b[1]) * 111000 * math.cos(math.radians(a[0])))


clusters = []
for e in els:
    p = (e["lat"], e["lon"])
    for c in clusters:
        if d(p, c["p"]) < 600 and (e["tags"].get("name") or "") == c["name"]:
            c["n"] += 1
            break
    else:
        clusters.append({"p": p, "name": e["tags"].get("name") or "", "op": e["tags"].get("operator") or "", "n": 1,
                         "ref": e["tags"].get("ref") or ""})
clusters.sort(key=lambda c: (c["p"][0] > 5.5, -c["p"][1] if False else c["p"][1], c["p"][0]))
print("KLUSTER", len(clusters))
for c in sorted(clusters, key=lambda c: c["name"].lower()):
    print(f'CL|{c["name"]}|{c["op"]}|{c["p"][0]:.5f},{c["p"][1]:.5f}|{c["n"]}')
