#!/usr/bin/env bash
# Lembaran kenalan bingkai (1 bingkai setiap N saat) untuk semakan visual video.
#   tools/promo/contact.sh promo_out/final/xxx.mp4 promo_out/contact_xxx.png 2 8
FILE="$1"; OUT="$2"; EVERY="${3:-2}"; COLS="${4:-8}"
ffmpeg -y -loglevel error -i "$FILE" -vf "fps=1/${EVERY},scale=240:-1,tile=${COLS}x6" -frames:v 1 "$OUT"
