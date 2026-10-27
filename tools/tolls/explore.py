#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 7: tambang tol rasmi Prolintas, LITRAK (LDP), MEX."""
import re
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"


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


def anchors(html):
    return [(h, re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", a)).strip())
            for h, a in re.findall(r'<a[^>]+href="([^"#]+)"[^>]*>(.*?)</a>', html, flags=re.S | re.I)]


KEY = re.compile(r"(?i)toll|fare|tol\b|tambang|kadar|rate")
for base in ("https://www.prolintas.com.my/", "https://www.mex.com.my/", "https://www.ijm.com/", "https://www.lebuhrayakajang.com.my/"):
    s, t = get(base)
    print(f"\n##### {base} -> {s} len={len(t)}")
    if s == 200:
        seen = set()
        for h, a in anchors(t):
            if KEY.search(a) or KEY.search(h):
                if h not in seen and len(seen) < 40:
                    seen.add(h)
                    print("   ", a[:60], "->", h)

for u in ("https://www.prolintas.com.my/?p=270", "https://litrak.com.my/our-highways/litrak/toll-fares/"):
    s, t = get(u)
    tx = text_of(t)
    print(f"\n===== {u} -> {s} len={len(t)} tables={len(re.findall('<table', t, flags=re.I))}")
    i = tx.lower().find("class 1")
    print(tx[max(0, i - 600): i + 3000] if i >= 0 else tx[:2500])
