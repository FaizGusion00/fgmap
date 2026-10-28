"""Pisahkan PNG HUD (banner, gelembung laju, panel bawah) kepada tiga fail berasingan.

PNG sumber dijana oleh app/test/promo/promo_assets_test.dart (widget sebenar app). Setiap PNG
mengandungi tiga komponen yang dipisahkan oleh baris lut sinar; skrip ini memotongnya supaya
enjin babak boleh meletakkan banner di atas dan panel di bawah seperti dalam app.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

src = sys.argv[1]
n = 0
for f in sorted(glob.glob(os.path.join(src, "hud_*.png"))):
    im = Image.open(f).convert("RGBA")
    a = np.asarray(im)[:, :, 3] > 90
    rows = a.any(axis=1)
    runs, start = [], None
    for y, on in enumerate(rows):
        if on and start is None:
            start = y
        if not on and start is not None:
            runs.append((start, y))
            start = None
    if start is not None:
        runs.append((start, len(rows)))
    if len(runs) != 3:
        raise SystemExit(f"{f}: dijangka 3 komponen, dapat {len(runs)}: {runs}")
    base = os.path.basename(f)[4:-4]
    for name, (y0, y1) in zip(("top", "bub", "bot"), runs):
        pad = 14
        im.crop((0, max(0, y0 - pad), im.width, min(im.height, y1 + pad))).save(os.path.join(src, f"{name}_{base}.png"))
    n += 1
print("dipisah:", n)
