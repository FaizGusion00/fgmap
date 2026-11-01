#!/usr/bin/env python3
"""Mengesahkan fail PMTiles v3 sebelum diterbitkan: pengepala, liputan Malaysia, dan lapisan OpenMapTiles.

Hanya pustaka standard. Penggunaan:
  verify_pmtiles.py <fail.pmtiles> [--min-bytes N] [--layers a,b,c] [--point lon,lat]...
Mencetak ringkasan JSON (maxZoom, bounds, layers, sizeBytes) pada stdout; keluar bukan sifar jika gagal.
"""
import argparse
import gzip
import json
import os
import struct
import sys


def fail(msg):
    print(f"GAGAL: {msg}", file=sys.stderr)
    sys.exit(1)


def read_info(path):
    with open(path, "rb") as f:
        head = f.read(127)
        if len(head) < 127 or head[:7] != b"PMTiles":
            fail("bukan fail PMTiles")
        if head[7] != 3:
            fail(f"versi PMTiles {head[7]} tidak disokong (perlu 3)")
        meta_off, meta_len = struct.unpack("<QQ", head[24:40])
        internal_comp, tile_comp, tile_type, min_z, max_z = head[97:102]
        min_lon, min_lat, max_lon, max_lat = (
            v / 1e7 for v in struct.unpack("<4i", head[102:118])
        )
        f.seek(meta_off)
        raw = f.read(meta_len)
    if internal_comp == 2:
        raw = gzip.decompress(raw)
    elif internal_comp not in (0, 1):
        fail(f"pemampatan metadata {internal_comp} tidak disokong")
    meta = json.loads(raw) if raw else {}
    return {
        "tileType": tile_type,
        "tileCompression": tile_comp,
        "minZoom": min_z,
        "maxZoom": max_z,
        "bounds": [min_lon, min_lat, max_lon, max_lat],
        "layers": sorted(l["id"] for l in meta.get("vector_layers", [])),
        "name": meta.get("name"),
        "sizeBytes": os.path.getsize(path),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--min-bytes", type=int, default=1)
    ap.add_argument("--layers", default="")
    ap.add_argument("--point", action="append", default=[])
    a = ap.parse_args()

    info = read_info(a.file)
    if info["tileType"] != 1:
        fail(f"jenis tile {info['tileType']} bukan vektor (MVT)")
    if info["sizeBytes"] < a.min_bytes:
        fail(f"fail terlalu kecil: {info['sizeBytes']} < {a.min_bytes}")
    need = [l for l in a.layers.split(",") if l]
    missing = [l for l in need if l not in info["layers"]]
    if missing:
        fail(f"lapisan hilang {missing}; ada {info['layers']}")
    for p in a.point:
        lon, lat = (float(v) for v in p.split(","))
        w, s, e, n = info["bounds"]
        if not (w <= lon <= e and s <= lat <= n):
            fail(f"titik {p} di luar sempadan {info['bounds']}")
    print(json.dumps(info))


if __name__ == "__main__":
    main()
