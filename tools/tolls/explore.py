#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 4: kandungan utama halaman lebuh raya LLM (kadar tol?)."""
import re
import urllib.request

UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


def text_of(html):
    html = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


for hid in (1, 2, 3, 8, 16, 24, 32):
    u = f"https://www.llm.gov.my/awam/highway/{hid}"
    s, t = get(u)
    tx = text_of(t)
    # Buang menu: ambil selepas penanda kandungan "LEBUH RAYA" kali terakhir sebelum nama lebuh raya.
    cut = tx.find("Kadar Tol")
    print(f"\n=== {u} {s} len={len(tx)} 'Kadar Tol'@{cut}")
    for m in list(re.finditer(r"(?i)kadar|toll rate|rm ?\d", tx))[:6]:
        print("  HIT:", tx[max(0, m.start() - 100): m.start() + 250])
    print("  TAIL:", tx[-1500:-400])
    docs = sorted(set(re.findall(r'href="([^"]+\.(?:pdf|xlsx?|docx?|csv|json))"', t, flags=re.I)))
    print("  DOCS:", docs[:20])
