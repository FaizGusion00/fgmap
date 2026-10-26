#!/usr/bin/env python3
"""Pelayan statik untuk pembangunan yang menyokong HTTP Range (http.server Python tidak menyokongnya).

Menyajikan direktori output tools/tiles/build.sh supaya app boleh menguji muat turun, sambung semula dan
kemas kini peta offline tanpa hos sebenar:

    tools/tiles/serve.py tools/tiles/out 8099
    flutter run --dart-define=OFFLINE_MANIFEST_URL=http://10.0.2.2:8099/manifest.json   # emulator Android

Sengaja hanya mendengar pada 127.0.0.1 (emulator Android mencapainya melalui 10.0.2.2; simulator iOS melalui
localhost). Bukan untuk produksi.
"""
import http.server
import os
import re
import sys


class RangeHandler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        rng = self.headers.get("Range")
        path = self.translate_path(self.path)
        if not rng or not os.path.isfile(path):
            return super().send_head()
        m = re.fullmatch(r"bytes=(\d+)-(\d*)", rng.strip())
        size = os.path.getsize(path)
        if not m or int(m.group(1)) >= size:
            self.send_error(416, "Range Not Satisfiable")
            self.send_header("Content-Range", f"bytes */{size}")
            return None
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else size - 1
        end = min(end, size - 1)
        f = open(path, "rb")
        f.seek(start)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.end_headers()
        self._remaining = end - start + 1
        return f

    def copyfile(self, source, outputfile):
        remaining = getattr(self, "_remaining", None)
        if remaining is None:
            return super().copyfile(source, outputfile)
        while remaining > 0:
            chunk = source.read(min(65536, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            remaining -= len(chunk)
        self._remaining = None

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()


if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "."
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8099
    handler = lambda *a, **k: RangeHandler(*a, directory=directory, **k)  # noqa: E731
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"Menyajikan {os.path.abspath(directory)} pada http://127.0.0.1:{port}", flush=True)
    srv.serve_forever()
