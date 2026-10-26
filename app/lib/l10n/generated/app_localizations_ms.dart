// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appName => 'FGMap';

  @override
  String get mapHintLongPress => 'Tekan lama pada peta untuk pilih destinasi';

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
      'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar ke pelayan FGMap hanya untuk mengira laluan.';

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
  String get routeFromMapCenter =>
      'Lokasi anda tidak tersedia, jadi laluan dikira dari pusat peta.';

  @override
  String routeOptionLabel(int index) {
    return 'Laluan $index';
  }

  @override
  String get routeAvoidTolls => 'Elak tol';

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
  String get appearanceTooltip => 'Paparan';

  @override
  String get appearanceTitle => 'Paparan';

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
  String get searchHint => 'Cari tempat atau alamat';

  @override
  String get searchPillHint => 'Cari destinasi';

  @override
  String get searchClear => 'Kosongkan';

  @override
  String get searchPrompt =>
      'Taip nama tempat, jalan atau alamat. Anda juga boleh tekan lama pada peta.';

  @override
  String searchNoResults(String query) {
    return 'Tiada hasil untuk “$query”.';
  }

  @override
  String get searchErrorNetwork =>
      'Tiada sambungan internet. Carian memerlukan internet; anda masih boleh tekan lama pada peta untuk memilih destinasi.';

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
  String get navCameraAuto => 'Kamera auto 3D/2D';

  @override
  String get navCameraFlat => 'Kamera 2D';

  @override
  String get navCameraTilted => 'Kamera 3D';

  @override
  String get navThen => 'Kemudian';

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
  String get navVoiceMalay => 'Bahasa Melayu';

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
}
