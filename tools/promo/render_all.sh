#!/usr/bin/env bash
# Render video v2 selari (N bahagian) kemudian cantum. Guna: render_all.sh <aspek> <bahasa> <skala> <N>
#   tools/promo/render_all.sh 16x9 ms 1 3  ->  promo_out/video/v2_16x9_ms_noaudio.mp4 + garis masa
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
A="$1"; L="$2"; SC="${3:-1}"; N="${4:-3}"
OUT="promo_out/video/v2_${A}_${L}_noaudio.mp4"; mkdir -p promo_out/video
node tools/promo/render.mjs --page v2 --aspect "$A" --lang "$L" --still s01:0.1 --out promo_out/video/tmp_still --timeline "promo_out/timeline_${A}_${L}.json" >/dev/null
pids=()
for ((k=0; k<N; k++)); do
  node tools/promo/render.mjs --page v2 --aspect "$A" --lang "$L" --scale "$SC" --part "$k/$N" --video "${OUT%.mp4}.part$k.mp4" > "promo_out/video/log_${A}_${L}_$k.txt" 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
: > "${OUT%.mp4}.list"; for ((k=0; k<N; k++)); do echo "file '$(basename "${OUT%.mp4}").part$k.mp4'" >> "${OUT%.mp4}.list"; done
ffmpeg -y -loglevel error -f concat -safe 0 -i "${OUT%.mp4}.list" -c copy "$OUT"
echo "siap: $OUT"
