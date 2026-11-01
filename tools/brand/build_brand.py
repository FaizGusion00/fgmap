"""Jana semua PNG jenama FGMaps daripada sumber SVG dalam app/assets/branding/.

Alat percuma setempat sahaja: Google Chrome tanpa kepala (render SVG/HTML) + Pillow (skala turun).
Tiada muat naik rangkaian.

    python3 tools/brand/build_brand.py
    cd app && dart run flutter_launcher_icons   # ikon pelancar Android + iOS daripada PNG induk

Output:
  app/assets/branding/fgmap-app-icon.png         ikon penuh 1024 (logo dalam app + induk pelancar)
  app/assets/branding/launcher/*.png             induk adaptif / satu warna / iOS gelap & berwarna
  docs/store/assets{,/upload}/icon-512.png       ikon Google Play
  docs/store/assets{,/upload}/feature-graphic-1024x500.png
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRAND = os.path.join(ROOT, "app", "assets", "branding")
LAUNCHER = os.path.join(BRAND, "launcher")
STORE = os.path.join(ROOT, "docs", "store", "assets")
CHROME = os.environ.get(
    "CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

# Supersampel: render 2x kemudian skala turun LANCZOS untuk tepi yang licin.
SS = 2


def _shot(url, w, h):
    with tempfile.TemporaryDirectory() as d:
        png = os.path.join(d, "shot.png")
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             f"--force-device-scale-factor={SS}", "--default-background-color=00000000",
             "--allow-file-access-from-files", f"--window-size={w},{h}",
             f"--screenshot={png}", url],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        im = Image.open(png).convert("RGBA")
        im.load()
    return im.resize((w, h), Image.LANCZOS)


def render_svg(svg_text, size):
    """Render teks SVG pada saiz segi empat [size] (latar lut sinar)."""
    with tempfile.TemporaryDirectory() as d:
        svg = os.path.join(d, "in.svg")
        html = os.path.join(d, "in.html")
        with open(svg, "w") as f:
            f.write(svg_text)
        with open(html, "w") as f:
            f.write(
                "<!doctype html><html><head><style>html,body{margin:0;padding:0;"
                "background:transparent;overflow:hidden}img{display:block;"
                f"width:{size}px;height:{size}px}}</style></head><body>"
                f'<img src="file://{svg}"></body></html>')
        return _shot("file://" + html, size, size)


def read(name):
    with open(os.path.join(BRAND, name)) as f:
        return f.read()


def save(im, path, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    im.save(path, optimize=True)
    print("  ", os.path.relpath(path, ROOT))


def main():
    if not os.path.exists(CHROME):
        sys.exit(f"Chrome tidak dijumpai: {CHROME} (tetapkan CHROME=...)")

    icon = render_svg(read("fgmap-app-icon.svg"), 1024)
    save(icon, os.path.join(BRAND, "fgmap-app-icon.png"), opaque=True)

    save(render_svg(read("fgmap-adaptive-foreground.svg"), 1024),
         os.path.join(LAUNCHER, "adaptive-foreground.png"))
    save(render_svg(read("fgmap-adaptive-background.svg"), 1024),
         os.path.join(LAUNCHER, "adaptive-background.png"), opaque=True)
    mono = read("fgmap-monochrome.svg")
    save(render_svg(mono, 1024), os.path.join(LAUNCHER, "monochrome.png"))
    # iOS 18: ikon gelap = tanda atas lut sinar; ikon berwarna = tanda satu warna pada skala jubin.
    save(render_svg(read("fgmap-mark.svg"), 1024), os.path.join(LAUNCHER, "ios-dark.png"))
    save(render_svg(mono.replace("scale(.6)", "scale(.84)"), 1024),
         os.path.join(LAUNCHER, "ios-tinted.png"))

    store_icon = icon.resize((512, 512), Image.LANCZOS)
    feature = _shot("file://" + os.path.join(ROOT, "tools", "brand", "feature_graphic.html"),
                    1024, 500)
    for d in (STORE, os.path.join(STORE, "upload")):
        save(store_icon, os.path.join(d, "icon-512.png"), opaque=True)
        save(feature, os.path.join(d, "feature-graphic-1024x500.png"), opaque=True)


if __name__ == "__main__":
    main()
