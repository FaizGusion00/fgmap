#!/usr/bin/env python3
"""Kedudukan kamera CCTV lebuh raya daripada lapisan GIS LLM (ArcGIS FeatureServer HIGHWAY_CCTV_TRAFFICK).

Lapisan itu menyenaraikan ~490 kamera dengan koordinat, tetapi `CCTV_URL` di dalamnya menunjuk ke hos lama
(vigroot.llm.gov.my) yang tidak lagi menjawab. Imej langsung datang daripada laman LLM
(index.php/awam/get_data_ajax, URL bertandatangan). Fail ini hanya memetakan NAMA FAIL kamera -> koordinat,
supaya app boleh meletakkan kamera langsung di peta/laluan bila namanya sepadan.

Penggunaan: build_cctv_positions.py --out app/assets/cctv/llm_cctv_positions.json
"""
import argparse
import datetime
import json
import re
import urllib.parse
import urllib.request

URL = "https://gis02.llm.gov.my/llmsmpt/rest/services/GIS_LLM/TMC/FeatureServer/0/query"
UA = "fgmap-cctv/0.1 (+https://github.com/FaizGusion00/fgmap)"


def key(file_name):
    """Kunci padanan: nama fail tanpa `.web.jpg`, huruf kecil, hanya huruf/angka (sama seperti app)."""
    base = re.sub(r"\.web\.jpg$", "", file_name.strip().lower())
    return re.sub(r"[^a-z0-9]", "", base)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    q = urllib.parse.urlencode({
        "where": "1=1", "outFields": "Camera,CCTV_URL,X,Y,Highway", "returnGeometry": "false", "f": "json",
    })
    req = urllib.request.Request(f"{URL}?{q}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode("utf-8-sig"))
    cams = {}
    for f in data.get("features", []):
        a = f.get("attributes", {})
        url, lat, lng = a.get("CCTV_URL") or "", a.get("Y"), a.get("X")
        if not url or not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
            continue
        if not (0.8 <= lat <= 7.5 and 99 <= lng <= 120):
            continue
        k = key(url.rsplit("/", 1)[-1])
        if k:
            cams[k] = [round(lat, 5), round(lng, 5)]
    doc = {
        "source": "Lembaga Lebuhraya Malaysia, lapisan GIS HIGHWAY_CCTV_TRAFFICK (gis02.llm.gov.my)",
        "fetchedOn": datetime.date.today().isoformat(),
        "cameras": dict(sorted(cams.items())),
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    print("kamera berkoordinat:", len(cams))


if __name__ == "__main__":
    main()
