# ADR 0019: FG AI: pengetahuan web percuma (berita, ensiklopedia, data rasmi)

Status: diterima (2026-11-01). Kod: `features/local_assistant/data/web_knowledge.dart`, `data/web_settings.dart`,
`domain/intent_router.dart` (`strongWebIntent`, `freshFactIntent`), `domain/assistant_tools.dart` (alat `web_search`),
`presentation/assistant_controller.dart` (`_web`, `_askModel(web:)`), `presentation/widgets/sources_section.dart`.
Menyambung ADR 0015 (penghala sebelum model) dan 0017.

## Konteks

Pemilik mahu FG AI "boleh browse internet bila perlu atau bila disuruh" dan memberi data terkini yang betul, dengan
cadangan DuckDuckGo. Model atas peranti (Qwen3 0.6B hingga Gemma 4 E4B) tidak tahu apa-apa selepas tarikh latihannya.
Probe pada 2026-11-01 mendapati:

- Titik akhir `html`/`lite` DuckDuckGo sentiasa memulangkan HTTP 202 "anomaly" (dinding bot) kepada klien app.
- DDG Instant Answer berfungsi, tetapi hanya untuk entiti (orang, tempat, organisasi). Ia tidak memulangkan berita
  atau carian bebas.
- Google News RSS (`news.google.com/rss/search`, `gl=MY`) memulangkan tajuk terkini dengan sumber dan tarikh.
- API BNM (`api.bnm.gov.my/public/exchange-rate/{CUR}`) memerlukan pengepala
  `Accept: application/vnd.BNM.API.v1+json`.

## Keputusan

1. **Campuran sumber percuma, tanpa kunci API.**
   - DDG Instant Answer, Wikipedia (`rest.php/v1/search/page` + ringkasan) dan Google News RSS (bahasa ms/en, Malaysia).
     Ketiga-tiganya dipanggil serentak, dengan bajet 6 s setiap satu.
   - Fakta rasmi pergi terus ke sumbernya: kadar tukaran ke BNM, harga minyak ke data.gov.my (penyedia `fuel` sedia ada).
   - Pautan yang ditampal pengguna dibaca dengan `readUrl`: HTTPS sahaja, hos peribadi/LAN ditolak (`isSafePublicUrl`),
     had 2 MB dan 8 s, dan teks utama diekstrak dengan `package:html`.
2. **Bila ke internet: automatik + atas permintaan.**
   - *Eksplisit:* "cari online / search the web / google X", berita, atau pautan. Penghala memancarkan
     `WebSearchIntent(explicit: true)`.
   - *Automatik:* soalan fakta segar ("hari ini", "terkini", "harga …", "kadar tukaran", "siapa … sekarang").
     Hanya berlaku bila suis Tetapan "cari di internet secara automatik" hidup (lalai: hidup).
   - Bila suis dimatikan, jawapan model ditamatkan dengan butang "Cari di internet: …".
   - Model juga boleh memanggil alat `web_search` sendiri.
3. **Jawapan berasaskan sumber.**
   - Jika model sedia, potongan web (≤ 1,200 aksara) diberi sebagai konteks. Arahan: jawab daripada sumber, petik [n],
     dan katakan bila tidak pasti.
   - Tanpa model, jawapan ialah templat: tajuk berita bertarikh, ringkasan ensiklopedia, atau angka rasmi.
   - Sumber sentiasa dilampirkan sebagai `AnswerSourceKind.web`. Fasa UI `browsing` ("Mencari di internet…")
     ditunjukkan semasa menunggu.
4. **Privasi dan konfigurasi.**
   - Hanya teks soalan dihantar ke sumber; lokasi tidak dihantar.
   - Dokumen privasi (ms/en) dan `legal_test` menyenaraikan DuckDuckGo, Google News, BNM dan Wikipedia.
   - Titik akhir didaftarkan dalam `AppConfig` dan disemak oleh `insecureEndpoints()`.

## Akibat

- Liputan web ialah berita, ensiklopedia dan data rasmi, bukan carian laman sembarangan. DDG tidak membenarkannya.
  Pautan yang ditampal tetap boleh dibaca.
- Google News RSS awam tetapi tidak rasmi; formatnya boleh berubah. Jika ia gagal, jawapan jatuh kepada Wikipedia
  dan DDG, dan `WebSearchResult.failed` memberi mesej jujur.
- Hasil berita disusun ikut tarikh daripada hasil yang dipulangkan. "Terkini" bermaksud terkini dalam hasil RSS itu,
  dan mungkin tajuk beberapa hari lepas.
- Kualiti jawapan model asas (0.6B/0.8B) tetap terhad walaupun dengan sumber; Gemma 4 E2B/E4B jauh lebih baik.
- Disahkan pada emulator (build release, 2026-11-01): "berita terkini banjir" memberi 5 tajuk bertarikh dengan [n];
  "kadar tukaran usd hari ini" memberi BNM beli/jual; "harga minyak hari ini" memberi RON95/RON97/Diesel daripada
  data.gov.my.
