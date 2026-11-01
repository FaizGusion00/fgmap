# ADR 0015: FG AI: penghala arahan, sesi model berterusan, dan senarai perbualan

Status: diterima (2026-11-01). Kod: `features/local_assistant/` (`domain/intent_router.dart`,
`data/edge_ai_runtime.dart`, `data/chat_history_store.dart`, `presentation/ai_chat_page.dart`).

## Konteks

Ujian pemilik pada telefon sebenar:
- **Jawapan berulang:** "FGMaps AI" mengulang "KLCC is a destination…" walaupun destinasi sudah bertukar
  ke Kuala Terengganu.
- **Tidak bertindak:** model bertanya "start now?" dan bukannya bertindak.
- **Perlahan.**
- **Kotak taip** tersorok di belakang papan kekunci.
- **FGMuslim:** rujukan dipaparkan sebagai longgokan URL.

Punca yang ditemui:
- **Teks bercampur:** `generateChatResponseWithTools` menghantar teks SETIAP giliran (termasuk "." sebelum
  panggilan alat). Runtime mencantum semuanya.
- **Jawapan lama dijadikan contoh:** 6 jawapan lama dimainkan semula sebagai giliran model, dan model 0.6B
  menyalinnya.
- **Prompt menggalakkan pengulangan:** arahan sistem dan hasil alat sendiri menyuruh "user taps Start".
- **Sesi dibina semula setiap mesej:** `clearHistory()` mencipta sesi natif baharu dan menyuap semula
  arahan sistem dan 11 skema alat.
- **Model dilepaskan setiap kali lembaran ditutup.**

## Keputusan

1. **Penghala arahan sebelum model.**
   - Arahan peta dalam BM/BI dihurai oleh kod, dan alat dijalankan terus. Jawapan bertemplat (ARB)
     menggunakan angka daripada data sebenar.
   - Arahan yang dikenali: laluan, mula, pilihan laluan, batal, berdekatan, carian, cuaca, IPU, kiblat,
     waktu solat, sepanjang laluan, muzik dan radio.
   - Pantas, tidak pernah mengulang, dan berfungsi walaupun model belum dimuat turun.
   - "Navigate to"/"bawa saya ke"/"… start now" memulakan navigasi terus.
   - "start now" selepas laluan memulakannya tanpa bertanya.
   - Peta mendengar `aiMapRequestProvider`, menutup halaman AI, dan memulakan navigasi melalui
     `_startNavigation` yang sama (kebenaran lokasi tetap disemak).
2. **Pilihan laluan jujur.** `chooseRoute`:
   - pantas, pendek, tanpa tol, tanpa lebuh raya, murah (tol + minyak);
   - **"selamat"** = wakil berdasarkan jenis jalan (jalan utama, kurang belokan/pusingan-U, tiada feri,
     ≤ 20% lebih lama). Jawapan menyatakan ia **bukan data kemalangan**: tiada dataset kemalangan
     percuma untuk Malaysia.
3. **Model kecil kekal (Qwen3 0.6B) tetapi lebih pantas:**
   - sesi berterusan setiap perbualan; sejarah ringkas (2 pusingan, jawapan dipotong) hanya bila sesi
     baharu;
   - model dipanaskan bila halaman dibuka dan dilepaskan selepas 3 minit rehat;
   - 4 skema alat untuk model (bukan 11);
   - konteks 1536, output 320;
   - GPU dicuba sekali: jika gagal (atau app mati semasa mencuba) CPU digunakan seterusnya;
   - teks dialirkan ke skrin;
   - teks sebelum panggilan alat dibuang, dan ayat berulang dibuang (`cleanReply`).
   Masa token pertama dan jumlah masa dicatat dalam log diagnostik untuk diukur pada telefon sebenar.
4. **Dua halaman penuh berasingan** (FG AI, FGMuslim AI), masing-masing dengan senarai perbualan seperti
   ChatGPT:
   - baharu, buka, namakan semula, padam (dengan buat asal), dan padam semua;
   - disimpan pada peranti (SharedPreferences, 50 perbualan × 100 mesej);
   - sembang lama dipindahkan sekali, dan "padam data" memadam semuanya.
5. **FGMuslim berstruktur.** Rujukan disimpan sebagai data, bukan teks:
   - nota piawai diterjemah semasa dipaparkan;
   - senarai rujukan di hujung jawapan model dibuang (penanda [n] kekal);
   - kad sumber boleh dilipat, dikumpul (teks klasik, fatwa);
   - islamic.app dan deen.ai dipanggil serentak.

## Akibat

- Kecerdasan untuk soalan umum masih terhad oleh model 0.6B (keputusan pemilik: kekalkan model kecil).
  Arahan peta tidak lagi bergantung padanya.
- Corak ayat penghala perlu dikembangkan mengikut cara pengguna sebenar bercakap; ujian
  `intent_router_test.dart` ialah senarai rujukan.
- Kelajuan GPU berbeza antara telefon; laluan CPU kekal sebagai sandaran selamat.
