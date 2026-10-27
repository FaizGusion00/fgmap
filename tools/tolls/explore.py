#!/usr/bin/env python3
"""Penerokaan sementara (dijalankan dalam GitHub Actions): titik akhir kalkulator LLM dan Overpass."""
import json
import re
import sys
import urllib.parse
import urllib.request

UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"
B = "https://www.llm.gov.my/Calculator"


def get(url, timeout=40, data=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA}, data=data)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:600]
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


def jget(path):
    s, t = get(f"{B}/{path}")
    try:
        return s, json.loads(t)
    except Exception:  # noqa: BLE001
        return s, t[:500]


s, hw = jget("getHighway")
print("getHighway", s, json.dumps(hw, ensure_ascii=False)[:2500])
if isinstance(hw, list):
    for h in hw:
        hid = h.get("id")
        if hid in ("", None):
            continue
        s1, enter = jget(f"getPlazaEnter/{hid}")
        plazas = [p for p in enter if p.get("id") != ""] if isinstance(enter, list) else enter
        n = len(plazas) if isinstance(plazas, list) else "?"
        print(f"\n== {hid} {h.get('name')}: enter {s1} n={n}")
        if isinstance(plazas, list) and plazas and hid in (2, 4, 11, 7, 17, 5, 23, 25, 15, 13, 36, 9, 12, 20, 18):
            print("  plazas:", [p.get("name") for p in plazas][:12])
            p0 = plazas[0]["id"]
            s2, ex = jget(f"getPlazaExit/{hid}/{p0}")
            print("  exit", s2, json.dumps(ex, ensure_ascii=False)[:500])
            ex_ids = [e["id"] for e in ex if isinstance(ex, list) and e.get("id") != ""] if isinstance(ex, list) else []
            for e_id in (ex_ids[:2] or [p0]):
                s3, rate = jget(f"getTollRate/{hid}/{p0}/{e_id}")
                print(f"  rate {p0}->{e_id}", s3, json.dumps(rate, ensure_ascii=False)[:500])

for url in ("https://www.llm.gov.my/", "https://www.llm.gov.my/Calculator", "https://www.llm.gov.my/Calculator/Index"):
    s, t = get(url)
    print("\nPAGE", url, s, len(t))
    print(sorted(set(re.findall(r'(?:href|src)="([^"]*(?:[Tt]ol|[Cc]alc|[Kk]adar)[^"]*)"', t)))[:40])
    print(sorted(set(re.findall(r"(?:Calculator/[A-Za-z]+|get[A-Z][A-Za-z]+)", t)))[:40])

q = '[out:json][timeout:90];area["ISO3166-1"="MY"]->.a;(node["barrier"="toll_booth"](area.a);node["highway"="toll_gantry"](area.a););out body;'
for u in ("https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter"):
    s, t = get(u, timeout=120, data=urllib.parse.urlencode({"data": q}).encode())
    print("\nOVERPASS", u, s, len(t))
    if s == 200:
        els = json.loads(t).get("elements", [])
        print("nodes", len(els), "named", sum(1 for e in els if e.get("tags", {}).get("name")),
              "charge", sum(1 for e in els if any(k.startswith("charge") for k in e.get("tags", {}))))
        for e in els[:70]:
            tg = e.get("tags", {})
            print(e["id"], round(e["lat"], 5), round(e["lon"], 5), tg.get("name"), tg.get("operator"), tg.get("ref"))
        break
sys.exit(0)
