#!/usr/bin/env python3
"""Eksport Overture Maps Places (Malaysia) → GeoJSON untuk tools/places/extra/.

Lesen: Overture Places ialah CDLA Permissive 2.0
  https://docs.overturemaps.org/attribution/
  https://cdla.dev/permissive-2-0/
Atribusi: "Overture Maps Foundation" (+ OpenStreetMap di mana data OSM digabung).
CDLA membenarkan pengedaran semula dalam pek offline FGMaps.

DITOLAK (ToS / saingan pangkalan tempat):
  - Google Places API / Google Maps POI dump (bulanan atau sekali setahun)
  - Scraping Google Maps
  - Kekunci API Google untuk membina indeks tempat saingan
  Jangan tambah laluan itu di sini.

Keperluan: Python 3.10+, duckdb (pip install duckdb), rangkaian untuk muat S3 Overture.

Contoh bulanan (atau biarkan Actions `.github/workflows/places-overture.yml`):
  python3 tools/places/import_overture.py --release latest \\
      --out tools/places/extra/overture_my.geojson.gz

Binaan APK / pek offline TIDAK memerlukan langkah ini di mesin tempatan — cron
bulanan + `workflow_dispatch` menulis `extra/`, dan `tiles.yml` menyerapnya pada
push ke main. Tiada laluan Google Places.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import sys
import urllib.request

# Sempadan kasar Malaysia + SG + BN (sama liputan Geofabrik pek).
BBOX = (99.5, 0.8, 119.4, 7.6)  # west, south, east, north

# Petakan kategori Overture → kind build_places.CAT
KIND_MAP = {
    "eat_and_drink": "food",
    "restaurant": "food",
    "cafe": "food",
    "bar": "food",
    "grocery": "shop",
    "retail": "shop",
    "shopping": "shop",
    "mall": "shop",
    "hotel": "lodging",
    "accommodation": "lodging",
    "health": "hospital",
    "hospital": "hospital",
    "school": "education",
    "education": "education",
    "entertainment": "tourism",
    "attraction": "tourism",
    "tourism": "tourism",
    "transport": "transport",
    "airport": "transport",
    "parking": "parking",
    "fuel": "fuel",
    "worship": "mosque",
    "religion": "mosque",
    "government": "government",
    "office": "other",
}


def kind_of(categories) -> str:
    if not categories:
        return "other"
    if isinstance(categories, dict):
        # Overture: {"primary": "...", "alternate": [...]}
        primary = categories.get("primary") or ""
        alts = categories.get("alternate") or []
        tokens = [primary, *alts]
    elif isinstance(categories, list):
        tokens = categories
    else:
        tokens = [str(categories)]
    for tok in tokens:
        t = str(tok).lower().replace(" ", "_")
        for key, kind in KIND_MAP.items():
            if key in t:
                return kind
    return "other"


def names_of(names) -> tuple[str, str]:
    """Pulangkan (name, alt) daripada struktur nama Overture."""
    if not names:
        return "", ""
    if isinstance(names, str):
        return names.strip(), ""
    common = ""
    alts = []
    if isinstance(names, dict):
        common = (names.get("common") or names.get("primary") or "")
        if isinstance(common, dict):
            # {"en": "...", "ms": "..."} — utamakan ms kemudian en
            common = common.get("ms") or common.get("en") or next(iter(common.values()), "")
        for k in ("en", "ms", "rules"):
            v = names.get(k)
            if isinstance(v, dict):
                for vv in v.values():
                    if vv and vv != common:
                        alts.append(str(vv))
            elif isinstance(v, str) and v and v != common:
                alts.append(v)
    return str(common).strip(), " ".join(dict.fromkeys(alts))


def resolve_release(release: str) -> str:
    """`latest` → id release semasa daripada STAC Overture; lain dikembalikan apa adanya."""
    if release != "latest":
        return release
    url = "https://stac.overturemaps.org/catalog.json"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "fgmap-places-overture/1.0 (+https://github.com/FaizGusion00/fgmap)"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.load(resp)
    latest = data.get("latest")
    if not isinstance(latest, str) or not latest.strip():
        raise SystemExit(f"STAC {url} tiada medan 'latest'")
    return latest.strip()


def fetch_overture(release: str, limit: int | None) -> list[dict]:
    import duckdb

    # Theme places; laluan S3 awam Overture (release bertarikh).
    # Docs: https://docs.overturemaps.org/getting-data/
    glob = (
        f"s3://overturemaps-us-west-2/release/{release}/theme=places/"
        f"type=place/*"
    )
    w, s, e, n = BBOX
    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs;")
    con.execute("INSTALL spatial; LOAD spatial;")
    con.execute("SET s3_region='us-west-2';")
    lim = f"LIMIT {int(limit)}" if limit else ""
    # Baca lajur yang biasa ada; gagal jelas jika skema release berubah.
    sql = f"""
    SELECT
      id,
      names,
      categories,
      ST_X(geometry) AS lon,
      ST_Y(geometry) AS lat,
      confidence
    FROM read_parquet('{glob}', hive_partitioning=1)
    WHERE ST_X(geometry) BETWEEN {w} AND {e}
      AND ST_Y(geometry) BETWEEN {s} AND {n}
      AND names IS NOT NULL
    {lim}
    """
    rows = con.execute(sql).fetchall()
    cols = [d[0] for d in con.description]
    return [dict(zip(cols, r)) for r in rows]


def to_features(rows: list[dict]) -> list[dict]:
    features = []
    for r in rows:
        name, alt = names_of(r.get("names"))
        if not name:
            continue
        try:
            lon, lat = float(r["lon"]), float(r["lat"])
        except (TypeError, ValueError, KeyError):
            continue
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            continue
        kind = kind_of(r.get("categories"))
        conf = r.get("confidence")
        rank = 36
        try:
            if conf is not None:
                rank = 20 + int(float(conf) * 40)
        except (TypeError, ValueError):
            pass
        features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [lon, lat]},
                "properties": {
                    "name": name,
                    "alt": alt,
                    "kind": kind,
                    "rank": rank,
                    "source": "overture",
                    "id": r.get("id"),
                },
            }
        )
    return features


def _write_geojson(path: str, doc: dict) -> str:
    """Tulis GeoJSON (atau .gz). Pulangkan sha256 hex kandungan yang ditulis."""
    payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    raw = payload.encode("utf-8")
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    if path.endswith(".gz"):
        with gzip.open(path, "wb", compresslevel=6) as f:
            f.write(raw)
    else:
        with open(path, "wb") as f:
            f.write(raw)
    return hashlib.sha256(raw).hexdigest()


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument(
        "--release",
        default="latest",
        help="Id release Overture (cth. 2025-10-22.0) atau 'latest' (STAC)",
    )
    p.add_argument(
        "--out",
        default=os.path.join(os.path.dirname(__file__), "extra", "overture_my.geojson.gz"),
        help="Laluan keluaran (.geojson atau .geojson.gz)",
    )
    p.add_argument("--limit", type=int, default=None, help="Had baris (ujian)")
    args = p.parse_args(argv)

    release = resolve_release(args.release)
    print(f">> Overture places release={release} (diminta={args.release}) bbox={BBOX}", flush=True)
    rows = fetch_overture(release, args.limit)
    features = to_features(rows)
    # Susunan stabil supaya hash sama bila data sama (elak PR kosong).
    features.sort(
        key=lambda f: (
            str((f.get("properties") or {}).get("id") or ""),
            str((f.get("properties") or {}).get("name") or ""),
        )
    )
    doc = {
        "type": "FeatureCollection",
        "features": features,
        "attribution": "Overture Maps Foundation (CDLA Permissive 2.0)",
        "release": release,
    }
    digest = _write_geojson(args.out, doc)
    meta_path = args.out + ".meta.json"
    if args.out.endswith(".gz"):
        meta_path = args.out[: -len(".gz")] + ".meta.json"
    elif args.out.endswith(".geojson"):
        meta_path = args.out[: -len(".geojson")] + ".meta.json"
    meta = {
        "release": release,
        "count": len(features),
        "sha256": digest,
        "out": os.path.basename(args.out),
        "attribution": doc["attribution"],
        "license": "CDLA Permissive 2.0",
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f">> {len(features)} tempat → {args.out} sha256={digest}", flush=True)
    print(f">> meta {meta_path}", flush=True)
    print(
        "Seterusnya: workflow places-overture membuka PR jika hash berubah; "
        "tiles.yml pada main menyerap extra/ secara automatik.",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
