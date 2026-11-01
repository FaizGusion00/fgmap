# ADR 0017: FG AI: faham arahan berasaskan kod (slang, ejaan, konteks, kawalan app)

Status: diterima (2026-11-01). Kod: `features/local_assistant/domain/` (`intent_router.dart`, `nlu/intents.dart`,
`nlu/normalizer.dart`, `nlu/fuzzy.dart`), `data/trip_info.dart`, `presentation/assistant_controller.dart`,
`presentation/ai_reply_builder.dart`. Menyambung ADR 0015 (penghala sebelum model) dan 0016 (ayat bersahaja).

## Konteks

Selepas 0016 pemilik menegaskan: AI "kena pandai betul-betul faham walaupun model tak pandai". Model Qwen3 0.6B tidak
boleh dipercayai untuk memahami arahan peta, jadi KOD mesti memahami. Audit penghala (dibaca + regex diuji) menemui:

- Tiada toleransi slang/SMS/salah taip: "nk g klcc", "cmne nk gi klcc", "bawak saya ke klcc", "rute ke klcc", "xnak tol".
- Intent saling menutup: "is it going to rain in klcc" menjadi laluan ke "rain in klcc"; "bawa saya ke stesen minyak
  terdekat" menjadi laluan ke teks itu; "cari masjid negara" memulangkan masjid terdekat (bukan tempat bernama);
  "route to jalan kampung baru" memadam "jalan kampung" sebagai pilihan elak lebuh raya.
- Tiada konteks: "yang pertama", "the second one", "ok" (memulakan navigasi walaupun jawapan kepada soalan lain),
  "stop"/"tak jadi" (navigasi aktif tidak pernah dihentikan), "klcc" sahaja (terus ke model).
- Banyak keupayaan app tiada pintu suara: balik rumah/kerja, berapa jauh/lama/tol/kos minyak, tukar kenderaan, senyap, mod gelap.

## Keputusan

1. **Dua lapisan padanan.** (a) `canonicalizeSlang(normalizeCommand(teks))`: kamus slang/SMS (data `const`, mudah
   dikembangkan), `x`/`g` satu huruf hanya slang pada kedudukan arahan. (b) Jika tiada padanan langsung, kata arahan
   yang salah taip dibetulkan (`fuzzyCorrect`, Damerau-Levenshtein, huruf pertama sama, hanya terhadap perbendaharaan
   arahan) dan ayat diuji semula. Lapisan (b) berjalan SELEPAS (a) gagal sepenuhnya, jadi nama tempat yang betul tidak
   pernah diubah.
2. **Urutan/pertindihan dibetulkan.** Cuaca/solat/IPU diuji sebelum kata kerja laluan (kecuali kata kerja jelas
   "navigate/bawa saya"); destinasi yang hanya kategori ("stesen minyak terdekat", "nak ke tandas") menjadi
   `NearbyIntent(navigate: true)`; "cari <kategori> <nama>" menjadi carian nama; "jalan kampung/lama" selepas penanda
   destinasi dilindungi sebagai nama jalan.
3. **Konteks perbualan** (`ConversationContext`, dipegang `AssistantController`): `hasRoute`, `navActive`, `offeredStart`
   (balasan terakhir benar-benar ada butang mula), `resultCount` (senarai hasil terakhir), `pendingDestination`.
   - "ok/ya/boleh" bermakna MULA hanya bila `offeredStart`; selain itu pengesahan ringkas (templat).
   - "yang pertama/kedua/ketiga", "the second one", "yang terdekat", "satu lagi" memilih daripada hasil terakhir dan
     merancang laluan ke koordinatnya (`planRouteToPlace`, tanpa carian semula).
   - Selepas AI bertanya "nak ke mana?", jawapan pendek ialah destinasi.
   - "stop/berhenti/tamatkan navigasi" menghentikan navigasi aktif; "tak jadi" tanpa laluan = ack.
4. **Intent baharu, semuanya daripada data/penyedia setempat (tiada rangkaian, tiada model):** `GoSavedPlaceIntent`
   (Rumah/Kerja), `TripInfoIntent` (jarak/masa baki/ETA/tol/kos minyak/belok seterusnya/had laju; `data/trip_info.dart`),
   `ChangeVehicleIntent`, `VoiceIntent`, `ThemeIntent`, `StopNavigationIntent`, `AskSlotIntent`.
   Tidak pernah mereka nilai: tol motosikal ditulis "tiada dalam data" (bukan percuma), harga minyak tiada -> berterus
   terang, tol belum siap dikira -> "masih dikira".
5. **Nama tempat sahaja** ("klcc", "masjid negara") -> carian spekulatif. Hasilnya hanya dipercayai jika nama mengandungi
   semua perkataan (atau singkatan huruf pertama); jika tidak, dan model sedia, ia diserahkan kepada model. Teks dengan
   kata soal/fungsi, tanda soal, atau >4 perkataan tidak pernah dianggap tempat. Laluan daripada soalan ("how do i go to
   sleep faster") yang tempatnya tidak wujud juga diserahkan kepada model (`RouteIntent.soft`).
6. **Model hanya untuk pengetahuan am.** Gesaan sistem ditambah: jangan memberi salam/memperkenalkan diri melainkan
   pengguna memberi salam.

## Yang sengaja ditangguhkan

Buka lembaran kecemasan 999, kongsi ETA, simpan Rumah/Kerja, zum/recenter (perlu jambatan UI dan pengesahan; tindakan
menulis data tidak dilakukan tanpa pengesahan); laluan dengan asal bukan lokasi semasa ("dari Ipoh ke KLCC") dan "via X"
(enjin hanya menerima asal GPS); kamera laju sepanjang laluan (alat ada, intent belum).

## Akibat

- Ayat sebenar yang gagal sebelum ini kini difahami oleh kod, pantas, tanpa model dan offline.
- Penghala masih berasaskan corak: ayat baharu yang tidak dijangka tetap boleh terlepas. Pertahanan: lapisan salah taip,
  carian spekulatif, soalan "nak ke mana?", dan KORPUS `test/features/local_assistant/nlu_corpus_test.dart` (setiap ayat
  yang gagal di lapangan ditambah sebagai satu baris dan dibetulkan).
- Carian spekulatif membuat satu panggilan carian untuk teks pendek yang bukan tempat sebelum model menjawab.

## Ujian

- `nlu_corpus_test.dart` (korpus ~160 baris: slang, salah taip, pertindihan, konteks, soalan umum yang MESTI ke model).
- `nlu_normalizer_test.dart` (slang, jarak suntingan, nama tempat tidak diubah).
- `ai_nlu_e2e_test.dart` (widget hujung ke hujung dengan model palsu yang tidak boleh dipanggil).
- Pengesahan akhir mesti pada telefon. Senarai semak (online dan mod pesawat):
  1. "nk g klcc", "cmne nk gi pavilion", "bawak saya ke ipoh" -> laluan.
  2. "bawa saya ke stesen minyak terdekat", "nak ke tandas" -> laluan ke yang terdekat; "satu lagi" -> yang kedua.
  3. "cari masjid negara" -> senarai bernama (bukan masjid terdekat); lalu "yang pertama".
  4. Selepas laluan: "berapa jauh lagi", "pukul berapa sampai", "berapa tol", "kos minyak".
  5. "balik rumah" (Rumah ditetapkan dan belum), "tukar ke motosikal", "senyap", "mod gelap".
  6. "ok" selepas jawapan bukan laluan -> pengesahan; "ok" selepas tawaran mula -> navigasi bermula.
  7. Semasa navigasi: "stop" -> berhenti; "belok mana", "had laju".
