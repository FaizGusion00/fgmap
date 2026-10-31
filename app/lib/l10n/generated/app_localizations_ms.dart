// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appName => 'FGMaps';

  @override
  String get mapHintLongPress => 'Tekan lama pada peta untuk pilih destinasi';

  @override
  String get mapZoomIn => 'Zum masuk';

  @override
  String get mapZoomOut => 'Zum keluar';

  @override
  String get myLocation => 'Lokasi saya';

  @override
  String get locationFixUnavailable =>
      'GPS belum dapat lokasi yang cukup tepat. Pergi ke kawasan terbuka dan cuba lagi.';

  @override
  String locationAccuracy(int meters) {
    return 'Anggaran ketepatan lokasi ±$meters m';
  }

  @override
  String get mapAttribution => '© penyumbang OpenStreetMap · OpenFreeMap';

  @override
  String get locationRationaleTitle => 'Benarkan akses lokasi?';

  @override
  String get locationRationaleBody =>
      'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar ke pelayan FGMaps hanya untuk mengira laluan.';

  @override
  String get locationAllow => 'Benarkan';

  @override
  String get locationNotNow => 'Bukan sekarang';

  @override
  String get locationOpenSettings => 'Buka Tetapan';

  @override
  String get locationDeniedForeverBody =>
      'Akses lokasi dimatikan. Aktifkan dalam Tetapan untuk guna lokasi semasa anda.';

  @override
  String get locationServiceOffBody =>
      'Perkhidmatan lokasi dimatikan. Hidupkan GPS untuk guna lokasi semasa anda.';

  @override
  String get routeSheetSemantics => 'Ringkasan laluan';

  @override
  String get routeCalculating => 'Mengira laluan…';

  @override
  String get routeLocationUnavailable =>
      'Lokasi GPS yang tepat belum tersedia. Semak kebenaran lokasi dan GPS, kemudian cuba lagi.';

  @override
  String get routeHasTolls => 'Ada tol';

  @override
  String get routeNoTolls => 'Tiada tol';

  @override
  String get routeClear => 'Padam laluan';

  @override
  String get routeRetry => 'Cuba lagi';

  @override
  String get routeErrorNoRoute =>
      'Tiada laluan ditemui ke tempat ini. Cuba pilih jalan lain berdekatan.';

  @override
  String get routeErrorUnavailable =>
      'Perkhidmatan laluan tidak tersedia buat masa ini. Cuba sebentar lagi.';

  @override
  String get routeErrorTimeout =>
      'Pengiraan laluan mengambil masa terlalu lama. Cuba lagi.';

  @override
  String get routeErrorNetwork =>
      'Tiada sambungan ke pelayan. Semak internet anda.';

  @override
  String get routeErrorRateLimited =>
      'Terlalu banyak permintaan. Tunggu sebentar.';

  @override
  String get routeErrorGeneric => 'Sesuatu tidak kena. Cuba lagi.';

  @override
  String distanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String distanceKilometers(String km) {
    return '$km km';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours j $minutes min';
  }

  @override
  String get appearanceTooltip => 'Tetapan';

  @override
  String get appearanceTitle => 'Paparan';

  @override
  String get aboutTitle => 'Tentang FGMaps';

  @override
  String get aboutDescription => 'Aplikasi navigasi komuniti Malaysia';

  @override
  String get aboutVersion => 'Versi';

  @override
  String get aboutVersionLoading => 'Memuatkan…';

  @override
  String get aboutVersionUnavailable => 'Maklumat versi tidak tersedia';

  @override
  String get aboutDeveloper => 'Dibangunkan oleh';

  @override
  String get aboutDeveloperName => 'Faiz Nasir';

  @override
  String get aboutOwner => 'Dimiliki oleh';

  @override
  String get aboutOwnerName => 'FG Universal Empire Company';

  @override
  String aboutCopyright(int year) {
    return '© $year FG Universal Empire Company. Hak cipta terpelihara.';
  }

  @override
  String get themeSystem => 'Ikut sistem';

  @override
  String get themeLight => 'Cerah';

  @override
  String get themeDark => 'Gelap';

  @override
  String get themeAmoled => 'Hitam AMOLED';

  @override
  String get themeAmoledHint =>
      'Latar hitam tulen. Jimat bateri pada skrin OLED dan kurang silau waktu malam.';

  @override
  String get routeErrorOfflineRequired =>
      'Tiada sambungan internet. Muat turun peta offline untuk mengira laluan tanpa internet.';

  @override
  String get routeErrorOfflineEngine =>
      'Peta offline tidak dapat digunakan. Cuba muat turun semula.';

  @override
  String get routeSourceOffline => 'Offline';

  @override
  String get offlineMapsOpen => 'Peta offline';

  @override
  String get offlineMapsTitle => 'Peta offline';

  @override
  String get offlineMapsIntro =>
      'Muat turun peta Malaysia sekali supaya laluan boleh dikira tanpa internet. Dengan internet, laluan dikira secara online (lebih terkini) dan peta offline menjadi sandaran.';

  @override
  String get offlineMapsNotConfigured =>
      'Muat turun peta offline belum dikonfigurasi dalam binaan ini.';

  @override
  String get offlineMapsNotInstalled => 'Belum dimuat turun';

  @override
  String offlineMapsInstalled(String date) {
    return 'Dipasang: $date';
  }

  @override
  String offlineMapsSize(String size) {
    return 'Saiz muat turun $size';
  }

  @override
  String offlineMapsUpdateAvailable(String date) {
    return 'Kemas kini tersedia: $date';
  }

  @override
  String get offlineMapsUpToDate => 'Peta offline terkini';

  @override
  String get offlineMapsDownload => 'Muat turun';

  @override
  String get offlineMapsRetry => 'Cuba lagi';

  @override
  String get offlineMapsUpdate => 'Kemas kini';

  @override
  String get offlineMapsDelete => 'Padam';

  @override
  String get offlineMapsCancel => 'Batal';

  @override
  String get offlineMapsChecking => 'Menyemak…';

  @override
  String offlineMapsDownloading(int percent) {
    return 'Memuat turun… $percent%';
  }

  @override
  String get offlineMapsVerifying => 'Mengesahkan fail…';

  @override
  String get offlineMapsInstalling => 'Memasang…';

  @override
  String get offlineMapsMobileDataTitle => 'Guna data mudah alih?';

  @override
  String offlineMapsMobileDataBody(String size) {
    return 'Muat turun ini kira-kira $size. Anda tidak bersambung ke Wi-Fi.';
  }

  @override
  String get offlineMapsDeleteTitle => 'Padam peta offline?';

  @override
  String get offlineMapsDeleteBody =>
      'Anda perlu memuat turunnya semula untuk menggunakan laluan offline.';

  @override
  String get offlineMapsErrorNetwork =>
      'Tidak dapat menyambung ke pelayan peta offline. Semak internet dan cuba lagi.';

  @override
  String get offlineMapsErrorStorage =>
      'Ruang simpanan tidak mencukupi. Bebaskan ruang dan cuba lagi.';

  @override
  String get offlineMapsErrorChecksum =>
      'Fail yang dimuat turun rosak. Cuba lagi.';

  @override
  String get offlineMapsErrorIncompatible =>
      'Peta offline ini tidak serasi dengan versi app. Kemas kini app.';

  @override
  String get offlineMapsErrorInvalid => 'Maklumat peta offline tidak sah.';

  @override
  String get offlineMapsErrorGeneric => 'Sesuatu tidak kena. Cuba lagi.';

  @override
  String get routingModeTitle => 'Sumber laluan';

  @override
  String get routingModeAuto => 'Auto';

  @override
  String get routingModeOnline => 'Online sahaja';

  @override
  String get routingModeOffline => 'Offline sahaja';

  @override
  String get routingModeAutoHint =>
      'Online dahulu; jika gagal, guna peta offline.';

  @override
  String get tripPlannerTitle => 'Rancang perjalanan';

  @override
  String get tripFrom => 'Dari';

  @override
  String get tripTo => 'Ke';

  @override
  String get searchHint => 'Tempat, alamat, koordinat atau pautan Maps';

  @override
  String get searchPillHint => 'Ke mana?';

  @override
  String get searchClear => 'Kosongkan';

  @override
  String get searchPrompt =>
      'Taip nama tempat, atau pilih Rumah / Kerja di bawah. Boleh juga tampal koordinat (3.14, 101.68) atau pautan Google Maps / Waze.';

  @override
  String get searchHistory => 'Tempat terkini';

  @override
  String get searchClearHistory => 'Padam sejarah';

  @override
  String get sharedLocationStopNavigation =>
      'Tamatkan navigasi semasa sebelum membuka destinasi yang dikongsi.';

  @override
  String searchNoResults(String query) {
    return 'Tiada hasil untuk “$query”. Tampal koordinat atau pautan Google Maps / Waze — kami hanya perlukan lat/lng.';
  }

  @override
  String searchNoNearby(String category) {
    return 'Tiada “$category” ditemui berhampiran dalam OpenStreetMap. Cuba kawasan lain atau cari mengikut nama.';
  }

  @override
  String get searchNearbyRefining => 'Mencari lebih jauh…';

  @override
  String get searchNeedLocation =>
      'Lokasi anda belum diketahui. Hidupkan lokasi untuk mencari tempat berhampiran.';

  @override
  String searchNearbySaved(String when) {
    return 'Pelayan data peta tidak dapat dicapai. Memaparkan hasil tersimpan dari $when.';
  }

  @override
  String get searchErrorNetwork =>
      'Tiada sambungan internet. Carian memerlukan internet; anda masih boleh tampal koordinat atau pautan Maps.';

  @override
  String get searchErrorRateLimited =>
      'Terlalu banyak carian. Tunggu sebentar.';

  @override
  String get searchErrorUnavailable =>
      'Perkhidmatan carian tidak tersedia buat masa ini.';

  @override
  String routeFromTo(String from, String to) {
    return '$from → $to';
  }

  @override
  String get navStart => 'Mula';

  @override
  String get navSimulate => 'Simulasi';

  @override
  String get navSimSpeedTitle => 'Kelajuan simulasi';

  @override
  String get navSimSpeedHint =>
      'Pilih kelajuan jelajah. Auto ikut anggaran laluan (kadang ~18 km/j di bandar). Semasa simulasi, guna butang 1×–4× untuk lebih pantas.';

  @override
  String get navSimSpeedAuto => 'Auto';

  @override
  String navSimSpeedKmh(int kmh) {
    return '$kmh km/j';
  }

  @override
  String navSimSpeedMult(int n) {
    return '$n×';
  }

  @override
  String get navEnd => 'Tamat';

  @override
  String get navEndTitle => 'Tamatkan navigasi?';

  @override
  String get navEndKeep => 'Teruskan';

  @override
  String get navDone => 'Selesai';

  @override
  String get navArrived => 'Anda telah sampai';

  @override
  String get navArrivalSub => 'Sampai di destinasi';

  @override
  String get navRerouting => 'Mengira semula laluan…';

  @override
  String get navRerouteRetry => 'Tiada sambungan. Mencuba semula…';

  @override
  String get navGpsWeak => 'Isyarat GPS lemah';

  @override
  String get navGpsEstimating => 'Tiada isyarat GPS. Kedudukan dianggar.';

  @override
  String get navLocationLost =>
      'Lokasi tidak dapat diakses. Semak kebenaran lokasi.';

  @override
  String get navRecenter => 'Pusatkan';

  @override
  String get navMute => 'Senyapkan suara';

  @override
  String get navUnmute => 'Hidupkan suara';

  @override
  String get navOverview => 'Lihat keseluruhan laluan';

  @override
  String get navChangeRoute => 'Tukar laluan';

  @override
  String get navRoutesTitle => 'Pilih laluan dari sini';

  @override
  String get navRoutesCurrent => 'Laluan semasa';

  @override
  String get navRoutesLoading => 'Mencari laluan dari lokasi anda…';

  @override
  String get navRoutesError => 'Tidak dapat mencari laluan lain sekarang.';

  @override
  String get navRoutesNone => 'Tiada laluan lain dari sini.';

  @override
  String get navRoutesSame => 'Masa sama';

  @override
  String navRoutesFaster(String time) {
    return '$time lebih cepat';
  }

  @override
  String navRoutesSlower(String time) {
    return '$time lebih lambat';
  }

  @override
  String get navRoutesSwitched => 'Laluan ditukar';

  @override
  String get navCameraAuto => 'Kamera auto 3D/2D';

  @override
  String get navCameraFlat => 'Kamera 2D';

  @override
  String get navCameraTilted => 'Kamera 3D';

  @override
  String get navThen => 'Kemudian';

  @override
  String navRoundaboutExitSemantics(int n) {
    return 'Bulatan, ambil simpang keluar ke-$n';
  }

  @override
  String get navLaneLeft => 'Guna lorong kiri';

  @override
  String get navLaneRight => 'Guna lorong kanan';

  @override
  String navLaneStripSemantics(String lanes) {
    return 'Lorong: $lanes';
  }

  @override
  String get navLaneUse => 'Guna lorong yang ditanda';

  @override
  String get navGetReady => 'Bersedia';

  @override
  String get navSimulatedBadge => 'Simulasi';

  @override
  String get navSpeedUnit => 'km/j';

  @override
  String get navSpeedLabel => 'Kelajuan';

  @override
  String get navSettingsTitle => 'Tetapan navigasi';

  @override
  String get navVoiceTitle => 'Suara navigasi';

  @override
  String get navVoiceLanguage => 'Bahasa suara';

  @override
  String get navVoiceFollowApp => 'Ikut app';

  @override
  String get navVoiceMalay => 'Melayu';

  @override
  String get navVoiceEnglish => 'English';

  @override
  String get navCameraTitle => 'Paparan kamera';

  @override
  String get navCameraAutoHint =>
      '3D di jalan lurus, 2D menghampiri selekoh dan bulatan';

  @override
  String get navSettingsOpen => 'Tetapan navigasi';

  @override
  String get navContinue => 'Teruskan';

  @override
  String navEta(String time) {
    return 'Tiba $time';
  }

  @override
  String get navAcquiring => 'Mencari isyarat GPS…';

  @override
  String get routeFastest => 'Terpantas';

  @override
  String get routeShortest => 'Terpendek';

  @override
  String get routeNoHighways => 'Tanpa lebuh raya';

  @override
  String get routeAlternative => 'Alternatif';

  @override
  String routeVia(String road) {
    return 'melalui $road';
  }

  @override
  String routeFindingTo(String place) {
    return 'Mencari laluan ke $place…';
  }

  @override
  String get routeVehicleCar => 'Kereta';

  @override
  String get routeVehicleMotorcycle => 'Motosikal';

  @override
  String get settingsTitle => 'Tetapan';

  @override
  String get settingsAppearance => 'Paparan';

  @override
  String get settingsNavigation => 'Navigasi';

  @override
  String get settingsMaps => 'Peta';

  @override
  String get settingsOfflineHint =>
      'Muat turun peta untuk navigasi tanpa internet';

  @override
  String get settingsAboutHint => 'Versi, pembangun dan hak cipta';

  @override
  String get themeSystemShort => 'Sistem';

  @override
  String get searchCatFuel => 'Stesen minyak';

  @override
  String get searchCatFood => 'Makan';

  @override
  String get searchCatMosque => 'Masjid';

  @override
  String get searchCatToilet => 'Tandas';

  @override
  String get searchCatParking => 'Parkir';

  @override
  String get searchCatHospital => 'Hospital';

  @override
  String get placeKindShopping => 'Beli-belah';

  @override
  String get placeKindFuel => 'Stesen minyak';

  @override
  String get placeKindFood => 'Makan';

  @override
  String get placeKindWorship => 'Tempat ibadat';

  @override
  String get placeKindHealth => 'Kesihatan';

  @override
  String get placeKindParking => 'Parkir';

  @override
  String get placeKindToilets => 'Tandas';

  @override
  String get placeKindTransit => 'Perhentian atau stesen';

  @override
  String get placeKindRoad => 'Jalan';

  @override
  String get placeKindArea => 'Kawasan';

  @override
  String get placeKindAddress => 'Alamat';

  @override
  String get placeKindPlace => 'Tempat';

  @override
  String get placeOppositeSide => 'seberang jalan';

  @override
  String get themeSun => 'Matahari';

  @override
  String get themeSunHint =>
      'Gelap antara matahari terbenam dan terbit di lokasi anda. Dikira dalam peranti, tanpa internet.';

  @override
  String get savedHome => 'Rumah';

  @override
  String get savedWork => 'Kerja';

  @override
  String get savedFavorite => 'Kegemaran';

  @override
  String get savedSetHome => 'Tetapkan Rumah';

  @override
  String get savedSetWork => 'Tetapkan Kerja';

  @override
  String get savedSection => 'Tempat disimpan';

  @override
  String get savedSaveTooltip => 'Simpan tempat';

  @override
  String get savedSheetTitle => 'Simpan sebagai';

  @override
  String get savedChange => 'Tukar';

  @override
  String get savedRemove => 'Padam';

  @override
  String get savedTapToSet => 'Ketik untuk tetapkan';

  @override
  String get savedFavoriteAdd => 'Tambah ke kegemaran';

  @override
  String get savedFavoriteRemove => 'Buang daripada kegemaran';

  @override
  String savedAssigning(String kind) {
    return 'Cari alamat $kind anda';
  }

  @override
  String savedDone(String label) {
    return 'Disimpan sebagai $label';
  }

  @override
  String savedRemoved(String label) {
    return '$label dipadam';
  }

  @override
  String get onbSkip => 'Langkau';

  @override
  String get onbNext => 'Seterusnya';

  @override
  String get onbStart => 'Mula';

  @override
  String get onbWelcomeTitle => 'Navigasi untuk Malaysia';

  @override
  String get onbWelcomeBody =>
      'Panduan belok demi belok untuk kereta dan motosikal, dengan suara dalam Bahasa Melayu atau English.';

  @override
  String get onbFeatureRoutes => 'Laluan terpantas, tanpa tol dan alternatif';

  @override
  String get onbFeatureNearby =>
      'Cari minyak, makan, surau dan tandas berhampiran';

  @override
  String get onbFeatureReports => 'Laporkan bahaya dan polis di jalan';

  @override
  String get onbFeatureOffline => 'Peta offline untuk bila tiada isyarat';

  @override
  String get onbPrivacyTitle => 'Privasi anda';

  @override
  String get onbPrivacyLocal =>
      'Tiada akaun dan tiada penjejakan. Tempat, sejarah dan laporan anda kekal pada telefon ini.';

  @override
  String get onbPrivacyServers =>
      'Untuk carian dan laluan, app menghantar teks carian dan koordinat perjalanan ke perkhidmatan awam OpenStreetMap. Tiada yang lain dihantar.';

  @override
  String get onbPrivacyLocation =>
      'Lokasi hanya digunakan semasa app dibuka, untuk menunjukkan kedudukan anda dan memandu anda.';

  @override
  String get onbSetupTitle => 'Sediakan dalam 10 saat';

  @override
  String get onbVehicleQuestion => 'Anda bergerak dengan apa?';

  @override
  String get onbVoiceQuestion => 'Bahasa suara';

  @override
  String get onbAllowLocation => 'Benarkan lokasi';

  @override
  String get onbLocationGranted => 'Lokasi dibenarkan';

  @override
  String get onbLocationHint =>
      'Anda juga boleh buat ini kemudian apabila memulakan perjalanan pertama.';

  @override
  String onbPageOf(int current, int total) {
    return 'Halaman $current daripada $total';
  }

  @override
  String get settingsTextSize => 'Saiz teks';

  @override
  String get settingsTextSizeHint =>
      'Dikenakan di atas saiz teks telefon anda.';

  @override
  String get settingsEasyMode => 'Mod mudah';

  @override
  String get settingsEasyModeHint =>
      'Teks dan butang lebih besar, kad arahan berkontras tinggi, kawalan lebih sedikit semasa memandu. Sesuai untuk warga emas.';

  @override
  String get onbEasyMode => 'Paparan besar & mudah';

  @override
  String get onbEasyModeHint =>
      'Teks lebih besar, arahan lebih jelas, butang lebih sedikit. Boleh ditukar bila-bila masa dalam Tetapan.';

  @override
  String get navGpsWeakHint => 'Teruskan memandu. Kami sedang mencari isyarat.';

  @override
  String get routeMoreOptions => 'Lanjut';

  @override
  String get settingsAzan => 'Waktu Azan';

  @override
  String get azanTitle => 'Waktu solat';

  @override
  String get azanEnable => 'Notifikasi azan';

  @override
  String get azanEnableHint =>
      'Beritahu saya setiap kali masuk waktu solat di lokasi semasa.';

  @override
  String get azanPrayerFajr => 'Subuh';

  @override
  String get azanPrayerSunrise => 'Syuruk';

  @override
  String get azanPrayerDhuhr => 'Zohor';

  @override
  String get azanPrayerAsr => 'Asar';

  @override
  String get azanPrayerMaghrib => 'Maghrib';

  @override
  String get azanPrayerIsha => 'Isyak';

  @override
  String get azanPrayersLabel => 'Waktu yang diberitahu';

  @override
  String get azanSoundLabel => 'Bunyi';

  @override
  String get azanSoundFull => 'Azan penuh';

  @override
  String get azanSoundShort => 'Nada pendek';

  @override
  String get azanSoundSilent => 'Senyap';

  @override
  String get azanSoundHint =>
      'Azan penuh ialah lalai. Nada pendek atau senyap jika anda mahu lebih tenang.';

  @override
  String get azanMethodLabel => 'Kaedah pengiraan';

  @override
  String get azanMethodJakim => 'JAKIM (Malaysia)';

  @override
  String get azanMethodMwl => 'Liga Muslim Sedunia';

  @override
  String get azanMethodEgyptian => 'Mesir';

  @override
  String get azanMethodKarachi => 'Karachi';

  @override
  String get azanMethodUmmAlQura => 'Umm al-Qura (Makkah)';

  @override
  String get azanMadhabLabel => 'Mazhab (waktu Asar)';

  @override
  String get azanMadhabShafi => 'Syafie';

  @override
  String get azanMadhabHanafi => 'Hanafi';

  @override
  String get azanReminderLabel => 'Peringatan awal';

  @override
  String get azanReminderNone => 'Tiada';

  @override
  String azanReminderMinutes(int n) {
    return '$n min sebelum';
  }

  @override
  String get azanPlayDuringNav => 'Main azan penuh semasa navigasi';

  @override
  String get azanPlayDuringNavHint =>
      'Jika mati: hanya bunyi pendek dan cip pada HUD supaya arahan suara tidak terganggu. Notifikasi tetap dihantar.';

  @override
  String get azanLocationLabel => 'Lokasi';

  @override
  String get azanLocationAuto => 'Ikut lokasi peranti';

  @override
  String get azanLocationCity => 'Pilih bandar';

  @override
  String get azanLocationAutoHint =>
      'Dikira pada telefon ini daripada lokasi anda (dibundarkan ~1 km). Tiada data dihantar.';

  @override
  String azanNextIn(String prayer, String time, String remaining) {
    return '$prayer $time · $remaining lagi';
  }

  @override
  String azanNextPrayer(String prayer, String time) {
    return 'Seterusnya: $prayer pada $time';
  }

  @override
  String get azanAllDone => 'Semua waktu hari ini telah berlalu';

  @override
  String azanNowTitle(String prayer) {
    return 'Waktu $prayer';
  }

  @override
  String get azanNowBody => 'Telah masuk waktu solat.';

  @override
  String get azanStop => 'Hentikan azan';

  @override
  String get azanListen => 'Dengar azan';

  @override
  String get azanStopListening => 'Berhenti';

  @override
  String azanEstimateNote(String method) {
    return 'Anggaran daripada pengiraan astronomi ($method). Jadual rasmi e-Solat JAKIM mungkin berbeza beberapa minit; ikut jadual rasmi untuk berbuka dan imsak.';
  }

  @override
  String get azanExactAlarmTitle => 'Benarkan penggera tepat';

  @override
  String get azanExactAlarmBody =>
      'Tanpa kebenaran ini, Android mungkin melewatkan notifikasi beberapa minit.';

  @override
  String get azanExactAlarmAction => 'Buka tetapan';

  @override
  String get azanPermissionDenied =>
      'Notifikasi tidak dibenarkan. Benarkan dalam tetapan telefon untuk menerima azan.';

  @override
  String azanReminderTitle(String prayer, int n) {
    return '$prayer dalam $n minit';
  }

  @override
  String get azanReminderBody => 'Bersedia untuk solat.';

  @override
  String get azanChannelFull => 'Azan (penuh)';

  @override
  String get azanChannelShort => 'Azan (nada pendek)';

  @override
  String get azanChannelSilent => 'Azan (senyap)';

  @override
  String get azanChannelReminder => 'Peringatan solat';

  @override
  String get azanOpenSettings => 'Tetapan azan';

  @override
  String azanRemainingHours(int h, int m) {
    return '$h j $m min';
  }

  @override
  String azanRemainingMinutes(int m) {
    return '$m min';
  }

  @override
  String azanForCity(String city) {
    return 'Untuk $city';
  }

  @override
  String get azanForCurrentLocation => 'Untuk lokasi semasa';

  @override
  String get azanNotNow => 'Bukan sekarang';

  @override
  String get settingsMusic => 'Muzik';

  @override
  String get musicTitle => 'Muzik';

  @override
  String get musicOpen => 'Muzik';

  @override
  String get musicSearchHint => 'Cari lagu, artis atau radio…';

  @override
  String get musicTabSongs => 'Lagu';

  @override
  String get musicTabRadio => 'Radio';

  @override
  String get musicTabLocal => 'Fail saya';

  @override
  String get musicEmptySongs =>
      'Taip nama lagu atau artis, kemudian ketik untuk main. Lagu daripada Audius (katalog terbuka, percuma).';

  @override
  String get musicEmptyRadio =>
      'Stesen radio Malaysia. Ketik untuk dengar siaran langsung.';

  @override
  String get musicEmptyLocal =>
      'Import lagu dari telefon anda. Ia disimpan dalam app dan sentiasa boleh dimainkan tanpa internet.';

  @override
  String musicNoResults(String query) {
    return 'Tiada hasil untuk “$query”.';
  }

  @override
  String get musicOffline => 'Tiada internet. Hanya fail saya boleh dimainkan.';

  @override
  String musicErrorSource(String source) {
    return '$source tidak dapat dihubungi sekarang.';
  }

  @override
  String get musicImport => 'Import dari telefon';

  @override
  String musicImported(int n) {
    return '$n lagu ditambah';
  }

  @override
  String get musicRemove => 'Buang';

  @override
  String get musicLive => 'LANGSUNG';

  @override
  String get musicViaAudius => 'via Audius';

  @override
  String get musicAttribution =>
      'Lagu daripada Audius · Radio daripada Radio Browser · Fail anda kekal pada telefon';

  @override
  String get musicNowPlaying => 'Sedang dimainkan';

  @override
  String get musicPlay => 'Main';

  @override
  String get musicPause => 'Jeda';

  @override
  String get musicNext => 'Seterusnya';

  @override
  String get musicPrevious => 'Sebelumnya';

  @override
  String get musicStop => 'Tutup pemain';

  @override
  String get musicVolume => 'Kelantangan';

  @override
  String get musicQueue => 'Baris gilir';

  @override
  String get musicEqualizer => 'Penyama (Equalizer)';

  @override
  String get musicEqPresetNormal => 'Normal';

  @override
  String get musicEqPresetBass => 'Bes';

  @override
  String get musicEqPresetTreble => 'Trebel';

  @override
  String get musicEqPresetVocal => 'Suara';

  @override
  String get musicEqPresetCustom => 'Tersuai';

  @override
  String get musicEqUnsupported => 'Penyama hanya tersedia pada Android.';

  @override
  String get musicEqEnable => 'Hidupkan penyama';

  @override
  String get musicDuckTitle => 'Semasa suara navigasi bercakap';

  @override
  String get musicDuckLower => 'Perlahankan muzik';

  @override
  String get musicDuckLowerHint =>
      'Lalai. Muzik diperlahankan semasa arahan, kemudian pulih.';

  @override
  String get musicDuckPause => 'Jeda muzik';

  @override
  String get musicDuckPauseHint =>
      'Muzik berhenti sepenuhnya semasa arahan, kemudian sambung.';

  @override
  String get musicOpenPlayer => 'Buka Muzik';

  @override
  String get musicClearLocal => 'Padam semua fail saya';

  @override
  String get musicSourceAudius => 'Audius';

  @override
  String get musicSourceRadio => 'Radio Browser';

  @override
  String get musicSourceLocal => 'Fail saya';

  @override
  String get musicLoading => 'Memuatkan…';

  @override
  String get musicError => 'Tidak dapat dimainkan. Cuba lagu lain.';

  @override
  String get musicDucked => 'Suara navigasi';

  @override
  String get settingsReduceMotion => 'Kurangkan animasi';

  @override
  String get settingsReduceMotionHint =>
      'Kurang kesan bergerak. Turut mengikut tetapan telefon anda.';

  @override
  String get settingsHaptics => 'Maklum balas getaran';

  @override
  String get settingsLanguage => 'Bahasa app';

  @override
  String get settingsLanguageSystem => 'Peranti';

  @override
  String get settingsLanguageMalay => 'Bahasa Melayu';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsVoice => 'Suara';

  @override
  String get settingsVoiceVolume => 'Kelantangan suara';

  @override
  String get settingsVolumeLow => 'Perlahan';

  @override
  String get settingsVolumeMedium => 'Sederhana';

  @override
  String get settingsVolumeHigh => 'Kuat';

  @override
  String get settingsSpeechRate => 'Kelajuan pertuturan';

  @override
  String get settingsRateSlow => 'Perlahan';

  @override
  String get settingsRateNormal => 'Biasa';

  @override
  String get settingsRateFast => 'Pantas';

  @override
  String get settingsReports => 'Laporan';

  @override
  String get settingsReportAlerts => 'Amaran laporan semasa memandu';

  @override
  String get settingsReportAlertsHint =>
      'Mengumumkan laporan di hadapan dan bertanya jika masih ada.';

  @override
  String get settingsPrivacy => 'Privasi';

  @override
  String get settingsLocationAllowed => 'Akses lokasi: dibenarkan';

  @override
  String get settingsLocationNotAllowed => 'Akses lokasi: tidak dibenarkan';

  @override
  String get settingsLocationOff => 'Perkhidmatan lokasi dimatikan';

  @override
  String get settingsLocationOpen => 'Buka tetapan telefon';

  @override
  String get settingsClearHistory => 'Padam sejarah carian';

  @override
  String get settingsClearSaved => 'Padam tempat disimpan';

  @override
  String get settingsClearReports => 'Padam laporan saya';

  @override
  String get settingsConfirmTitle => 'Padam data ini?';

  @override
  String get settingsConfirmBody =>
      'Ini hanya melibatkan telefon ini dan tidak boleh dibatalkan.';

  @override
  String get settingsConfirmDelete => 'Padam';

  @override
  String get settingsConfirmCancel => 'Batal';

  @override
  String get settingsDeleted => 'Dipadam';

  @override
  String get settingsHelp => 'Bantuan & tentang';

  @override
  String get settingsWelcomeAgain => 'Papar semula sambutan';

  @override
  String get settingsLicences => 'Lesen sumber terbuka';

  @override
  String get splashTagline => 'Navigasi komuniti Malaysia';

  @override
  String get searchCategories => 'Cari berhampiran';

  @override
  String get reportTitle => 'Laporkan di sini';

  @override
  String get reportButtonTooltip => 'Laporkan';

  @override
  String get reportTypePolice => 'Polis';

  @override
  String get reportTypeAccident => 'Kemalangan';

  @override
  String get reportTypeHazard => 'Bahaya';

  @override
  String get reportTypeJam => 'Sesak';

  @override
  String get reportTypeClosed => 'Jalan ditutup';

  @override
  String get reportTypeBrokenDown => 'Kenderaan rosak';

  @override
  String get reportTypeFlood => 'Banjir';

  @override
  String get reportCreated => 'Laporan dihantar. Terima kasih!';

  @override
  String get reportConfirmedExisting =>
      'Laporan serupa sudah ada berdekatan; ia disahkan.';

  @override
  String get reportNoLocation =>
      'Lokasi anda tidak tersedia. Laporan mesti dibuat dari lokasi sebenar anda.';

  @override
  String get reportLocalOnlyNote =>
      'Laporan disimpan pada peranti ini sahaja dan belum dikongsi dengan pemandu lain.';

  @override
  String reportStillThereTitle(String type) {
    return '$type masih ada?';
  }

  @override
  String get reportStillThereYes => 'Ya, masih ada';

  @override
  String get reportStillThereNo => 'Tiada';

  @override
  String reportAhead(String type, String distance) {
    return '$type $distance di hadapan';
  }

  @override
  String get navSpeedLimit => 'Had laju';

  @override
  String get navOverspeedTitle => 'Amaran laju lebih';

  @override
  String get navOverspeedOff => 'Mati';

  @override
  String get navOverspeedHint =>
      'Bunyi dan tanda merah apabila melebihi had laju. Had laju tidak lengkap di semua jalan.';

  @override
  String get savedBySearch => 'Cari alamat';

  @override
  String get savedBySearchHint => 'Taip nama tempat atau alamat';

  @override
  String get savedByCurrent => 'Guna lokasi semasa';

  @override
  String get savedByCurrentHint => 'Simpan kedudukan anda sekarang';

  @override
  String get savedCurrentLocation => 'Lokasi semasa';

  @override
  String get savedLocating => 'Mencari lokasi anda…';

  @override
  String get savedGoHint =>
      'Ketik untuk mula navigasi · tekan lama untuk tukar';

  @override
  String get autoStartCancel => 'Batal';

  @override
  String get navThemeTitle => 'Paparan peta';

  @override
  String get settingsSavedPlaces => 'Rumah dan Kerja';

  @override
  String get savedNotSet => 'Belum ditetapkan';

  @override
  String autoStartCountdown(String name, int seconds) {
    return 'Memulakan navigasi ke $name dalam $seconds…';
  }

  @override
  String get routeRecommended => 'Disyorkan';

  @override
  String get routeSimplest => 'Paling mudah';

  @override
  String get routeSearchingMore => 'Mencari laluan lain…';

  @override
  String get routeHasHighway => 'Lebuh raya';

  @override
  String get routeHasFerry => 'Feri';

  @override
  String routeTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count belokan',
      one: '1 belokan',
      zero: 'Tiada belokan',
    );
    return '$_temp0';
  }

  @override
  String routeCount(int count) {
    return '$count laluan';
  }

  @override
  String routeMore(int count) {
    return 'Lagi $count';
  }

  @override
  String routeTollRm(String amount) {
    return 'RM $amount';
  }

  @override
  String routeTollRmPartial(String amount) {
    return 'RM $amount+';
  }

  @override
  String routeTollPlazaCount(int count) {
    return '$count plaza';
  }

  @override
  String routeTollEstimateExact(String amount) {
    return 'Tol RM $amount';
  }

  @override
  String routeTollEstimatePartial(String amount) {
    return 'Tol RM $amount+ (sebahagian)';
  }

  @override
  String routeTollPlazasUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plaza tol',
      one: '1 plaza tol',
    );
    return '$_temp0, harga tidak diketahui';
  }

  @override
  String routeTollOn(String roads) {
    return 'Tol: $roads';
  }

  @override
  String get routeTollDisclaimer =>
      'Anggaran untuk kereta (kelas 1) daripada kadar Lembaga Lebuhraya Malaysia; semak harga di plaza.';

  @override
  String get settingsClearAll => 'Padam semua data saya';

  @override
  String get settingsClearAllHint =>
      'Sejarah carian, tempat disimpan, laporan dan data simpanan lokasi pada peranti ini.';

  @override
  String get legalPrivacyTitle => 'Dasar Privasi';

  @override
  String get legalTermsTitle => 'Terma Penggunaan';

  @override
  String get legalLoadFailed => 'Dokumen tidak dapat dimuatkan.';

  @override
  String get legalDraftNotice =>
      'Draf: dokumen ini belum disemak oleh peguam dan tidak boleh dianggap nasihat undang-undang.';

  @override
  String get legalConsent =>
      'Dengan meneruskan, anda bersetuju dengan Terma Penggunaan dan Dasar Privasi.';

  @override
  String get legalAttribution =>
      'Data peta © penyumbang OpenStreetMap (ODbL). Gaya dan jubin: OpenFreeMap, OpenMapTiles. Laluan: Valhalla. Carian: Photon (komoot) dan Nominatim. Harga petrol: data.gov.my. Muzik: Audius (Open Music License) dan Radio Browser; strim radio daripada stesen masing-masing. Rakaman azan: Aaqib Azeez / Atcovi, Wikimedia Commons, CC BY-SA 4.0.';

  @override
  String get aboutAttributionTitle => 'Sumber data';

  @override
  String get settingsFuel => 'Kos minyak';

  @override
  String get fuelTypeRon95 => 'RON95';

  @override
  String get fuelTypeRon97 => 'RON97';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelConsumptionCar => 'Penggunaan kereta (L/100 km)';

  @override
  String get fuelConsumptionMoto => 'Penggunaan motosikal (L/100 km)';

  @override
  String get fuelManualPrice => 'Harga seliter saya (RM)';

  @override
  String get fuelManualPriceHint =>
      'Kosongkan untuk guna harga data.gov.my. Isi jika harga yang anda bayar berbeza (cth. RON95 subsidi).';

  @override
  String get fuelPriceUnavailable =>
      'Harga terkini tidak dapat diambil. Isi harga sendiri untuk melihat anggaran kos minyak.';

  @override
  String get fuelEstimateNote =>
      'Anggaran kos minyak berdasarkan jarak, penggunaan dan harga di atas.';

  @override
  String get shareDestinationTooltip => 'Kongsi destinasi';

  @override
  String get shareEtaAction => 'Kongsi masa tiba';

  @override
  String get shareFailed => 'Tidak dapat membuka lembaran kongsi.';

  @override
  String get emergencyTooltip => 'Kecemasan';

  @override
  String get emergencyTitle => 'Kecemasan';

  @override
  String get emergencyBody =>
      'Dalam kecemasan, hubungi terus. Butang ini hanya jalan pintas dan tidak menjamin panggilan, ketepatan lokasi atau bantuan tiba.';

  @override
  String get emergencyCall999 => 'Hubungi 999';

  @override
  String get emergencyCall999Hint => 'Polis, bomba, ambulans';

  @override
  String get emergencyCall112 => 'Hubungi 112';

  @override
  String get emergencyCall112Hint =>
      'Nombor kecemasan antarabangsa untuk telefon bimbit';

  @override
  String get emergencyConfirmCall => 'Hubungi';

  @override
  String get emergencyConfirmBody =>
      'Papan nombor akan dibuka. Tekan butang panggil untuk menyambung.';

  @override
  String get emergencyShareLocation => 'Kongsi lokasi tepat saya';

  @override
  String get emergencyNoLocation =>
      'Lokasi anda belum diketahui. Cuba di tempat terbuka atau hidupkan lokasi.';

  @override
  String routeFuelCost(String amount) {
    return '≈ RM $amount minyak';
  }

  @override
  String fuelPriceSource(String price, String date) {
    return 'Harga data.gov.my: RM $price/L ($date)';
  }

  @override
  String emergencyConfirmTitle(String number) {
    return 'Hubungi $number sekarang?';
  }

  @override
  String shareDestinationText(
    String name,
    String eta,
    String duration,
    String distance,
    String link,
  ) {
    return 'Saya menuju ke $name. Anggaran tiba $eta ($duration, $distance).\n$link';
  }

  @override
  String shareEtaText(String name, String eta, String distance, String link) {
    return 'Saya sedang menuju ke $name. Anggaran tiba $eta, baki $distance.\n$link';
  }

  @override
  String emergencyShareText(String coords, String link) {
    return 'Saya memerlukan bantuan. Lokasi saya: $coords\n$link';
  }

  @override
  String emergencyDialFailed(String number) {
    return 'Papan nombor tidak dapat dibuka. Dail $number secara manual.';
  }

  @override
  String get errorWidgetMessage => 'Bahagian ini tidak dapat dipaparkan.';

  @override
  String get settingsCopyErrorReport => 'Salin laporan ralat';

  @override
  String get settingsCopyErrorReportHint =>
      'Log ralat disimpan pada telefon ini sahaja dan tidak dihantar. Salin dan hantar sendiri jika perlu.';

  @override
  String get settingsErrorReportCopied => 'Laporan ralat disalin';

  @override
  String get settingsErrorReportEmpty => 'Tiada ralat direkodkan';
}
