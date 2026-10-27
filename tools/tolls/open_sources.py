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


def parse_mex(text):
    if not re.search(r"SALAK SELATAN TOLL PLAZA SERI KEMBANGAN TOLL PLAZA PUTRAJAYA UTAMA TOLL PLAZA", text):
        raise ParseError("tajuk plaza MEX berubah")
    rates = []
    for m in re.finditer(r"Class 1 Vehicles with 2 axles and 3 or 4 wheels excluding taxies " + RM, text):
        rates.append(float(m.group(1)))
    if len(rates) != 3 or any(r <= 0 or r > 50 for r in rates):
        raise ParseError(f"kadar MEX tidak sah: {rates}")
    return {"Salak Selatan": rates[0], "Seri Kembangan": rates[1], "Putrajaya": rates[2]}


def _prolintas_class1(text, plaza_label=None):
    """Kadar kelas 1 jadual Prolintas ("1 Cars with 2 Axles 1.75"); jika `plaza_label`, jadual selepas tajuk itu."""
    start = 0
    if plaza_label:
        m = re.search(re.escape(plaza_label) + r" Toll Plaza", text)
        if not m:
            raise ParseError(f"tiada tajuk plaza '{plaza_label}'")
        start = m.end()
    m = re.search(r"\b1 Cars? with 2 Axles (\d+\.\d{2})\b", text[start:])
    if not m:
        raise ParseError("tiada baris kelas 1 Prolintas")
    rate = float(m.group(1))
    if rate <= 0 or rate > 50:
        raise ParseError(f"kadar tidak sah: {rate}")
    return rate


def parse_prolintas_flat(*labels):
    """Satu jadual kadar untuk semua plaza lebuh raya (halaman tidak membezakan plaza)."""
    def parse(text):
        rate = _prolintas_class1(text)
        return {label: rate for label in labels}
    return parse


def parse_lksa(text):
    return {"Seri Muda": _prolintas_class1(text, "Seri Muda"), "Alam Impian": _prolintas_class1(text, "Alam Impian")}


# `osm`: label plaza -> awalan nama nod OSM (huruf kecil). Hanya awalan yang disahkan sepadan dengan plaza
# berkenaan (daripada senarai nod OSM dan halaman pengendali); plaza lain pada lebuh raya yang sama TIDAK
# dianggap sama kadar kecuali halaman pengendali menyatakannya. Selebihnya kekal "tidak diketahui".
SOURCES = [
    {
        "id": "ldp", "name": "LDP (Lebuhraya Damansara-Puchong)",
        "url": "https://litrak.com.my/our-highways/litrak/toll-fares/", "parse": parse_ldp,
        "osm": {"Penchala": ["plaza tol penchala"], "Petaling Jaya": ["plaza tol petaling jaya"],
                "Puchong Barat": ["plaza tol puchong barat"], "Puchong Selatan": ["plaza tol puchong selatan"]},
    },
    {
        "id": "sprint", "name": "SPRINT",
        "url": "https://litrak.com.my/our-highways/sprint/toll-fares/", "parse": parse_sprint,
        "osm": {"Damansara": ["plaza tol damansara ("], "Pantai": ["plaza tol pantai ("],
                "Bukit Kiara": ["plaza tol bukit kiara"]},
    },
    {
        "id": "llb", "name": "Lebuhraya Lingkaran Luar Butterworth (LLB)",
        "url": "https://llb.com.my/tambang-tol/", "parse": parse_llb,
        "osm": {"Perai": ["perai toll plaza"], "Bagan Ajam": ["plaza tol bagan ajam"],
                "Sungai Nyior": ["plaza tol sungai nyior"]},
    },
    {
        "id": "kesas", "name": "KESAS (Lebuhraya Shah Alam)",
        "url": "https://kesas.com.my/toll-lane/", "parse": parse_kesas,
        "osm": {"Awan Besar": ["plaza tol awan besar"], "Sunway": ["plaza tol sunway"],
                "Kemuning": ["plaza tol kemuning"]},
    },
    {
        "id": "mex", "name": "MEX (Lebuhraya Maju)",
        "url": "https://www.mex.com.my/features-and-facilities/toll-operations/", "parse": parse_mex,
        # "Putrajaya": dua plaza OSM bernama sama (ELITE dan MEX); koordinat MEX dalam aliases.json.
        "osm": {"Salak Selatan": ["plaza tol salak selatan"], "Seri Kembangan": ["plaza tol mex seri kembangan"],
                "Putrajaya": []},
    },
    {
        "id": "gce", "name": "GCE (Guthrie Corridor Expressway)",
        "url": "https://www.prolintas.com.my/gce/",
        "parse": parse_prolintas_flat("Elmina", "Lagong", "Bukit Jelutong"),
        "osm": {"Elmina": ["plaza tol elmina"], "Lagong": ["plaza tol lagong"],
                "Bukit Jelutong": ["plaza tol bukit jelutong", "lorong tol berlapis gce bukit jelutong"]},
    },
    {
        "id": "lksa", "name": "LKSA (Lebuhraya Kemuning-Shah Alam)",
        "url": "https://www.prolintas.com.my/lksa/", "parse": parse_lksa,
        "osm": {"Seri Muda": ["plaza tol seri muda"], "Alam Impian": ["plaza tol lksa alam impian"]},
    },
    {
        "id": "akleh", "name": "AKLEH (Lebuhraya Ampang-Kuala Lumpur Layang)",
        "url": "https://www.prolintas.com.my/akleh/", "parse": parse_prolintas_flat("Ampang"),
        "osm": {"Ampang": ["plaza tol ampang ("]},
    },
    {
        "id": "silk", "name": "SILK (Lebuhraya Kajang Dispersal Link)",
        "url": "https://www.prolintas.com.my/kajang-silk/", "parse": parse_prolintas_flat("Sungai Balak"),
        "osm": {"Sungai Balak": ["plaza tol sungai balak"]},
    },
    {
        "id": "dash", "name": "DASH (Lebuhraya Damansara-Shah Alam Layang)",
        "url": "https://www.prolintas.com.my/dash/", "parse": parse_prolintas_flat("Kota Damansara"),
        "osm": {"Kota Damansara": ["plaza tol kota damansara (dash)"]},
    },
]
