# ADR 0016: FG AI: ayat bersahaja, ralat jujur dan carian tempat yang tahan

Status: diterima (2026-11-01). Kod: `features/local_assistant/` (`domain/intent_router.dart`,
`data/tool_executor.dart`, `domain/reply_cleaner.dart`, `presentation/assistant_controller.dart`,
`presentation/ai_reply_builder.dart`), `features/search/` (`domain/offline_place.dart`,
`domain/place_query_expand.dart`, `data/offline_geocoder.dart`), `core/network/connectivity_probe.dart`.

## Konteks

Ujian pemilik pada telefon sebenar (versi `main`, bahasa peranti BM, mesej dalam English) dalam dua keadaan.

| Mesej | Offline | Online |
|---|---|---|
| "Can you tell me where are my current location?" / "Please tell me my current location" | gema: "Hello! I'm FG AI. Where are you heading today...? Can you tell me where are my current location?" | sama |
| "Im heading to masjid attaufiqiah can you tell me how?" / "...how do i do that?" | "Itu perlukan internet. Anda sedang luar talian..." | "Laluan tidak dapat dikira sekarang. Semak sambungan..." |

Balasan bertemplat juga dalam BM walaupun pengguna menaip English.

Punca (dibaca daripada kod, disahkan dengan ujian):

1. **Penghala terlalu ketat.** `_isCurrentLocationQuery` ditambat `^...$`, jadi pembungkus sopan ("can you tell me",
   "please tell me", "where are my...") tidak padan. `parseIntent` pulang null dan model 0.6B menjawab dengan menggema
   salam + ayat pengguna.
2. **Destinasi bercampur sampah.** Corak "heading to" menangkap SEMUA teks selepasnya, dan `_cleanDestination` tidak
   membuang ekor soalan. Geokoder menerima "masjid attaufiqiah can you tell me how". Padanan FTS luar talian memerlukan
   semua token (`AND`), maka tidak mungkin padan.
3. **Ejaan dirapatkan.** "attaufiqiah" bukan token "at" + "taufiqiah" dalam indeks (tokenizer `simple` memisahkan
   "At-Taufiqiah"), dan tiada alias kata sandang Arab.
4. **Ralat dipetakan mengikut jenis, bukan keadaan sebenar.** Tiada semakan sambungan. HTTP 429/5xx daripada Photon
   dipaparkan sebagai "anda luar talian" walaupun online; semua `RouteFailed` (noRoute, rateLimited, offlineRequired,
   network...) menjadi satu teks "semak sambungan".
5. **Bahasa jawapan.** Perkataan "masjid"/"ke" dalam nama tempat menjadikan ayat English dikira Melayu.
6. **Tiada pengawal gema** pada keluaran model.

## Keputusan

1. **Penghala memahami ayat bersahaja.** `stripPoliteness` membuang pembungkus ("can you (please) tell me", "please",
   "tolong", "i want to", "im heading to" -> "go to") sebelum padanan; `_isCurrentLocationQuery` ada bentuk longgar
   ("where are my current location", "tell me my location", "saya kat mana"); ekor soalan dipotong daripada destinasi
   ("... can you tell me how", "... macam mana"). Intent baharu `RouteFollowUpIntent`: "how do i do that / get there",
   "tell me how", "bawa saya ke sana" memakai laluan sedia ada (balas: sudah ada pada peta) atau destinasi terakhir, atau
   bertanya "ke mana?" menggunakan templat (bukan model).
2. **Carian tempat tahan.**
   - `placeQueryVariants` mencuba ejaan alternatif secara berturutan ("attaufiqiah" -> "at taufiqiah" -> "at-taufiqiah").
   - `ftsMatchQuery` menambah `(at* AND taufiqiah*)` untuk token berawalan at/al/ar/as/an/ad/az/asy/ash; jika semua token
     tidak padan, `OfflinePlacesDb.search` mencuba padanan longgar (OR) dan membiarkan `rankOfflinePlaces` menyusun.
   - Hasil disusun `PlaceRanker` (nama + jarak) dan bukan sekadar yang pertama daripada pelayan.
