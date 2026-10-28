#!/usr/bin/env bash
# Gabung video v2 (tanpa audio) + campuran audio (mix.py) -> MP4 akhir H.264/AAC, ~ -14 LUFS.
#   tools/promo/mux_v2.sh promo_out/video/v2_16x9_ms_noaudio.mp4 promo_out/audio/mix_16x9_ms.wav promo_out/final/fgmaps_promo_16x9_ms.mp4
set -euo pipefail
IN="$1"; AUD="$2"; OUT="$3"
mkdir -p "$(dirname "$OUT")"
ffmpeg -y -loglevel error -i "$IN" -i "$AUD" \
  -filter_complex "[1:a]loudnorm=I=-14:TP=-1.5:LRA=9[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 44100 -shortest -movflags +faststart "$OUT"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,duration -of default=nw=1 "$OUT"
echo "siap: $OUT"
