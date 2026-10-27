#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 6: halaman tambang tol rasmi pengendali (teks atau gambar?)."""
import re
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
PAGES = [
    "https://litrak.com.my/our-highways/litrak/toll-fares/",
    "https://litrak.com.my/our-highways/sprint/toll-fares/",
    "https://www.duke.com.my/page/143/Toll-Fare/",
    "https://www.duke.com.my/page/192/Toll-Fare/",
    "https://llb.com.my/tambang-tol/",
    "https://kesas.com.my/toll-lane/",
]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html,*/*"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


def text_of(html):
    html = re.sub(r"<(script|style|nav|footer|header)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


for u in PAGES:
    s, t = get(u)
    print(f"\n=== {u} -> {s} len={len(t)}")
    if s != 200:
        print("  ", t[:200])
        continue
    tx = text_of(t)
    rms = len(re.findall(r"(?i)rm ?\d+\.\d{2}|\b\d+\.\d{2}\b", tx))
    print("  tables:", len(re.findall(r"<table", t, flags=re.I)), "angka harga:", rms,
          "img:", len(re.findall(r"<img", t, flags=re.I)),
          "pdf/xls:", sorted(set(re.findall(r'href="([^"]+\.(?:pdf|xlsx?))"', t, flags=re.I)))[:10])
    i = tx.lower().find("class 1")
    i = i if i >= 0 else tx.lower().find("kelas 1")
    print("  TEXT:", tx[max(0, i - 400): i + 2500] if i >= 0 else tx[:2000])
    imgs = [m for m in re.findall(r'<img[^>]+src="([^"]+)"', t) if re.search(r"(?i)fare|tol|toll|tambang|rate", m)]
    print("  IMGS:", imgs[:10])
