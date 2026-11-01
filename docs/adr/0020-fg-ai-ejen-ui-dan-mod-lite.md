# ADR 0020: FG AI menggunakan app di skrin (ejen UI) dan Mod Lite untuk telefon rendah

Status: diterima (2026-11-01). Kod: `core/agent/` (`agent_targets.dart`, `agent_controller.dart`, `agent_overlay.dart`),
`features/local_assistant/presentation/agent_scripts.dart`, `core/settings/device_tier.dart`, `app/app.dart`,
`app/router.dart`. Saluran platform `com.fguniversalempire.fgmaps/device` (`MainActivity.kt`, `AppDelegate.swift`).

## Konteks

Pemilik mahu FG AI "pro guna semua dalam system kita" dan pengguna NAMPAK apa yang AI tekan, bila ia berfikir, dan ke
mana ia pergi. Bila ditanya, pemilik memilih kedua-dua bentuk paparan: jari di skrin DAN senarai langkah dalam sembang.
Pemilik juga mahu app laju pada telefon paling rendah, dengan bateri yang jimat.

## Keputusan: ejen UI

1. **Tekan widget sebenar, bukan laluan rahsia.**
   - Kawalan didaftarkan dengan `AgentTarget(id: 'tool.weather', …)` (GlobalKey mengikut id yang stabil).
   - Ejen menghantar peristiwa sentuhan sintetik (`kAgentPointerDevice`) ke kedudukan kawalan itu.
   - Apa sahaja yang ejen boleh buat, pengguna juga boleh buat dengan tangan, dan sebaliknya.
   - Menaip menggunakan `EditableTextState.userUpdateTextEditingValue`, huruf demi huruf, jadi `onChanged` berjalan
     seperti papan kekunci sebenar.
2. **Lapisan `AgentOverlay` dalam `MaterialApp.builder`:**
   - sorotan malap pada sasaran;
   - jari hantu yang bergerak lalu beriak semasa menekan;
   - kad status dengan senarai semak (✓ siap, ● sedang, ○ belum) dan butang Henti.
   Kad diletak di separuh skrin yang bertentangan dengan sasaran, di atas papan kekunci. Sentuhan pengguna sebenar
   menghentikan ejen. Bila larian tamat, ringkasan langkah ditambah ke sembang.
3. **Jujur tentang apa yang berlaku.**
   - Sentuhan diuji-hit pada kandungan app SAHAJA (di bawah lapisan ejen, `agentAppKey`), lalu dihantar terus ke
     laluan itu (`GestureBinding.dispatchEvent`). Kad status, sorotan dan jari tidak boleh menyerap sentuhan ejen.
   - Jika titik tidak sampai ke kawalan sasaran (dialog lain di atasnya, halaman masih beranimasi selepas 1.8 s),
     ejen tidak menekan apa-apa dan langkah ditanda ✗.
   - Langkah yang bergantung pada kesan menyemak kesannya: memilih bandar dalam Cuaca menunggu lembaran carian
     tertutup, dan laluan menunggu butang Mula.
4. **Ketahanan.**
   - Ejen menunggu sasaran berhenti bergerak (animasi halaman/lembaran) sebelum menekan, dan mengikutnya jika susun
     atur berubah semasa jari bergerak.
   - Hasil carian yang tidak muncul dicuba semula sekali dengan butang "Cari" papan kekunci (`tapResult`).
     Perancang kini mencari semula pada `onSubmitted`.
5. **Skrip dan pintu masuk.**
   - Skrip terhad: buka cuaca (+ cari bandar), kiblat, kualiti udara, muzik, waktu solat, peta offline, tetapan,
     laporan, pusatkan peta, cari tempat di peta, dan kategori terdekat → pilih → laluan (→ mula).
   - Pintu masuk: penghala (`OpenScreenIntent`: "buka cuaca Kuantan", "cari masjid terdekat dan pergi") dan alat
     model `app_action` (enum id + satu argumen). Model tidak boleh mencipta sentuhan sembarangan.
   - Tindakan merosakkan atau luaran (SOS, padam data, tamat navigasi) tidak diskripkan. Dialog pengesahan sedia ada
     tetap pada pengguna.

## Keputusan: Mod Lite

1. **Tahap peranti.** Tahap dikesan daripada RAM, `isLowRamDevice` dan bilangan teras: rendah jika ≤ 3.2 GB,
   `lowRam` atau ≤ 4 teras; sederhana jika ≤ 6.2 GB. Tetapan "Mod Lite" (Auto/Hidup/Mati) menindih pengesanan.
   Nilainya dicerminkan ke `LiteMode.enabled` statik untuk kod yang tidak memegang `ref`.
2. **Kesan Mod Lite:**
   - bangunan 3D disembunyikan;
   - pam bingkai pemanduan dihadkan ke 30 fps;
   - bayang kereta tanpa `MaskFilter.blur`;
   - animasi hiasan menjadi statik (gelombang carian, AI, ikon cuaca, rangka, denyut muat peta);
   - animasi tema sifar;
   - GPS ketika tidak menavigasi dijarangkan (10 m / 4 s);
   - jari ejen melompat terus ke sasaran, dan menaip berlaku sekali gus.
3. **Untuk semua tahap:**
   - Skrin peta tidak lagi dibina semula 4×/s semasa navigasi: `.select` dan `Consumer` untuk HUD dan bebola laju.
   - Pembersihan laporan hanya mengubah keadaan bila kandungan berubah.
   - Denyut lokasi dan pembersihan berhenti ketika app di latar belakang.
   - Model AI dilepaskan dari RAM bila app dijeda.
   - Gaya peta malam dibina dalam isolat lain (`compute`).
   - Karya seni muzik dinyahkod pada saiz paparan.
   - Model AI yang terlalu berat untuk RAM telefon ditanda dan perlu pengesahan sebelum dimuat turun.

## Akibat

- Skrip mesti dikemas kini bila id kawalan berubah. Langkah yang hilang sasarannya gagal dengan jujur (✗); ia tidak
  tergantung.
- Ejen hanya boleh melakukan skrip yang ada. Permintaan lain dijawab dalam sembang.
- Disahkan pada emulator (build release, 2026-11-01): "buka cuaca Kuantan/Ipoh" membuka Cuaca dengan bandar itu;
  "cari masjid terdekat dan pergi" melalui carian → kategori → hasil terdekat → laluan → navigasi bermula.
- Belum diuji pada iPhone sebenar, dan belum diukur pada AVD 2 GB / 2 teras.