3. **Sambungan sebenar dan ralat jujur.**
   - `onlineProbeProvider` (connectivity_plus) membezakan tiada pautan (mod pesawat) daripada pelayan sibuk/lambat.
   - Tiada pautan: `OfflineAwareGeocoder` melangkau carian dalam talian terus (tiada tunggu 6 s) dan guna indeks pek.
   - Kod ralat baharu: `offline`, `offline_not_found`, `offline_pack_needed`, `busy` (429), `service_down` (5xx),
     `slow` (tamat masa/sambungan gagal semasa ADA pautan), `no_drivable_route`, `search_failed`, `route_failed`.
     Setiap satu ada mesej tersendiri (BM + English) yang menyebut tempat dan tindakan seterusnya.
   - Ralat sementara diulang SEKALI sebelum mengalah.
   - `RouteFailed` dipetakan mengikut `RoutingFailureKind`.
   - Pemasa tunggu laluan 15 s ialah `Timer` yang dibatalkan (bukan `Future.delayed`).
4. **Bahasa jawapan ikut bahasa mesej.** `replyIsMalay` menskor kata fungsi Melayu vs English (nama tempat dikecualikan);
   seri -> bahasa UI.
5. **Pengawal gema.** `isEchoReply` menolak jawapan model yang mengandungi ayat pengguna utuh, hampir sama dengannya
   (Jaccard >= 0.8), atau bermula dengan salam/pengenalan diri yang tidak diminta. Diganti `aiNotUnderstood` (panduan
   ringkas apa yang boleh ditanya).

## Akibat

- "Tell me my current location" dan "im heading to <tempat> can you tell me how?" dijawab oleh kod: pantas, betul, dalam
  bahasa pengguna, online dan offline.
- Mesej ralat kini menunjukkan sebab sebenar. Luar talian TANPA pek peta tetap tidak boleh mencari nama tempat (indeks
  tempat ada dalam pek); mesej menyatakannya dan menawarkan muat turun pek.
- Kekal terhad: soalan umum masih bergantung pada model 0.6B (ADR 0015). Corak penghala perlu terus dikembangkan
  mengikut cara pengguna sebenar bercakap; `intent_router_test.dart` dan `ai_chat_phone_regression_test.dart` ialah
  senarai rujukan.
- `connectivity_plus` hanya mengesan pautan, bukan internet berfungsi: Wi-Fi tanpa internet dilaporkan `slow`/`busy`
  mengikut ralat sebenar, bukan `offline`.

## Ujian

- `test/features/local_assistant/intent_router_test.dart`: ayat daripada tangkapan skrin + variasi.
- `test/features/local_assistant/tool_executor_test.dart`: 429/503/tamat masa/luar talian, ulangan, varian ejaan,
  pemetaan `RouteFailed`.
- `test/features/search/offline_search_test.dart`: `ftsMatchQuery` (kata sandang Arab, longgar) dan
  `placeQueryVariants`.
- `test/features/local_assistant/ai_chat_phone_regression_test.dart`: dua ayat tangkapan skrin dari hujung ke hujung
  (online, luar talian, 429, sambungan lemah, gema model).
- Pengesahan akhir mesti pada telefon (sandbox tiada peranti, model 0.6B atau GPS sebenar). Senarai semak manual,
  dalam talian dan dalam mod pesawat, dengan dan tanpa pek peta offline:
  1. "Can you tell me where are my current location?" -> koordinat GPS (nama jalan jika online), tiada ucapan salam.
  2. "Please tell me my current location" -> sama.
  3. "Im heading to masjid attaufiqiah can you tell me how?" -> laluan ke Masjid At-Taufiqiah (online); mod pesawat +
     pek terpasang -> laluan offline; mod pesawat tanpa pek -> mesej menyebut pek peta.
  4. "how do i do that?" selepas langkah 3 -> "laluan sudah ada pada peta"; tanpa laluan -> "anda nak ke mana?".
  5. "navigate to klcc" semasa Wi-Fi tanpa internet -> mesej "lambat/tidak stabil", bukan "luar talian".
