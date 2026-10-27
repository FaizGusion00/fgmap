#!/usr/bin/env python3
"""Penerokaan sementara (Actions), pusingan 3: halaman lebuh raya LLM untuk kadar tol harga tetap."""
import re
import urllib.parse
import urllib.request

UA = "fgmap-tolls/0.1 (+https://github.com/FaizGusion00/fgmap)"
ROOT = "https://www.llm.gov.my/"


def get(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode("utf-8-sig", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:300]
    except Exception as e:  # noqa: BLE001
        return 0, repr(e)


def text_of(html):
    html = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


seen = set()
queue = ["awam/highway", "awam/data", "maps/index", "pages/view/faq"]
for page in queue:
    u = urllib.parse.urljoin(ROOT, page)
    s, t = get(u)
    print("\n=== PAGE", u, s, len(t))
    links = sorted(set(re.findall(r'href="([^"#]+)"', t)))
    inter = [l for l in links if "llm.gov.my" in l or not l.startswith("http")]
    print("LINKS", [l for l in inter if not l.endswith((".css", ".png", ".jpg", ".ico", ".js"))][:80])
    tx = text_of(t)
    for m in re.finditer(r"(?i)(kadar tol|toll rate|rm ?\d+\.\d{2})", tx):
        print("  HIT:", tx[max(0, m.start() - 120): m.start() + 200])
        break
    print("TEXT:", tx[:1200])
    for l in inter:
        if re.search(r"highway|lebuhraya|tol", l, re.I) and l not in seen and len(seen) < 12:
            seen.add(l)
            queue.append(l)
