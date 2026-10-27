#!/usr/bin/env python3
"""Menjana HTML statik (untuk GitHub Pages / pautan Play Store dan App Store) daripada
app/assets/legal/*.md. Sumber tunggal: dokumen dalam app dan di web sentiasa sama.

Penggunaan:
  LEGAL_EMAIL=... LEGAL_ADDRESS="..." LEGAL_REG_NO=... python3 tools/legal/render_html.py [direktori_output]

Tanpa pemboleh ubah, pemegang tempat [DIISI] kekal (jangan terbitkan keluaran sebegitu).
"""
import html
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "app", "assets", "legal")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "legal", "site")

VALUES = {
    "entity": os.environ.get("LEGAL_ENTITY", "FG Universal Empire Company"),
    "developer": os.environ.get("LEGAL_DEVELOPER", "Faiz Nasir"),
    "regNo": os.environ.get("LEGAL_REG_NO", "[DIISI]"),
    "address": os.environ.get("LEGAL_ADDRESS", "[DIISI]"),
    "email": os.environ.get("LEGAL_EMAIL", "[DIISI]"),
    "effective": "2026-10-26",
    "version": "1.0",
}


def fill(text: str) -> str:
    return re.sub(r"\{\{(\w+)\}\}", lambda m: VALUES.get(m.group(1), m.group(0)), text)


def inline(text: str) -> str:
    escaped = html.escape(text)
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)


def render(markdown: str, lang: str) -> str:
    body, paragraph, in_list = [], [], False

    def close_list():
        nonlocal in_list
        if in_list:
            body.append("</ul>")
            in_list = False

    def flush():
        if paragraph:
            body.append("<p>" + "<br>".join(inline(p) for p in paragraph) + "</p>")
            paragraph.clear()

    title = "FGMaps"
    for line in markdown.split("\n"):
        line = line.rstrip()
        if not line:
            flush()
            close_list()
        elif line.startswith("# "):
            flush(); close_list()
            title = line[2:]
            body.append(f"<h1>{inline(title)}</h1>")
        elif line.startswith("## "):
            flush(); close_list()
            body.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("### "):
            flush(); close_list()
            body.append(f"<h3>{inline(line[4:])}</h3>")
        elif line.startswith("- "):
            flush()
            if not in_list:
                body.append("<ul>")
                in_list = True
            body.append(f"<li>{inline(line[2:])}</li>")
        else:
            close_list()
            paragraph.append(line)
    flush()
    close_list()
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>
body{{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:0 auto;padding:1.5rem;color:#1b1b1f;background:#fff}}
@media (prefers-color-scheme:dark){{body{{color:#e6e6ea;background:#121214}}}}
h1{{font-size:1.6rem}}h2{{font-size:1.2rem;margin-top:2rem}}
</style>
</head>
<body>
{chr(10).join(body)}
</body>
</html>
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".md"):
            continue
        lang = name.split(".")[1]
        with open(os.path.join(SRC, name), encoding="utf-8") as f:
            text = fill(f.read())
        out = os.path.join(OUT, name[:-3] + ".html")
        with open(out, "w", encoding="utf-8") as f:
            f.write(render(text, lang))
        print("ditulis", out)
    left = [k for k, v in VALUES.items() if v == "[DIISI]"]
    if left:
        print("AMARAN: masih pemegang tempat:", ", ".join(left), file=sys.stderr)


if __name__ == "__main__":
    main()
