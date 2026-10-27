"""Kadar tol lebuh raya HARGA TETAP daripada halaman tambang rasmi pengendali (kelas 1, kereta).

Setiap sumber ialah halaman awam pengendali yang menyiarkan jadual dalam teks HTML. Penghurai mesti GAGAL
dengan jelas (ParseError) jika bentuk halaman berubah; plaza berkenaan kemudian keluar sebagai "tidak
diketahui" dalam app, bukan angka lapuk. Tiada angka daripada tapak pihak ketiga.

Setiap sumber menyenaraikan plaza dengan kata kunci nama OSM (semua kata mesti ada dalam nama nod) supaya
koordinat diambil daripada OpenStreetMap, bukan direka.
"""
import re
import urllib.request

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/124.0 Safari/537.36")


class ParseError(Exception):
    pass


def fetch_text(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html,*/*"})
    with urllib.request.urlopen(req, timeout=60) as r:
        html = r.read().decode("utf-8-sig", "replace")
    html = re.sub(r"<(script|style|nav|footer|header)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    html = re.sub(r"<[^>]+>", " ", html)
    html = html.replace("&nbsp;", " ").replace("&#8211;", "-").replace("&amp;", "&")
    return re.sub(r"\s+", " ", html)


RM = r"RM\s?(\d+(?:\.\d{1,2})?)"


def _first_rates(text, anchor_pattern, count):
    """`count` angka RM pertama selepas `anchor_pattern` (cth. baris Kelas 1)."""
    m = re.search(anchor_pattern, text, flags=re.I)
    if not m:
        raise ParseError(f"tiada baris '{anchor_pattern}'")
    rates = [float(x) for x in re.findall(RM, text[m.end(): m.end() + 400])[:count]]
    if len(rates) != count or any(r <= 0 or r > 50 for r in rates):
        raise ParseError(f"angka kelas 1 tidak sah: {rates}")
    return rates


def parse_ldp(text):
    # "... four (4) LDP toll plazas located at Penchala, Petaling Jaya, Puchong Barat and Puchong Selatan."
    if not re.search(r"Penchala,\s*Petaling Jaya,\s*Puchong Barat and Puchong Selatan", text):
        raise ParseError("senarai plaza LDP berubah")
    (rate,) = _first_rates(text, r"Class 1 A vehicle with 2 axles and 3/4 wheels, excluding a taxi\.", 1)
    return {"Penchala": rate, "Petaling Jaya": rate, "Puchong Barat": rate, "Puchong Selatan": rate}


def parse_sprint(text):
    if not re.search(r"Toll Plaza Damansara Toll Plaza Pantai Toll Plaza Bukit Kiara", text):
        raise ParseError("tajuk plaza SPRINT berubah")
    d, p, k = _first_rates(text, r"Class 1 A vehicle with 2 axles and 3/4 wheels, excluding a taxi\.", 3)
    return {"Damansara": d, "Pantai": p, "Bukit Kiara": k}


def parse_llb(text):
    if not re.search(r"Daripada Perai Bagan Ajam Sungai Nyior", text):
        raise ParseError("tajuk plaza LLB berubah")
    p, b, s = _first_rates(text, r"Kelas 1 \(Kenderaan dengan 2 gandar dan 3 atau 4 roda kecuali teksi\)", 3)
    return {"Perai": p, "Bagan Ajam": b, "Sungai Nyior": s}


def parse_kesas(text):
    if not re.search(r"four toll plazas", text):
        raise ParseError("bilangan plaza KESAS berubah")
    (rate,) = _first_rates(text, r"RATE \(RM\) VEHICLE CLASSES", 1)
    return {"Awan Besar": rate, "Sunway": rate, "Kemuning": rate}


# kunci: (id, nama, URL, penghurai); plaza: label -> kata kunci nama OSM (huruf kecil, semua mesti ada)
SOURCES = [
    {
        "id": "ldp", "name": "LDP (Lebuhraya Damansara-Puchong)",
        "url": "https://litrak.com.my/our-highways/litrak/toll-fares/", "parse": parse_ldp,
        "osm": {"Penchala": ["penchala"], "Petaling Jaya": ["petaling", "jaya"],
                "Puchong Barat": ["puchong", "barat"], "Puchong Selatan": ["puchong", "selatan"]},
        "operator": ["litrak", "lingkaran trans kota"],
    },
    {
        "id": "sprint", "name": "SPRINT",
        "url": "https://litrak.com.my/our-highways/sprint/toll-fares/", "parse": parse_sprint,
        "osm": {"Damansara": ["damansara"], "Pantai": ["pantai"], "Bukit Kiara": ["bukit", "kiara"]},
        "operator": ["sistem penyuraian trafik kl barat", "sprint"],
    },
    {
        "id": "llb", "name": "Lebuhraya Lingkaran Luar Butterworth (LLB)",
        "url": "https://llb.com.my/tambang-tol/", "parse": parse_llb,
        "osm": {"Perai": ["perai"], "Bagan Ajam": ["bagan", "ajam"], "Sungai Nyior": ["sungai", "nyior"]},
        "operator": ["lingkaran luar butterworth", "llb"],
    },
    {
        "id": "kesas", "name": "KESAS (Lebuhraya Shah Alam)",
        "url": "https://kesas.com.my/toll-lane/", "parse": parse_kesas,
        "osm": {"Awan Besar": ["awan", "besar"], "Sunway": ["sunway"], "Kemuning": ["kemuning"]},
        "operator": ["kesas"],
    },
]
