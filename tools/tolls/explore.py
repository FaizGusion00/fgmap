#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 8: jadual tambang Prolintas / MEX / IJM dan imej DUKE."""
import os
import re
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
OUT = "tools/tolls/cache"
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            b = r.read()
            return r.status, (b if binary else b.decode("utf-8-sig", "replace"))
    except Exception as e:  # noqa: BLE001
        return 0, (b"" if binary else repr(e))


def text_of(html):
    html = re.sub(r"<(script|style|nav|footer|header)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


def anchors(html):
    return [(h, re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", a)).strip())
            for h, a in re.findall(r'<a[^>]+href="([^"#]+)"[^>]*>(.*?)</a>', html, flags=re.S | re.I)]


# Prolintas: pautan lebuh raya + jadual.
s, t = fetch("https://www.prolintas.com.my/")
hw = {}
for h, a in anchors(t):
    if re.search(r"(?i)^(AKLEH|GCE|LKSA|SILK|SUKE|DASH|KAJANG)\b", a) and h not in hw:
        hw[h] = a
print("PROLINTAS pautan lebuh raya:", hw)
for h in list(hw)[:8]:
    s, t = fetch(h)
    print(f"\n== {h} {s} len={len(t)}")
    for m in re.finditer(r"(?is)<table.*?</table>", t):
        tb = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " | ", m.group(0)))
        print("  TABLE:", tb[:1500])
    for h2, a2 in anchors(t):
        if re.search(r"(?i)toll|fare|tol|tambang|rate", a2 + h2) and "prolintas" in h2 and len(a2) < 60:
            print("   link:", a2, h2)

# MEX
s, t = fetch("https://www.mex.com.my/features-and-facilities/toll-operations/")
tx = text_of(t)
print("\n== MEX toll-operations", s, len(t), "tables", len(re.findall("<table", t, flags=re.I)))
i = tx.lower().find("class 1")
print(tx[max(0, i - 500): i + 1800] if i >= 0 else tx[:1500])

# IJM
s, t = fetch("https://www.ijm.com/our-businesses/infrastructure-toll")
print("\n== IJM", s, len(t))
for h, a in anchors(t):
    if re.search(r"(?i)npe|besraya|kl-?k|karak|toll|tol", a + h):
        print("   ", a[:50], h)

# DUKE imej tambang (disimpan supaya boleh dibaca secara visual).
for u in ("https://www.duke.com.my/files/editor_files//images/The%20Highway/kadartol.jpg",):
    s, b = fetch(u, binary=True)
    print("\n== DUKE image", u, s, len(b))
    if s == 200 and b:
        open(os.path.join(OUT, "duke_kadartol.jpg"), "wb").write(b)
