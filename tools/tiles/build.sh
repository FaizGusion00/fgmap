#!/usr/bin/env bash
# Membina pek tile Valhalla untuk app (laluan offline dalam peranti).
#
# Versi Valhalla WAJIB sepadan dengan yang tertanam dalam valhalla-mobile (lihat tools/tiles/VERSIONS).
# Tile yang dibina dengan versi lain boleh ditolak atau menghasilkan laluan yang salah.
#
# Penggunaan: tools/tiles/build.sh <fail.osm.pbf> <direktori-output> [versi-pek]
#   versi-pek  lalai: tarikh UTC hari ini (YYYYMMDD), cth. 20261026
#
# Hasil dalam <direktori-output>:
#   valhalla_tiles.tar           pek untuk enjin (mjolnir.tile_extract)
#   malaysia-<versi>.tar.gz      pek untuk dimuat turun oleh app
#   manifest.json                versi, url (diisi semasa terbit), saiz, sha256
set -euo pipefail

PBF=${1:?usage: build.sh <file.osm.pbf> <outdir> [pack-version]}
OUT=${2:?usage: build.sh <file.osm.pbf> <outdir> [pack-version]}
PACK_VERSION=${3:-$(date -u +%Y%m%d)}

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=VERSIONS
source "$HERE/VERSIONS"

mkdir -p "$OUT"
PBF_DIR=$(cd "$(dirname "$PBF")" && pwd)
PBF_NAME=$(basename "$PBF")
OUT=$(cd "$OUT" && pwd)

IMAGE="ghcr.io/valhalla/valhalla-scripted:${VALHALLA_VERSION}"
echo ">> Valhalla ${VALHALLA_VERSION} (${IMAGE}), pbf=${PBF_NAME}, pek=${PACK_VERSION}"

rm -rf "$OUT/valhalla_tiles" "$OUT/valhalla_tiles.tar"

docker run --rm \
  -v "$PBF_DIR":/in:ro -v "$OUT":/out \
  --entrypoint /bin/bash "$IMAGE" -euxc '
    valhalla_build_config \
      --mjolnir-tile-dir /out/valhalla_tiles \
      --mjolnir-tile-extract /out/valhalla_tiles.tar \
      --mjolnir-timezone /out/timezones.sqlite \
      --mjolnir-admin /out/admins.sqlite \
      --mjolnir-concurrency 4 > /out/valhalla.json
    valhalla_build_timezones > /out/timezones.sqlite
    valhalla_build_admins -c /out/valhalla.json /in/'"$PBF_NAME"'
    valhalla_build_tiles  -c /out/valhalla.json /in/'"$PBF_NAME"'
    valhalla_build_extract -c /out/valhalla.json -v
  '

TAR="$OUT/valhalla_tiles.tar"
[ -s "$TAR" ] || { echo "GAGAL: $TAR tiada atau kosong" >&2; exit 1; }

PACK="malaysia-${PACK_VERSION}.tar.gz"
echo ">> Memampatkan -> $PACK"
gzip -9 -c "$TAR" > "$OUT/$PACK"

SHA=$(shasum -a 256 "$OUT/$PACK" | cut -d' ' -f1)
RAW_SIZE=$(stat -f%z "$TAR" 2>/dev/null || stat -c%s "$TAR")
PACK_SIZE=$(stat -f%z "$OUT/$PACK" 2>/dev/null || stat -c%s "$OUT/$PACK")
RAW_SHA=$(shasum -a 256 "$TAR" | cut -d' ' -f1)

cat > "$OUT/manifest.json" <<JSON
{
  "schema": 1,
  "region": "malaysia",
  "version": "${PACK_VERSION}",
  "valhalla": "${VALHALLA_VERSION}",
  "file": "${PACK}",
  "sizeBytes": ${PACK_SIZE},
  "sha256": "${SHA}",
  "extractedSizeBytes": ${RAW_SIZE},
  "extractedSha256": "${RAW_SHA}"
}
JSON
echo ">> Siap:"; cat "$OUT/manifest.json"
