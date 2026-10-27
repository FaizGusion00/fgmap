#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 5: kadar tol lebuh raya harga tetap daripada pengendali + OSM."""
import json
import re
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (compatible; fgmap-tolls/0.1; +https://github.com/FaizGusion00/fgmap)"


def get(url, data=None, timeout=40):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


def text_of(html):
    html = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


# 1) Nod OSM dengan tag charge (ringkas).
q = ('[out:json][timeout:120];area["ISO3166-1"="MY"]->.a;'
     '(node(area.a)["barrier"="toll_booth"]["charge"];node(area.a)["highway"="toll_gantry"]["charge"];);out body;')
s, body = get("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": q}).encode(), 150)
print("OSM charge status", s)
try:
    for e in json.loads(body)["elements"]:
        t = e["tags"]
        print("CHG", e["lat"], e["lon"], "|", t.get("name"), "|", t.get("operator"), "|", t.get("charge"),
              "|", {k: v for k, v in t.items() if k.startswith("charge") and k != "charge"}, "|", t.get("check_date") or t.get("source"))
except Exception as ex:  # noqa: BLE001
    print("OSM parse gagal", repr(ex), body[:200])

# 2) Halaman pengendali (URL daripada halaman LLM) + pautan berkaitan kadar.
OPS = {
    "LDP/LITRAK": "http://www.litrak.com.my",
    "BESRAYA/NPE/KLK (IJM)": "http://www.ijm.com/infrastructure/toll/besraya/",
    "NPE": "http://www.ijm.com/infrastructure/toll/npe/",
    "SPE/DUKE": "https://www.duke.com.my/page/175/SETIAWANGSA-PANTAI-EXPRESSWAY-(SPE)/",
    "SILK/Prolintas": "http://www.prolintas.com.my",
    "KESAS": "https://www.kesas.com.my",
    "JPP2": "http://www.jambatankedua.com.my",
    "LLB/JPP1": "http://www.llb.com.my",
    "SMART": "https://smarttunnel.com.my",
    "SKVE": "https://www.skve.com.my",
}
for name, url in OPS.items():
    s, t = get(url)
    print(f"\n=== {name} {url} -> {s} len={len(t)}")
    if s != 200:
        print("  ", t[:150])
        continue
    links = sorted(set(re.findall(r'href="([^"#]+)"', t)))
    rate_links = [l for l in links if re.search(r"(?i)rate|kadar|toll|tol|fare|tariff", l)][:15]
    print("  RATE LINKS:", rate_links)
    tx = text_of(t)
    for m in list(re.finditer(r"(?i)rm ?\d+\.\d{2}", tx))[:3]:
        print("  RM:", tx[max(0, m.start() - 80): m.start() + 120])
