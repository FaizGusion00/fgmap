#!/usr/bin/env python3
"""Semak stesen radio disahkan dalam app (app/lib/features/music/data/curated_stations.dart).

Untuk setiap stesen: ikut ubah hala, pastikan HTTP 200 dan audio sebenar diterima (untuk HLS:
ambil satu segmen). Keluar dengan kod 1 jika ada yang gagal. Hanya membaca; tiada kod daripada
respons dijalankan. Jalankan: python3 -I tools/radio/check_curated_stations.py

Menambah stesen: cari URL strim yang digunakan oleh laman/aplikasi stesen itu sendiri (bukan
tekaan), sahkan di sini, dan pastikan IDENTITI: strim StreamTheWorld memulangkan `icy-name`;
strim Revma hanya memulangkan ID jadi sahkan melalui `StreamTitle` (lagu yang sesuai dengan
stesen) dan sumber direktori. Jangan tambah stesen yang hanya ada melalui radiko (terkunci
kepada Japan) atau yang memerlukan token/tanda tangan pengguna.
"""
import pathlib
import re
import sys
import urllib.parse
import urllib.request

SRC = pathlib.Path(__file__).resolve().parents[2] / "app/lib/features/music/data/curated_stations.dart"
UA = {"User-Agent": "FGMaps-curated-check/1.0", "Icy-MetaData": "0"}


def fetch(url, n=200_000, timeout=12):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.status, (r.headers.get("Content-Type") or "").lower(), r.read(n), r.geturl()


def is_playlist(ctype, body):
    return "mpegurl" in ctype or body.lstrip().startswith(b"#EXTM3U")


def entries(body, base):
    lines = [l.strip() for l in body.decode("utf-8", "replace").splitlines() if l.strip() and not l.startswith("#")]
    return [urllib.parse.urljoin(base, l) for l in lines]


def check(url):
    status, ctype, body, final = fetch(url)
    for _ in range(2):  # senarai varian -> senarai media -> segmen
        if not is_playlist(ctype, body):
            break
        items = entries(body, final)
        if not items:
            return "senarai HLS kosong"
        status, ctype, body, final = fetch(items[0])
    if status != 200 or not body:
        return f"status {status} / kosong"
    if not any(k in ctype for k in ("audio", "aac", "ogg")):
        return f"bukan audio ({ctype})"
    return None


def main():
    text = SRC.read_text()
    names = re.findall(r"name:\s*'([^']+)'", text)
    streams = re.findall(r"stream:\s*'(https://[^']+)'", text)
    if not streams or len(names) != len(streams):
        sys.exit(f"Tidak dapat menghurai {SRC}: {len(names)} nama, {len(streams)} strim")
    bad = 0
    for name, url in zip(names, streams):
        try:
            err = check(url)
        except Exception as e:  # noqa: BLE001
            err = f"{type(e).__name__}: {e}"
        print(f"{'OK  ' if err is None else 'GAGAL'} {name:16} {'' if err is None else err}")
        bad += err is not None
    print(f"\n{len(streams) - bad}/{len(streams)} berfungsi")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
