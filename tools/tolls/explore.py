#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 2: bagaimana kalkulator LLM mendapatkan kadar harga tetap."""
import json
import re
import urllib.parse
import urllib.request

UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"
B = "https://www.llm.gov.my/Calculator"


def get(url, timeout=30, data=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA}, data=data)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:300]
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


# 1. Halaman utama: semua pautan dan skrip.
s, home = get("https://www.llm.gov.my/")
print("HOME", s, len(home))
hrefs = sorted(set(re.findall(r'href="([^"#]+)"', home)))
print("HREFS", [h for h in hrefs if not h.endswith((".css", ".png", ".jpg", ".ico"))][:120])
scripts = sorted(set(re.findall(r'<script[^>]+src="([^"]+)"', home)))
print("SCRIPTS", scripts)
inline = re.findall(r"<script(?![^>]+src)[^>]*>(.*?)</script>", home, flags=re.S)
for i, code in enumerate(inline):
    if re.search(r"getTollRate|Calculator|plaza", code, re.I):
        print(f"INLINE {i}:", code[:2500])

cands = [h for h in hrefs if re.search(r"calc|tol|kalkul|kadar", h, re.I)]
print("CANDIDATE PAGES", cands)
for h in cands[:6]:
    u = urllib.parse.urljoin("https://www.llm.gov.my/", h)
    s, t = get(u)
    print("\nPAGE", u, s, len(t))
    for m in re.finditer(r"getTollRate|getPlazaExit|getPlazaEnter", t):
        print("  ...", t[max(0, m.start() - 300): m.start() + 500].replace("\n", " "))
        break
    for src in sorted(set(re.findall(r'<script[^>]+src="([^"]+)"', t)))[:10]:
        su = urllib.parse.urljoin(u, src)
        s2, js = get(su)
        if re.search(r"getTollRate", js):
            print("  JS", su, s2, len(js))
            i = js.index("getTollRate")
            print("  ", js[max(0, i - 1200): i + 1500])

# 2. Varian panggilan untuk lebuh raya harga tetap (LDP=4, plaza 010).
for path in ("getTollRate/4/010/010", "getTollRate/4/010/0", "getTollRate/4/010/", "getTollRate/4/010",
             "getPlazaExit/4/010", "getTollRate/4/010/011", "getTollRate/4/011/010",
             "getTollRate/17/101/101", "getTollRate/5/200/200"):
    s, t = get(f"{B}/{path}")
    t = re.sub(r"<[^>]+>", " ", t)
    print("\nVARIANT", path, s, re.sub(r"\s+", " ", t)[:300])
for hid in (4, 17, 5):
    s, t = get(f"{B}/getPlazaEnter/{hid}")
    print("ENTER", hid, s, t[:700])

# 3. OSM: nod bercaj.
q = '[out:json][timeout:90];area["ISO3166-1"="MY"]->.a;(node["barrier"="toll_booth"](area.a);node["highway"="toll_gantry"](area.a););out body;'
s, t = get("https://overpass-api.de/api/interpreter", timeout=120, data=urllib.parse.urlencode({"data": q}).encode())
if s == 200:
    els = json.loads(t).get("elements", [])
    for e in els:
        tg = e.get("tags", {})
        ch = {k: v for k, v in tg.items() if k.startswith("charge") or k == "fee"}
        if any(k.startswith("charge") for k in ch):
            print("CHARGE", e["id"], tg.get("name"), ch)
