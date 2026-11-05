#!/usr/bin/env python3
"""Merangkak kalkulator tol RASMI Lembaga Lebuhraya Malaysia (https://www.llm.gov.my/Calculator).

Titik akhir awam (tanpa kunci), digunakan oleh laman LLM sendiri:
  GET /Calculator/getHighway                         -> [{id, name}]
  GET /Calculator/getPlazaEnter/{hw}                 -> [{id, name}]
  GET /Calculator/getPlazaExit/{hw}/{entry}          -> [{id, name}] (kosong = plaza harga tetap)
  GET /Calculator/getTollRate/{hw}/{entry}/{exit|null} -> [{transCode, rate, distance}]

Hasil dalam bentuk yang sama dengan dataset mohdsyahid/kadar-tol-malaysia (supaya build_tolls.build_system
boleh digunakan semula) ditambah senarai plaza harga tetap. Sopan: satu permintaan pada satu masa, jeda
antara permintaan, cuba semula dengan undur. Respons dicache dalam fail JSON supaya larian yang terputus
boleh disambung.

Penggunaan sendiri: llm_api.py --cache llm_cache.json --out llm_dataset.json
"""
import argparse
import datetime
import json
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
import urllib.parse
import urllib.request

BASE = "https://www.llm.gov.my/Calculator/"
UA = "fgmap-tolls/0.2 (+https://github.com/FaizGusion00/fgmap)"


class Client:
    def __init__(self, cache_path=None, delay=0.25):
        self.cache_path = cache_path
        self.delay = delay
        self.cache = {}
        self.fetched = 0
        self.lock = threading.Lock()
        if cache_path and os.path.exists(cache_path):
            with open(cache_path, encoding="utf-8") as f:
                self.cache = json.load(f)

    def save(self):
        if not self.cache_path:
            return
        tmp = self.cache_path + ".tmp"
        with self.lock:
            snapshot = dict(self.cache)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(snapshot, f, ensure_ascii=False, separators=(",", ":"))
        os.replace(tmp, self.cache_path)

    def get(self, path):
        with self.lock:
            if path in self.cache:
                return self.cache[path]
        last = None
        for attempt in range(5):
            try:
                req = urllib.request.Request(
                    BASE + urllib.parse.quote(path, safe="/"),
                    headers={"User-Agent": UA, "Accept": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=40) as r:
                    data = json.loads(r.read().decode("utf-8-sig"))
                with self.lock:
                    self.cache[path] = data
                    self.fetched += 1
                    n = self.fetched
                if n % 500 == 0:
                    self.save()
                    print(f"  {n} permintaan", file=sys.stderr)
                time.sleep(self.delay)
                return data
            except Exception as e:  # noqa: BLE001 - dicuba semula, kemudian gagal dengan jelas
                last = e
                time.sleep(2 * (attempt + 1))
        raise RuntimeError(f"LLM gagal: {path}: {last!r}")


def _items(rows):
    """Buang pilihan "Sila Pilih ..." (id kosong)."""
    return [r for r in rows or [] if str(r.get("id", "")).strip() != ""]


def _rates(rows):
    out = []
    for r in rows or []:
        cls, rate = r.get("transCode"), r.get("rate")
        if isinstance(cls, int) and isinstance(rate, (int, float)) and rate > 0:
            out.append({"vehicleClass": cls, "rateRM": round(float(rate), 2)})
    return out


def crawl(client, only=None, workers=4):
    """-> {"generatedAt", "highways": [...], "closed": [sysdata], "open": [{...}]}"""
    highways = _items(client.get("getHighway"))
    closed, opens, index = [], [], []
    for h in highways:
        hid, hname = str(h["id"]), h["name"].strip()
        if only and hid not in only:
            continue
        entries = _items(client.get(f"getPlazaEnter/{hid}"))
        routes = []
        open_count = 0
        for e in entries:
            eid, ename = str(e["id"]), e["name"].strip()
            exits = _items(client.get(f"getPlazaExit/{hid}/{eid}"))
            if not exits:
                rates = _rates(client.get(f"getTollRate/{hid}/{eid}/null"))
                if rates:
                    opens.append({"highwayId": hid, "highway": hname, "plazaId": eid, "plaza": ename,
                                  "rates": rates})
                    open_count += 1
                continue
            # Beberapa permintaan serentak (sopan: had kecil + jeda setiap pekerja).
            with ThreadPoolExecutor(max_workers=workers) as pool:
                got = list(pool.map(lambda x: client.get(f"getTollRate/{hid}/{eid}/{x['id']}"), exits))
            for x, raw in zip(exits, got):
                xid, xname = str(x["id"]), x["name"].strip()
                rates = _rates(raw)
                if rates:
                    routes.append({"entryPlazaId": eid, "entryPlaza": ename, "exitPlazaId": xid,
                                   "exitPlaza": xname, "rates": rates})
        if routes:
            closed.append({"highwayId": hid, "highway": hname, "routes": routes, "routeCount": len(routes)})
        index.append({"id": hid, "name": hname, "routeCount": len(routes), "openCount": open_count})
        print(f"{hid} {hname}: {len(routes)} pasangan, {open_count} plaza harga tetap", file=sys.stderr)
        client.save()
    return {
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "highways": index,
        "closed": closed,
        "open": opens,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache")
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", help="senarai id lebuh raya, dipisah koma (ujian)")
    ap.add_argument("--delay", type=float, default=0.25)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    client = Client(args.cache, args.delay)
    data = crawl(client, set(args.only.split(",")) if args.only else None, args.workers)
    client.save()
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("ditulis", args.out, "permintaan baharu:", client.fetched, file=sys.stderr)


if __name__ == "__main__":
    main()
