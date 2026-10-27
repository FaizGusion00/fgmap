#!/usr/bin/env bash
# Gabung video tanpa audio + muzik -> MP4 akhir (H.264/AAC), loudness ~ -14 LUFS, puncak benar <= -1.5 dBTP.
#   tools/promo/mux.sh 9x16 ms     -> promo_out/final/fgmaps_promo_9x16_30s_ms.mp4 (+ poster JPG)
set -euo pipefail
ASPECT="$1"; LANG_="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
case "$ASPECT" in 9x16) SECS=30;; 16x9) SECS=60;; *) echo "aspek tidak sah"; exit 2;; esac
IN="$ROOT/promo_out/video/${ASPECT}_${LANG_}_noaudio.mp4"
AUD="$ROOT/promo_out/audio/music_${ASPECT}.wav"
OUT="$ROOT/promo_out/final/fgmaps_promo_${ASPECT}_${SECS}s_${LANG_}.mp4"
mkdir -p "$ROOT/promo_out/final"
ffmpeg -y -loglevel error -i "$IN" -i "$AUD" \
  -filter_complex "[1:a]acompressor=threshold=-18dB:ratio=3:attack=8:release=120,loudnorm=I=-14:TP=-1.5:LRA=9[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 44100 -shortest -movflags +faststart "$OUT"
# poster: bingkai babak navigasi (kira-kira satu pertiga video)
ffmpeg -y -loglevel error -ss "$(python3 -c "print($SECS*0.28)")" -i "$OUT" -frames:v 1 -q:v 2 "${OUT%.mp4}_poster.jpg"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,duration,bit_rate -of default=nw=1 "$OUT"
echo "siap: $OUT"
