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

Contoh bulanan:
  python3 tools/places/import_overture.py \\
      --release 2025-10-22.0 \\
      --out tools/places/extra/overture_my.geojson

Kemudian jalankan workflow tiles (atau build_places.py) supaya pek menyerap fail extra/.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

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


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--release", required=True, help="Id release Overture, cth. 2025-10-22.0")
    p.add_argument(
        "--out",
        default=os.path.join(os.path.dirname(__file__), "extra", "overture_my.geojson"),
        help="Laluan GeoJSON keluaran (lalai: tools/places/extra/overture_my.geojson)",
    )
    p.add_argument("--limit", type=int, default=None, help="Had baris (ujian)")
    args = p.parse_args(argv)

    print(f">> Overture places release={args.release} bbox={BBOX}", flush=True)
    rows = fetch_overture(args.release, args.limit)
    features = to_features(rows)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    doc = {
        "type": "FeatureCollection",
        "features": features,
        "attribution": "Overture Maps Foundation (CDLA Permissive 2.0)",
        "release": args.release,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False)
    print(f">> {len(features)} tempat → {args.out}", flush=True)
    print(
        "Seterusnya: commit/update tools/places/extra/ lalu jalankan tiles workflow "
        "(build_places.py memuatkan extra/ secara automatik).",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
