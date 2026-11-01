#!/usr/bin/env bash
# Membina tile paparan peta offline (PMTiles, skema OpenMapTiles) untuk app.
#
# Penggunaan: tools/basemap/build.sh <fail.osm.pbf> <direktori-output> [versi-pek]
#   versi-pek  lalai: tarikh UTC hari ini (YYYYMMDD); MESTI sama dengan versi pek laluan.
#
# Hasil dalam <direktori-output>:
#   basemap-<versi>.pmtiles   tile untuk dimuat turun app (mentah: tile PMTiles sudah dimampatkan)
#   manifest.json             (jika ada) ditambah medan `basemap` {file, sizeBytes, sha256, maxZoom, schema}
#
# Keperluan: Java 21+ dan sambungan internet (Planetiler memuat turun Natural Earth dan poligon air).
# Planetiler (Apache 2.0) dimuat turun daripada Release rasmi dan sha256-nya disemak sebelum dijalankan.
set -euo pipefail

PBF=${1:?usage: build.sh <file.osm.pbf> <outdir> [pack-version]}
OUT=${2:?usage: build.sh <file.osm.pbf> <outdir> [pack-version]}
VERSION=${3:-$(date -u +%Y%m%d)}

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=VERSIONS
source "$HERE/VERSIONS"

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
PBF=$(cd "$(dirname "$PBF")" && pwd)/$(basename "$PBF")
CACHE="$HERE/.cache"
mkdir -p "$CACHE"

# Java 21+: JAVA_HOME_21_X64 wujud pada runner GitHub; jika tidak, guna java dalam PATH.
JAVA=java
if [ -n "${JAVA_HOME_21_X64:-}" ] && [ -x "$JAVA_HOME_21_X64/bin/java" ]; then
  JAVA="$JAVA_HOME_21_X64/bin/java"
fi
JV=$("$JAVA" -version 2>&1 | head -1)
echo ">> Java: $JV"
MAJOR=$("$JAVA" -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')
[ "${MAJOR:-0}" -ge 21 ] || { echo "GAGAL: perlu Java 21+, ada: $JV" >&2; exit 1; }

JAR="$CACHE/planetiler-${PLANETILER_VERSION}.jar"
if [ ! -f "$JAR" ]; then
  echo ">> Muat turun Planetiler ${PLANETILER_VERSION}"
  curl -fsSL --retry 3 -o "$JAR.tmp" \
    "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"
  mv "$JAR.tmp" "$JAR"
fi
ACTUAL=$( (sha256sum "$JAR" 2>/dev/null || shasum -a 256 "$JAR") | cut -d' ' -f1)
if [ "$ACTUAL" != "$PLANETILER_SHA256" ]; then
  echo "GAGAL: sha256 Planetiler tidak sepadan (jangkaan $PLANETILER_SHA256, dapat $ACTUAL)" >&2
  rm -f "$JAR"
  exit 1
fi

FILE="basemap-${VERSION}.pmtiles"
rm -f "$OUT/$FILE"
echo ">> Membina $FILE (maxzoom ${BASEMAP_MAXZOOM})"
JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx5g}" "$JAVA" -jar "$JAR" \
  --osm-path="$PBF" \
  --download --download_dir="$CACHE/sources" \
  --tmpdir="$CACHE/tmp" \
  --output="$OUT/$FILE" --force \
  --maxzoom="${BASEMAP_MAXZOOM}"

[ -s "$OUT/$FILE" ] || { echo "GAGAL: $OUT/$FILE tiada atau kosong" >&2; exit 1; }

# Skema OpenMapTiles + liputan Kuala Lumpur, Johor Bahru, Kota Kinabalu dan Kuching.
python3 "$HERE/verify_pmtiles.py" "$OUT/$FILE" --min-bytes 50000000 \
  --layers transportation,water,place,poi,building,landuse,transportation_name \
  --point 101.6869,3.139 --point 103.7414,1.4927 --point 116.0735,5.9788 --point 110.3593,1.5535 \
  > "$OUT/basemap.info.json"
cat "$OUT/basemap.info.json"

python3 - "$OUT" "$FILE" "$BASEMAP_MAXZOOM" <<'PY'
import hashlib, json, os, sys
out, file, maxzoom = sys.argv[1], sys.argv[2], int(sys.argv[3])
path = os.path.join(out, file)
h = hashlib.sha256()
with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
        h.update(chunk)
entry = {"file": file, "sizeBytes": os.path.getsize(path), "sha256": h.hexdigest(),
         "maxZoom": maxzoom, "schema": 1}
manifest = os.path.join(out, "manifest.json")
if os.path.exists(manifest):
    with open(manifest) as f:
        m = json.load(f)
    m["basemap"] = entry
    with open(manifest, "w") as f:
        json.dump(m, f, indent=2)
        f.write("\n")
print(">> basemap:", json.dumps(entry))
PY
