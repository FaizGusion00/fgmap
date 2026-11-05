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
  String get mapAttribution =>
      '© penyumbang OpenStreetMap · © OpenMapTiles · OpenFreeMap';

  @override
  String get locationRationaleTitle => 'Benarkan akses lokasi?';

  @override
  String get locationRationaleBody =>
      'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar terus ke perkhidmatan laluan awam hanya untuk mengira laluan dan tidak disimpan di mana-mana pelayan kami.';

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
  String get mapLayersTooltip => 'Jenis peta';

  @override
  String get mapLayersTitle => 'Jenis peta';

  @override
  String get mapLayerStandard => 'Lalai';

  @override
  String get mapLayerSatellite => 'Satelit';

  @override
  String get mapLayerSatelliteHint =>
      'Satelit perlukan internet. Imej: Esri, Maxar, Earthstar Geographics.';

  @override
  String get masjidOpen => 'Masjid & surau';

  @override
  String get masjidDirectoryTitle => 'Masjid & surau Malaysia';

  @override
  String get masjidDirectoryLoadFailed =>
      'Senarai tidak dapat dimuat. Cuba buka semula.';

  @override
  String get masjidSearchHint => 'Cari nama, kampung, daerah atau poskod';

  @override
  String get masjidClear => 'Kosongkan';

  @override
  String get masjidAll => 'Semua';

  @override
  String get masjidTypeMasjid => 'Masjid';

  @override
  String get masjidTypeSurau => 'Surau';

  @override
  String get masjidAllStates => 'Semua negeri';

  @override
  String get masjidAllDistricts => 'Semua daerah';

  @override
  String get masjidStateTitle => 'Negeri';

  @override
  String get masjidDistrictTitle => 'Daerah';

  @override
  String get masjidFilterSearch => 'Cari';

  @override
  String get masjidFilterEmpty => 'Tiada padanan';

  @override
  String masjidCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tempat',
      one: '1 tempat',
    );
    return '$_temp0';
  }

  @override
  String get masjidNoResults =>
      'Tiada masjid atau surau sepadan. Cuba perkataan lain atau buang penapis.';

  @override
  String get masjidAttribution =>
      'Senarai: JAKIM melalui data.gov.my (CC BY), data 2019, mungkin ada yang sudah berubah. Lokasi tepat: OpenStreetMap.';

  @override
  String get masjidApproximateHint =>
      'Lokasi tepat belum ada: FGMaps akan cari alamat ini (lokasi anggaran).';

  @override
  String get masjidNotFound =>
      'Lokasi tidak ditemui. Cuba cari nama tempat ini dalam carian peta.';

  @override
  String get masjidDirections => 'Arah';

  @override
  String get masjidGo => 'Pergi';

  @override
  String masjidApproximateSnack(String name) {
    return 'Lokasi anggaran daripada alamat: $name';
  }

  @override
  String get webSearchOpen => 'Cari di Google';

  @override
  String webSearchFor(String query) {
    return 'Cari \"$query\" di Google';
  }

  @override
  String get webSearchPlannerHint =>
      'Tekan Arah pada tempat untuk buka laluan dalam FGMaps';

  @override
  String get webSearchHint => 'Cari di Google';

  @override
  String get webSearchReload => 'Muat semula';

  @override
  String get webSearchClear => 'Padam data pelayar';

  @override
  String get webSearchCleared => 'Data pelayar dipadam';

  @override
  String get webSearchBanner =>
      'Tekan \"Arah\" atau peta pada tempat: laluan dibuka dalam FGMaps.';

  @override
  String get webSearchPlace => 'Tempat daripada Google';

  @override
  String get routeTollTitle => 'Anggaran tol';

  @override
  String get routeTollPriceUnknown => 'Harga tol belum ada dalam data kami';

  @override
  String routeTollUnpricedPlazas(int count) {
    return '$count plaza tiada harga';
  }

  @override
  String get routeFuelTitle => 'Minyak';

  @override
  String routeCostApprox(String amount) {
    return '≈ RM $amount';
  }

  @override
  String get webSearchResolving => 'Mendapatkan lokasi tepat daripada Google…';

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
      'Muat turun peta Malaysia sekali untuk melihat peta, merancang laluan dan mencari tempat tanpa internet. Dengan internet, laluan dan carian menggunakan perkhidmatan dalam talian (lebih terkini) dan peta offline menjadi sandaran.';

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
      'Anda perlu memuat turunnya semula untuk menggunakan paparan peta, laluan dan carian offline.';

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
  String get searchOfflinePackPrompt =>
      'Muat turun indeks tempat offline untuk carian Malaysia yang lebih lengkap — tiada suis berasingan.';

  @override
  String get searchOfflinePackUpdate =>
      'Kemas kini pek peta offline untuk dapat tempat baharu.';

  @override
  String get searchOfflinePackAction => 'Peta offline';

  @override
  String get searchQuickDestinations => 'Pergi sekarang';

  @override
  String get searchResultOffline => 'Offline';

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
  String get navLaneRightmost => 'Guna lorong paling kanan';

  @override
  String get navLaneLeftmost => 'Guna lorong paling kiri';

  @override
  String navLaneRightmostN(int count) {
    return 'Guna $count lorong paling kanan';
  }

  @override
  String navLaneLeftmostN(int count) {
    return 'Guna $count lorong paling kiri';
  }

  @override
  String navLaneNthFromLeft(int n) {
    return 'Guna lorong ke-$n dari kiri';
  }

  @override
  String navLaneNthFromRight(int n) {
    return 'Guna lorong ke-$n dari kanan';
  }

  @override
  String get navLaneEstimated => 'Anggaran lorong';

  @override
  String get navJunctionCross => 'Simpang 4';

  @override
  String get navJunctionTee => 'Simpang 3';

  @override
  String navJunctionRoundabout(int n) {
    return 'Bulatan · keluar ke-$n';
  }

  @override
  String navJunctionSemantics(String kind) {
    return 'Gambar simpang: $kind';
  }

  @override
  String navLaneViewSemantics(int count) {
    return 'Paparan $count lorong';
  }

  @override
  String navLaneViewHintSemantics(String hint) {
    return 'Paparan lorong. $hint';
  }

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
  String get searchCatMosque => 'Masjid / surau';

  @override
  String get searchCatToilet => 'Tandas';

  @override
  String get searchCatParking => 'Parkir';

  @override
  String get searchCatHospital => 'Hospital';

  @override
  String get searchCategories => 'Berhampiran dari lokasi anda';

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
  String get azanEnable => 'Sentiasa ingatkan waktu azan';

  @override
  String get azanEnableHint =>
      'Notifikasi dan bunyi azan pada setiap waktu solat, walaupun app ditutup.';

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
  String azanNextTomorrow(String prayer, String time) {
    return 'Esok: $prayer $time';
  }

  @override
  String azanRemainingLeft(String remaining) {
    return '$remaining lagi';
  }

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
      'Taip nama lagu atau artis, atau ketik cadangan di atas. Katalog percuma Audius ialah muzik bebas; lagu artis label besar tiada di sini. Untuk lagu penuh artis label besar, ketik Spotify atau YouTube Music di atas untuk cari dalam app anda sendiri, atau cuba tab Radio.';

  @override
  String get musicEmptyRadio =>
      'Pilih kawasan di atas, atau taip nama stesen (cth. Hitz, Prambors, KBS). Ketik untuk dengar siaran langsung.';

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
  String get musicSourceAppleMusic => 'Apple Music';

  @override
  String get musicViaAppleMusic => 'via Apple Music';

  @override
  String get musicAppleConnectTitle => 'Lagu penuh dengan Apple Music';

  @override
  String get musicAppleConnectBody =>
      'Sambung langganan Apple Music anda untuk cari dan main lagu penuh Malay, Indonesia, Japan dan K-pop. Carian dan lagu terus melalui Apple; FGMaps tidak melihat akaun anda.';

  @override
  String get musicAppleConnect => 'Sambung Apple Music';

  @override
  String get musicAppleDenied =>
      'Akses Apple Music ditolak. Hidupkan di Tetapan iPhone > FGMaps > Media & Apple Music.';

  @override
  String get musicAppleNeedsSubscription =>
      'Lagu penuh perlukan langganan Apple Music yang aktif. Langgan dalam app Apple Music, kemudian buka semula tab ini.';

  @override
  String get musicAppleUnavailable =>
      'Apple Music tidak boleh dimain dengan akaun ini.';

  @override
  String get musicOpenSpotify => 'Spotify';

  @override
  String get musicOpenYoutubeMusic => 'YouTube Music';

  @override
  String get musicExternalHint =>
      'Cari lagu penuh dalam app anda sendiri (FGMaps hanya membuka carian):';

  @override
  String get musicExternalFailed => 'Tidak dapat membuka app atau pelayar itu.';

  @override
  String get musicSourceDevice => 'Muzik telefon';

  @override
  String get musicViaDevice => 'pada telefon ini';

  @override
  String get musicDeviceTitle => 'Muzik pada telefon';

  @override
  String get musicDeviceBody =>
      'Mainkan lagu yang sudah ada pada telefon anda. FGMaps hanya membaca tajuk dan artis pada peranti; tiada apa-apa dihantar ke mana-mana.';

  @override
  String get musicDeviceAllow => 'Benarkan akses muzik';

  @override
  String get musicDeviceDenied =>
      'Akses muzik ditolak. Hidupkan untuk FGMaps dalam Tetapan telefon anda.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plaza',
      one: '1 plaza',
    );
    return '$_temp0';
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
      'Anggaran untuk kereta (kelas 1) daripada kadar rasmi; semak harga di plaza.';

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
      'Data peta © penyumbang OpenStreetMap (ODbL). Gaya dan jubin: OpenFreeMap, OpenMapTiles. Laluan: Valhalla. Carian: Photon (komoot) dan Nominatim. Harga petrol: data.gov.my. Waktu solat: JAKIM e-Solat melalui WaktuSolat API (api.waktusolat.app), dan pengiraan Adhan. Muzik: Audius (Open Music License), Radio Browser, dan Apple Music di iPhone (pelanggan, melalui MusicKit Apple); strim radio daripada stesen masing-masing. Rakaman azan: Aaqib Azeez / Atcovi, Wikimedia Commons, CC BY-SA 4.0.';

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

  @override
  String azanEnabledSnack(String source) {
    return 'Azan dihidupkan. $source';
  }

  @override
  String azanSourceOfficial(String zone) {
    return 'Waktu rasmi JAKIM e-Solat, zon $zone';
  }

  @override
  String azanSourceCalculated(String method) {
    return 'Dikira pada telefon ($method)';
  }

  @override
  String get azanDeniedTitle => 'Notifikasi dimatikan';

  @override
  String get azanDeniedBody =>
      'Tanpa kebenaran notifikasi, azan tidak boleh berbunyi apabila app ditutup. Buka tetapan dan benarkan notifikasi untuk FGMaps.';

  @override
  String get azanOpenAppSettings => 'Buka tetapan';

  @override
  String get azanExactDialogTitle => 'Benarkan penggera tepat';

  @override
  String get azanExactDialogBody =>
      'Supaya azan berbunyi tepat pada waktunya dan bukan lewat beberapa minit, benarkan “Penggera & peringatan” untuk FGMaps pada skrin seterusnya.';

  @override
  String get azanNotificationsOffTitle => 'Notifikasi azan dimatikan';

  @override
  String get azanNotificationsOffBody =>
      'Azan tidak akan berbunyi apabila app ditutup sehingga anda membenarkan notifikasi semula.';

  @override
  String get azanBatteryTitle => 'Pastikan azan berbunyi apabila app ditutup';

  @override
  String get azanBatteryBody =>
      'Sesetengah telefon menghentikan app di latar belakang. Jika azan tidak berbunyi, benarkan FGMaps berjalan di latar belakang.';

  @override
  String get azanBatteryAction => 'Benarkan di latar belakang';

  @override
  String get azanBatteryList => 'Buka senarai bateri';

  @override
  String get azanBatteryListHint =>
      'Atau buka senarai bateri: tukar penapis atas daripada “Not optimized” kepada “All apps”, kemudian pilih FGMaps dan “Don’t optimize”.';

  @override
  String get azanLocationUnknown =>
      'Lokasi belum diketahui. Waktu dikira untuk Kuala Lumpur. Benarkan lokasi atau pilih bandar di bawah.';

  @override
  String get azanUseOfficial => 'Waktu rasmi JAKIM';

  @override
  String get azanUseOfficialHint =>
      'Ambil jadual e-Solat rasmi melalui internet (hanya lokasi ~1 km dihantar). Tanpa talian, waktu dikira pada telefon.';

  @override
  String get onbAzan => 'Ingatkan waktu azan';

  @override
  String get onbAzanHint =>
      'Notifikasi dan azan pada setiap waktu solat, walaupun app ditutup. Kami akan minta kebenaran notifikasi.';

  @override
  String get musicRegionMalaysia => 'Malaysia';

  @override
  String get musicRegionIndonesia => 'Indonesia';

  @override
  String get musicRegionFavorites => 'Kegemaran';

  @override
  String get musicEmptyFavorites =>
      'Belum ada stesen kegemaran. Ketik bintang pada mana-mana stesen untuk simpan di sini.';

  @override
  String get musicFavoriteAdd => 'Tambah ke kegemaran';

  @override
  String get musicFavoriteRemove => 'Buang daripada kegemaran';

  @override
  String get musicRadioUnreachable => 'Gagal disambung tadi';

  @override
  String get musicRegionJapan => 'Japan';

  @override
  String get musicRegionJpop => 'J-pop';

  @override
  String get musicRegionKorea => 'Korea';

  @override
  String get musicRegionKpop => 'K-pop';

  @override
  String get musicNoResultsSongsHint =>
      'Katalog percuma Audius ialah muzik bebas; lagu artis label besar tiada di sini. Ketik Spotify atau YouTube Music di atas untuk cari dalam app anda sendiri, atau cuba Radio.';

  @override
  String get musicTryRadio => 'Cari dalam Radio';

  @override
  String aboutWhatsNewTitle(String version) {
    return 'Baharu dalam versi $version';
  }

  @override
  String get aboutNew1 =>
      'Senarai masjid & surau Malaysia (JAKIM): cari, tapis ikut negeri dan daerah, kemudian Arah atau Pergi terus';

  @override
  String get aboutNew2 =>
      'Cari di Google dalam app: tekan \"Arah\" atau \"Buka dalam Peta\" dan FGMaps terus kira laluan ke lokasi tepat Google, tanpa carian semula';

  @override
  String get aboutNew3 =>
      'Jenis peta Satelit (seperti Google Maps) dengan jalan, nama tempat dan laluan di atasnya';

  @override
  String get aboutNew4 =>
      'Logo baharu FGMaps dengan animasi pembuka, dan gambar simpang sebenar ketika hendak belok';

  @override
  String get aboutNew5 =>
      'FG AI boleh buka senarai masjid untuk anda: cuba \"senarai masjid Selangor\"';

  @override
  String get aboutNew6 =>
      'Anggaran tol lebih jelas dan lengkap (termasuk SPE, Besraya dan NPE); muzik terus dimainkan di latar';

  @override
  String get alongRouteTitle => 'Sepanjang laluan';

  @override
  String get alongRouteDisclaimer => 'Data OpenStreetMap; mungkin tak lengkap.';

  @override
  String get alongRouteUnavailable =>
      'Tidak dapat memuatkan tempat sepanjang laluan. Cuba lagi kemudian.';

  @override
  String get alongRouteEmpty =>
      'Tiada tempat dijumpai sepanjang laluan untuk kategori ini.';

  @override
  String alongRouteIn(String distance) {
    return 'Dalam $distance';
  }

  @override
  String get alongRouteRr => 'R&R';

  @override
  String get alongRouteFuel => 'Minyak';

  @override
  String get alongRouteMosque => 'Surau';

  @override
  String get alongRouteToilets => 'Tandas';

  @override
  String get alongRouteAddStop => 'Tambah sebagai perhentian';

  @override
  String get alongRouteAddedStop =>
      'Ditambah sebagai perhentian — mengira semula laluan';

  @override
  String get tripHistoryExport => 'Eksport JSON';

  @override
  String get tripHistoryExported => 'Sejarah perjalanan disalin';

  @override
  String tripHistoryRetentionDays(int days) {
    return '$days hari';
  }

  @override
  String get tripHistoryRetentionForever => 'Selamanya';

  @override
  String get tripHistoryRetentionOff => 'Mati';

  @override
  String get pickingStopHint => 'Pilih perhentian, kemudian pilih destinasi';

  @override
  String get cameraAwasAhead => 'Kamera AwAS di hadapan — patuhi had laju';

  @override
  String get cameraOsmAhead => 'Kamera (OSM) di hadapan — patuhi had laju';

  @override
  String get settingsCameras => 'Amaran kamera';

  @override
  String get settingsCamerasHint =>
      'Amaran AwAS rasmi (JPJ). Bukan semua kamera Malaysia.';

  @override
  String get settingsCamerasOsm => 'Termasuk kamera OSM';

  @override
  String get settingsCamerasOsmHint =>
      'Data komuniti; mungkin tak lengkap atau usang.';

  @override
  String get settingsCamerasDistance => 'Jarak amaran';

  @override
  String get addStop => 'Tambah perhentian';

  @override
  String get stopsTitle => 'Perhentian';

  @override
  String get removeStop => 'Buang perhentian';

  @override
  String get nextStop => 'Perhentian seterusnya';

  @override
  String get skipStop => 'Langkau perhentian';

  @override
  String get tripHistoryTitle => 'Perjalanan';

  @override
  String get tripHistoryEmpty => 'Belum ada perjalanan tersimpan.';

  @override
  String get tripHistoryMonth => 'Bulan ini';

  @override
  String tripHistoryKm(String km) {
    return '$km km';
  }

  @override
  String tripHistoryDuration(int hours, int mins) {
    return '$hours j $mins min';
  }

  @override
  String tripHistoryToll(String amount) {
    return 'Tol ~RM $amount';
  }

  @override
  String tripHistoryTrips(int count) {
    return '$count perjalanan';
  }

  @override
  String get tripHistoryRetention => 'Simpan sejarah';

  @override
  String get tripHistoryDeleteAll => 'Padam semua perjalanan';

  @override
  String get weatherTitle => 'Cuaca';

  @override
  String get weatherAttribution => 'Cuaca: Open-Meteo · lokasi GPS';

  @override
  String get weatherUnavailable => 'Cuaca tidak tersedia';

  @override
  String get weatherRainAlong => 'Hujan dijangka sepanjang laluan';

  @override
  String get weatherSevere => 'Cuaca buruk dijangka — pandu berhati-hati';

  @override
  String get weatherHere => 'Di sini';

  @override
  String get weatherAtDestination => 'Destinasi';

  @override
  String get weatherFeelsLike => 'Rasa';

  @override
  String get weatherCached => 'Cache';

  @override
  String get settingsWeather => 'Amaran cuaca';

  @override
  String get settingsWeatherHint => 'Banner hujan lebat semasa navigasi';

  @override
  String get settingsAlongRouteAnnounce => 'Umumkan R&R / minyak';

  @override
  String get settingsAlongRouteAnnounceHint =>
      'Suara bila R&R atau stesen minyak di hadapan (chip tetap dipaparkan)';

  @override
  String get airQualityTitle => 'Kualiti udara (IPU)';

  @override
  String get airQualityOpen => 'Kualiti udara';

  @override
  String get airQualityDisclaimer =>
      'Indeks Pencemar Udara rasmi daripada stesen pemantauan JAS yang terdekat.';

  @override
  String get airQualityHere => 'Di sini';

  @override
  String get airQualitySearchHint => 'Cari tempat lain';

  @override
  String get airQualityUnavailable =>
      'IPU tidak tersedia. Semak sambungan, kemudian cuba lagi.';

  @override
  String get airQualityCached => 'Cache';

  @override
  String get airQualityAttribution =>
      'Sumber: Jabatan Alam Sekitar (APIMS/EQMS)';

  @override
  String airQualityStation(String name, String distance) {
    return 'Stesen: $name · $distance';
  }

  @override
  String airQualityRouteAlert(String name, int ipu) {
    return 'IPU tinggi sepanjang laluan — $name · $ipu';
  }

  @override
  String get airBandGood => 'Baik';

  @override
  String get airBandModerate => 'Sederhana';

  @override
  String get airBandUnhealthy => 'Tidak sihat';

  @override
  String get airBandVeryUnhealthy => 'Sangat tidak sihat';

  @override
  String get airBandHazardous => 'Berbahaya';

  @override
  String get airQualityScale => 'Skala rasmi JAS';

  @override
  String airQualityDominant(String name) {
    return 'Pencemar dominan: $name';
  }

  @override
  String airQualityObserved(String time) {
    return 'Bacaan $time';
  }

  @override
  String get airPollutantPm25 => 'PM2.5';

  @override
  String get airPollutantPm10 => 'PM10';

  @override
  String get airPollutantSo2 => 'SO₂';

  @override
  String get airPollutantNo2 => 'NO₂';

  @override
  String get airPollutantO3 => 'Ozon';

  @override
  String get airPollutantCo => 'CO';

  @override
  String get airPollutantSeveral => 'Lebih daripada satu';

  @override
  String get airAdviceGood =>
      'Sesuai untuk aktiviti luar. Tiada kesan kesihatan.';

  @override
  String get airAdviceModerate => 'Sesuai untuk aktiviti luar.';

  @override
  String get airAdviceUnhealthy =>
      'Kurangkan aktiviti luar yang lama. Kumpulan sensitif mungkin terjejas.';

  @override
  String get airAdviceVeryUnhealthy =>
      'Elakkan aktiviti luar. Semua orang mungkin terjejas.';

  @override
  String get airAdviceHazardous =>
      'Kecemasan kesihatan. Tinggal di dalam bangunan.';

  @override
  String get alongRouteEv => 'Pengecas EV';

  @override
  String get qiblaTitle => 'Kiblat';

  @override
  String get assistantOpen => 'Pembantu';

  @override
  String get assistantTitle => 'FG AI';

  @override
  String get assistantHint =>
      'Sembang umum dalam telefon serta alat peta (tempat, IPU, cuaca, laluan). Model dimuat turun sekali dan kekal di peranti.';

  @override
  String get assistantInputHint => 'Tanya apa-apa atau beri arahan…';

  @override
  String get assistantClearChat => 'Padam sembang';

  @override
  String get assistantDownloadTitle => 'Muat turun model tempatan';

  @override
  String get assistantDownloadBody =>
      'Qwen3 0.6B (~345 MB). Berjalan pada telefon; tiada kunci cloud. Wi‑Fi digalakkan.';

  @override
  String get assistantDownloadAction => 'Muat turun';

  @override
  String assistantDownloading(int percent) {
    return 'Memuat turun… $percent%';
  }

  @override
  String get assistantSettingsTitle => 'FG AI';

  @override
  String get assistantSettingsReady => 'Model sedia pada telefon ini.';

  @override
  String get assistantSettingsMissing =>
      'Belum dimuat turun. Pilihan; tanpa model, ciri lain kekal berfungsi.';

  @override
  String get assistantDeleteModel => 'Padam model';

  @override
  String get assistantModeFgmaps => 'FG AI';

  @override
  String get assistantModeMuslim => 'FGMuslim';

  @override
  String get assistantEmptyTitle =>
      'Tanya apa-apa — peta, cuaca, atau soalan umum';

  @override
  String get assistantSuggestRoute => 'Laluan ke KLCC';

  @override
  String get assistantSuggestIpu => 'IPU berhampiran';

  @override
  String get assistantSuggestGeneral => 'Jelaskan tol di MY';

  @override
  String get muslimAiTitle => 'FGMuslim AI';

  @override
  String get muslimAiHint =>
      'Jawapan berpetikan teks klasik (islamic.app) serta pautan fatwa (deen.ai). Bukan nasihat JAKIM. Wallahu a\'lam.';

  @override
  String get muslimAiInputHint => 'Tanya tentang Quran, hadis, atau fiqh…';

  @override
  String get muslimAiGateTitle => 'Untuk Muslim yang memilih untuk aktifkan';

  @override
  String get muslimAiGateBody =>
      'FGMuslim AI guna sumber pihak ketiga berpetikan. Setuju syarat dulu — ini bukan autoriti agama rasmi.';

  @override
  String get muslimAiEnableAction => 'Baca syarat & aktifkan';

  @override
  String get muslimAiEmptyTitle => 'Tanya dengan petikan — teks klasik dahulu';

  @override
  String get muslimAiSuggestZakat => 'Apa kata Islam tentang zakat?';

  @override
  String get muslimAiSuggestSolat => 'Apa itu sabar (sabr) dalam Islam?';

  @override
  String get muslimAiSuggestRiba => 'Apa itu riba?';

  @override
  String get muslimAiSettingsTitle => 'FGMuslim AI';

  @override
  String get muslimAiSettingsOn =>
      'Hidup — petikan islamic.app + deen.ai (opt-in).';

  @override
  String get muslimAiSettingsOff =>
      'Mati. Pilihan; untuk pengguna Muslim selepas bersetuju syarat.';

  @override
  String get muslimAiTermsTitle => 'Syarat FGMuslim AI';

  @override
  String get muslimAiTermsLead =>
      'Sila baca teliti. Topik agama di Malaysia sensitif. Tandakan setiap kotak untuk teruskan.';

  @override
  String get muslimAiTermsMuslim =>
      'Saya Muslim (atau mencari rujukan Islam untuk pembelajaran peribadi) dan memilih untuk mengaktifkan ciri pilihan ini.';

  @override
  String get muslimAiTermsNotOfficial =>
      'Saya faham FGMuslim AI BUKAN fatwa rasmi JAKIM, pejabat mufti negeri, atau FGMaps.';

  @override
  String get muslimAiTermsNotAdvice =>
      'Saya tidak akan anggap jawapan sebagai nasihat agama, undang-undang, atau perubatan peribadi. Untuk situasi saya, saya akan rujuk ulama yang berkelayakan.';

  @override
  String get muslimAiTermsThirdParty =>
      'Saya faham soalan dihantar ke islamic.app dan deen.ai (pihak ketiga). Jawapan mungkin tidak lengkap, berat sebelah, atau silap; saya akan semak petikan.';

  @override
  String get muslimAiTermsHoldHarmless =>
      'Saya bersetuju FGMaps dan penulisnya tidak bertanggungjawab atas cara saya guna atau tafsir kandungan ini.';

  @override
  String get muslimAiTermsAgree => 'Saya setuju — aktifkan FGMuslim AI';

  @override
  String get muslimAiTermsCancel => 'Batal';

  @override
  String get muslimAiOpenDeen => 'Buka islamic.app';

  @override
  String get qiblaOpen => 'Kiblat';

  @override
  String qiblaDegrees(String degrees) {
    return '$degrees° dari utara';
  }

  @override
  String get qiblaHint => 'Halakan bahagian atas telefon ke ikon Kaabah.';

  @override
  String get qiblaFacing => 'Tepat ke arah kiblat';

  @override
  String qiblaTurnRight(String degrees) {
    return 'Pusing ke kanan $degrees°';
  }

  @override
  String qiblaTurnLeft(String degrees) {
    return 'Pusing ke kiri $degrees°';
  }

  @override
  String get qiblaWaitingSensor => 'Menyediakan kompas…';

  @override
  String get qiblaLocating => 'Mencari lokasi anda…';

  @override
  String get qiblaNoSensor =>
      'Tiada sensor kompas pada telefon ini. Dail hanya mengikut arah perjalanan apabila anda bergerak.';

  @override
  String get qiblaDirectionLabel => 'Arah kiblat';

  @override
  String get qiblaDistanceLabel => 'Jarak ke Kaabah';

  @override
  String qiblaDistanceValue(String km) {
    return '$km km';
  }

  @override
  String get qiblaSensorLabel => 'Ketepatan sensor';

  @override
  String get qiblaAccuracyHigh => 'Tinggi';

  @override
  String get qiblaAccuracyMedium => 'Sederhana';

  @override
  String get qiblaAccuracyLow => 'Rendah';

  @override
  String get qiblaAccuracyUnreliable => 'Perlu kalibrasi';

  @override
  String get qiblaCalibrateTitle => 'Kalibrasi kompas';

  @override
  String get qiblaCalibrateBody =>
      'Gerakkan telefon dalam bentuk angka 8 beberapa kali. Jauhkan daripada magnet, sarung bermagnet dan logam.';

  @override
  String get qiblaFlatTip =>
      'Pegang telefon mendatar dan stabil untuk bacaan paling tepat.';

  @override
  String get qiblaNorthTrue => 'Utara benar (deklinasi magnet dikira)';

  @override
  String get qiblaNorthMagnetic => 'Utara magnet (menunggu lokasi)';

  @override
  String get qiblaCardinals => 'U,T,S,B';

  @override
  String get qiblaKaaba => 'Kaabah';

  @override
  String qiblaSemantics(String heading, String qibla, String guidance) {
    return 'Kompas kiblat. Arah telefon $heading darjah, kiblat $qibla darjah. $guidance';
  }

  @override
  String get qiblaUnavailable => 'Perlukan GPS untuk arah kiblat.';

  @override
  String aiRouteReady(String place, String summary) {
    return 'Laluan ke $place sedia: $summary.';
  }

  @override
  String aiTollAmount(String amount) {
    return 'tol $amount';
  }

  @override
  String aiTollAmountPlus(String amount) {
    return 'tol $amount+';
  }

  @override
  String get aiTollNone => 'tiada tol';

  @override
  String get aiTollUnknown => 'ada tol';

  @override
  String get aiReasonRecommended =>
      'Ini pilihan disyorkan: seimbang antara masa, belokan dan kualiti jalan.';

  @override
  String get aiReasonFastest => 'Ini pilihan paling cepat.';

  @override
  String get aiReasonShortest => 'Ini jarak paling pendek.';

  @override
  String get aiReasonTollFree => 'Pilihan ini mengelak semua tol.';

  @override
  String get aiReasonFewestTolls =>
      'Semua pilihan ada tol, jadi saya pilih yang paling sedikit jalan bertol.';

  @override
  String get aiReasonNoHighways =>
      'Pilihan ini guna jalan biasa sebanyak mungkin.';

  @override
  String get aiReasonCheapest =>
      'Ini paling murah secara keseluruhan (tol dan anggaran minyak).';

  @override
  String get aiReasonSafest =>
      'Saya pilih yang paling selamat: kebanyakannya jalan utama, kurang belokan dan pusingan-U, tiada feri. Ini berdasarkan jenis jalan, bukan data kemalangan.';

  @override
  String get aiOtherOptions => 'Pilihan lain:';

  @override
  String get aiNavStarting => 'Navigasi dimulakan sekarang. Pandu cermat.';

  @override
  String get aiNoRouteToStart =>
      'Belum ada laluan. Beritahu saya destinasi, contohnya \"Laluan ke KLCC\".';

  @override
  String aiPlaceNotFound(String place) {
    return 'Saya tak jumpa \"$place\". Cuba nama yang lebih spesifik.';
  }

  @override
  String get aiRouteFailed =>
      'Laluan tidak dapat dikira sekarang. Sila cuba lagi sebentar lagi.';

  @override
  String get aiBusy =>
      'Perkhidmatan carian dan laluan sedang sibuk. Cuba lagi sebentar lagi.';

  @override
  String get aiServiceDown =>
      'Perkhidmatan dalam talian tidak menjawab sekarang. Cuba lagi sebentar, atau muat turun pek peta offline supaya saya boleh rancang laluan tanpanya.';

  @override
  String get aiSlow =>
      'Sambungan anda nampak perlahan atau tidak stabil, jadi saya tak dapat siapkan. Sila cuba lagi.';

  @override
  String aiOfflineNotFound(String place) {
    return 'Anda sedang luar talian, jadi saya hanya boleh cari \"$place\" dalam peta offline dan tiada padanan. Carian offline perlukan pek peta Malaysia (Peta offline). Cuba ejaan lain, atau sambung ke internet.';
  }

  @override
  String get aiOfflinePackNeeded =>
      'Anda luar talian dan pek peta offline belum dipasang, jadi saya tak dapat rancang laluan itu. Muat turun pek Malaysia dalam Peta offline semasa ada internet.';

  @override
  String get aiOfflineEngine =>
      'Enjin laluan offline tak dapat mengira laluan itu. Cuba lagi, atau muat turun semula pek peta offline.';

  @override
  String aiNoDrivableRoute(String place) {
    return 'Saya jumpa $place, tetapi tiada laluan boleh dipandu ke sana dari lokasi anda. Semak sama ada itu tempat yang betul.';
  }

  @override
  String get aiSearchFailed =>
      'Saya tak dapat cari tempat itu sekarang. Sila cuba lagi.';

  @override
  String get aiAskDestination =>
      'Anda nak ke mana? Cakap contohnya \"Bawa saya ke KLCC\" atau \"Navigate to Masjid Negara\".';

  @override
  String get aiRouteReadyHint =>
      'Laluan sudah ada pada peta. Cakap \"start now\" atau tekan Mula untuk mula memandu.';

  @override
  String get aiNotUnderstood =>
      'Saya kurang faham. Saya boleh rancang laluan (\"Laluan ke KLCC\"), cari tempat berdekatan, beritahu lokasi anda, serta kiblat dan waktu solat. Cuba salah satu.';

  @override
  String get aiNoLocation =>
      'Saya perlukan lokasi anda untuk ini. Hidupkan lokasi dan cuba lagi.';

  @override
  String get aiOfflineTool =>
      'Itu perlukan internet dan anda sedang luar talian. Saya masih boleh beri lokasi GPS, kiblat, waktu solat dan laluan jika anda sudah muat turun pek peta offline. Cuba lagi bila online.';

  @override
  String get aiRouteCleared => 'Laluan dipadam.';

  @override
  String aiNearbyTitle(String category) {
    return '$category terdekat:';
  }

  @override
  String get aiNearbyAroundYou => 'Tempat berdekatan sekitar anda:';

  @override
  String get aiNothingFound => 'Tiada apa-apa dijumpai berdekatan sekarang.';

  @override
  String aiSearchTitle(String query) {
    return 'Ini yang saya jumpa untuk \"$query\":';
  }

  @override
  String aiCurrentLocation(String place, String lat, String lng) {
    return 'Anda di sini: $place. Koordinat: $lat, $lng.';
  }

  @override
  String aiCurrentLocationCoords(String lat, String lng) {
    return 'Kedudukan GPS anda ialah $lat, $lng. Nama tempat tidak dapat diselesaikan sekarang.';
  }

  @override
  String get aiCapabilities =>
      'Anda boleh minta saya rancang laluan, mula navigasi, cari minyak/masjid/makan berdekatan, cuaca atau IPU, kiblat, waktu solat, tempat sepanjang laluan, atau main muzik/radio. Arahan peta berfungsi tanpa model pada telefon.';

  @override
  String get aiCapabilitiesOffline =>
      'Ciri pada telefon (luar talian): rancang laluan jika peta offline sudah dimuat turun, arah kiblat, dan waktu solat hari ini. Carian tempat, cuaca, IPU, muzik dan Wikipedia perlukan internet. Arahan seperti \"Laluan ke KLCC\" atau \"Di mana saya\" tidak akan memaparkan senarai alat.';

  @override
  String aiWeatherNow(
    String place,
    String condition,
    String temp,
    String feels,
  ) {
    return '$place: $condition, $temp°C (terasa $feels°C).';
  }

  @override
  String aiWeatherDetails(String rain, String humidity, String wind) {
    return 'Peluang hujan $rain%, kelembapan $humidity%, angin $wind km/j.';
  }

  @override
  String get aiHere => 'Di sini';

  @override
  String aiAirLine(String station, String ipu, String band) {
    return 'Kualiti udara berhampiran $station: IPU $ipu, $band.';
  }

  @override
  String aiQiblaLine(String bearing, String distance) {
    return 'Arah kiblat dari lokasi anda ialah $bearing° dari utara benar, $distance km ke Kaabah. Buka kompas Kiblat untuk arah secara langsung.';
  }

  @override
  String aiPrayerTitle(String zone) {
    return 'Waktu solat hari ini ($zone):';
  }

  @override
  String get aiPrayerTitleLocal => 'Waktu solat hari ini:';

  @override
  String aiPrayerNext(String prayer, String time) {
    return 'Seterusnya: $prayer pada $time.';
  }

  @override
  String get aiUnavailable =>
      'Maklumat itu tiada buat masa ini. Cuba lagi sebentar.';

  @override
  String aiAlongTitle(String category) {
    return '$category sepanjang laluan:';
  }

  @override
  String aiAlongIn(String distance) {
    return 'dalam $distance';
  }

  @override
  String get aiNeedRoute =>
      'Rancang laluan dahulu, kemudian saya boleh cari sepanjang laluan.';

  @override
  String aiPlaying(String title) {
    return 'Memainkan $title.';
  }

  @override
  String get aiNeedModel =>
      'Arahan peta boleh digunakan terus (laluan, tempat berdekatan, cuaca, kiblat). Untuk soalan umum, muat turun model pada telefon dahulu.';

  @override
  String get aiError => 'Maaf, ada masalah. Sila cuba lagi.';

  @override
  String get aiPreparing => 'Menyediakan model…';

  @override
  String get aiThinking => 'Sedang berfikir…';

  @override
  String get aiWorking => 'Sedang diproses…';

  @override
  String get aiSearchingSources => 'Mencari dalam teks klasik…';

  @override
  String get aiActionStart => 'Mula navigasi';

  @override
  String get aiActionShowRoute => 'Lihat di peta';

  @override
  String aiActionRouteTo(String place) {
    return 'Laluan ke $place';
  }

  @override
  String get aiNewChat => 'Sembang baharu';

  @override
  String get aiChats => 'Sembang';

  @override
  String get aiRename => 'Namakan semula';

  @override
  String get aiRenameTitle => 'Namakan semula sembang';

  @override
  String get aiDelete => 'Padam';

  @override
  String get aiDeleteAll => 'Padam semua sembang';

  @override
  String aiDeleteAllConfirm(String name) {
    return 'Padam semua sembang dalam $name? Tindakan ini tidak boleh dibuat asal.';
  }

  @override
  String get aiDeleted => 'Sembang dipadam';

  @override
  String get aiUndo => 'Buat asal';

  @override
  String get aiSave => 'Simpan';

  @override
  String get aiCancel => 'Batal';

  @override
  String get aiToday => 'Hari ini';

  @override
  String get aiPrevious7Days => '7 hari lalu';

  @override
  String get aiOlder => 'Lebih lama';

  @override
  String get aiNoChats => 'Belum ada sembang. Mulakan di bawah.';

  @override
  String get aiCopy => 'Salin';

  @override
  String get aiCopied => 'Disalin';

  @override
  String get aiStop => 'Henti';

  @override
  String get muslimNoticeSummary =>
      'Ringkasan daripada teks klasik (islamic.app). Bukan fatwa rasmi JAKIM atau mufti negeri; semak petikan dan rujuk ulama untuk keputusan peribadi. Wallahu a\'lam.';

  @override
  String get muslimNoticeRateLimited =>
      'islamic.app sibuk sekarang (had permintaan). Cuba lagi sebentar. Pautan fatwa berkaitan di bawah jika ada.';

  @override
  String get muslimNoticeNotGrounded =>
      'Tiada petikan klasik yang cukup hampir untuk soalan ini. Sila rujuk ulama. Wallahu a\'lam.';

  @override
  String get muslimNoticeUnreachable =>
      'Sumber rujukan tidak dapat dicapai sekarang. Cuba lagi, atau rujuk pejabat mufti tempatan. Wallahu a\'lam.';

  @override
  String muslimSources(int count) {
    return 'Sumber ($count)';
  }

  @override
  String get muslimClassical => 'Teks klasik';

  @override
  String get muslimFatwa =>
      'Fatwa berkaitan (indeks deen.ai, bukan rasmi di Malaysia)';

  @override
  String muslimPage(String page) {
    return 'hlm. $page';
  }

  @override
  String get assistantSuggestFuel => 'Stesen minyak terdekat';

  @override
  String get assistantSuggestWeather => 'Cuaca di Kuala Terengganu';

  @override
  String get routeTollShort => 'Tol';

  @override
  String get qiblaCalibrateAction => 'Kalibrasi';

  @override
  String get qiblaCalibrateSteps =>
      'Pegang telefon dan lukis angka 8 yang besar di udara tiga kali sambil memusingkan pergelangan tangan. Jauhkan daripada logam dan magnet.';

  @override
  String get qiblaCalibrateDone => 'Kompas sudah dikalibrasi';

  @override
  String qiblaCalibrateProgress(String deg) {
    return 'Teruskan… ketepatan ±$deg°';
  }

  @override
  String qiblaCalibrateProgressLevel(String level) {
    return 'Teruskan… ketepatan: $level';
  }

  @override
  String get qiblaInterferenceTitle => 'Gangguan magnet';

  @override
  String get qiblaInterferenceBody =>
      'Medan magnet di sekitar telefon luar biasa. Jauhkan daripada logam, magnet, kereta, pembesar suara dan sarung telefon bermagnet, kemudian kalibrasi semula.';

  @override
  String qiblaAccuracyDegrees(String deg) {
    return '±$deg°';
  }

  @override
  String get qiblaDone => 'Selesai';

  @override
  String get qiblaNotAccurateYet => 'Kalibrasi untuk arah yang tepat';

  @override
  String get weatherCurrentLocation => 'Lokasi saya';

  @override
  String weatherHighLow(String high, String low) {
    return 'T:$high°  R:$low°';
  }

  @override
  String weatherFeelsLikeValue(String temp) {
    return 'Terasa $temp°';
  }

  @override
  String get weatherHourly => 'Ramalan setiap jam';

  @override
  String get weatherDaily => 'Ramalan 10 hari';

  @override
  String get weatherNow => 'Kini';

  @override
  String get weatherToday => 'Hari ini';

  @override
  String get weatherHumidity => 'Kelembapan';

  @override
  String get weatherWind => 'Angin';

  @override
  String get weatherUv => 'Indeks UV';

  @override
  String get weatherUvLow => 'Rendah';

  @override
  String get weatherUvModerate => 'Sederhana';

  @override
  String get weatherUvHigh => 'Tinggi';

  @override
  String get weatherUvVeryHigh => 'Sangat tinggi';

  @override
  String get weatherUvExtreme => 'Melampau';

  @override
  String get weatherSunrise => 'Matahari terbit';

  @override
  String get weatherSunset => 'Matahari terbenam';

  @override
  String get weatherPressure => 'Tekanan';

  @override
  String get weatherVisibility => 'Jarak penglihatan';

  @override
  String get weatherRainToday => 'Hujan hari ini';

  @override
  String get weatherRainChance => 'Peluang hujan';

  @override
  String weatherUpdated(String time) {
    return 'Dikemas kini $time';
  }

  @override
  String weatherOfflineStale(String time) {
    return 'Luar talian · dikemas kini $time';
  }

  @override
  String get weatherSearchHint => 'Cari bandar atau tempat';

  @override
  String get weatherAddPlace => 'Tambah tempat';

  @override
  String get weatherRemovePlace => 'Buang tempat';

  @override
  String get weatherSevereSoon =>
      'Ribut petir atau hujan lebat dijangka dalam 24 jam akan datang.';

  @override
  String get weatherLoadFailed =>
      'Ramalan tidak dapat dimuat. Semak sambungan dan cuba lagi.';

  @override
  String get weatherNoLocation =>
      'Hidupkan lokasi untuk melihat cuaca di tempat anda, atau cari tempat.';

  @override
  String weatherSpeedKmh(String value) {
    return '$value km/j';
  }

  @override
  String weatherMm(String value) {
    return '$value mm';
  }

  @override
  String weatherHpa(String value) {
    return '$value hPa';
  }

  @override
  String weatherKm(String value) {
    return '$value km';
  }

  @override
  String get weatherCardinals => 'U,TL,T,TG,S,BD,B,BL';

  @override
  String weatherFrom(String dir) {
    return 'dari $dir';
  }

  @override
  String get weatherCodeClear => 'Cerah';

  @override
  String get weatherCodeMainlyClear => 'Kebanyakannya cerah';

  @override
  String get weatherCodePartlyCloudy => 'Sebahagian berawan';

  @override
  String get weatherCodeOvercast => 'Mendung';

  @override
  String get weatherCodeFog => 'Berkabus';

  @override
  String get weatherCodeDrizzle => 'Gerimis';

  @override
  String get weatherCodeRain => 'Hujan';

  @override
  String get weatherCodeHeavyRain => 'Hujan lebat';

  @override
  String get weatherCodeShowers => 'Hujan renyai';

  @override
  String get weatherCodeHeavyShowers => 'Hujan renyai lebat';

  @override
  String get weatherCodeThunderstorm => 'Ribut petir';

  @override
  String get weatherCodeSnow => 'Salji';

  @override
  String get mapToolsMore => 'Alat lain';

  @override
  String get weatherOpen => 'Cuaca';

  @override
  String offlineMapsSearchAvailable(String size) {
    return 'Carian offline tersedia (+$size)';
  }

  @override
  String offlineMapsMapAvailable(String size) {
    return 'Paparan peta offline tersedia (+$size)';
  }

  @override
  String offlineMapsMapSearchAvailable(String size) {
    return 'Paparan peta dan carian offline tersedia (+$size)';
  }

  @override
  String get aiIdentity =>
      'Saya FG AI, pembantu pintar dalam FGMaps, dibangunkan oleh Faiz Nasir dari FG Universal Empire. Saya berjalan terus pada telefon anda, jadi banyak perkara boleh dibuat tanpa internet: merancang laluan (dengan peta offline), arah kiblat, waktu solat, dan menjawab soalan umum. Dengan internet, saya juga boleh mencari tempat, menyemak cuaca dan banyak lagi.';

  @override
  String get aiGreeting =>
      'Hai! Saya FG AI. Nak ke mana hari ini, atau ada apa yang boleh saya bantu?';

  @override
  String get aiThanks => 'Sama-sama! Ada apa-apa lagi yang boleh saya bantu?';

  @override
  String get aiPing =>
      'Ya, saya di sini. Tanya apa sahaja, contohnya \"laluan ke Ipoh\", \"cuaca di Kuantan\", \"masjid terdekat\" atau soalan umum.';

  @override
  String get aiWikiSource => 'Sumber: Wikipedia';

  @override
  String get aiModelsTitle => 'Model AI pada telefon';

  @override
  String get aiModelsIntro =>
      'Pilih satu model untuk FG AI. Model yang lebih besar lebih pintar dan lebih fasih, tetapi muat turunnya lebih besar, perlukan lebih RAM dan menjawab lebih perlahan. Hanya model yang digunakan dimuat ke memori; yang lain boleh kekal untuk ditukar bila-bila masa.';

  @override
  String get aiModelsManage => 'Pilih model AI';

  @override
  String get aiModelTierBasic => 'Asas · pantas dan ringan';

  @override
  String get aiModelTierMedium => 'Sederhana · seimbang';

  @override
  String get aiModelTierHigh => 'Tinggi · paling pintar';

  @override
  String aiModelRam(String gb) {
    return 'RAM $gb GB ke atas';
  }

  @override
  String get aiModelInUse => 'Sedang digunakan';

  @override
  String get aiModelDownloaded => 'Dimuat turun';

  @override
  String get aiModelUse => 'Guna';

  @override
  String get aiModelDownload => 'Muat turun';

  @override
  String get aiModelDownloadUse => 'Muat turun & guna';

  @override
  String get aiModelDelete => 'Padam';

  @override
  String aiModelDeleteTitle(String name) {
    return 'Padam $name?';
  }

  @override
  String get aiModelDeleteBody =>
      'Fail model dibuang dari telefon. Anda boleh memuat turunnya semula bila-bila masa.';

  @override
  String aiModelSwitched(String name) {
    return 'FG AI kini menggunakan $name.';
  }

  @override
  String get aiModelBusy => 'Tunggu muat turun semasa selesai dahulu.';

  @override
  String get aiModelDescQwen3 =>
      'Paling ringan dan pantas. Sesuai untuk telefon lama dan soalan ringkas.';

  @override
  String get aiModelDescQwen35Small =>
      'Asas yang lebih baharu: lebih fasih dalam BM dan BI, masih ringan.';

  @override
  String get aiModelDescGemma4E2b =>
      'Seimbang: jawapan jauh lebih bijak dan tepat, sesuai untuk kebanyakan telefon moden.';

  @override
  String get aiModelDescQwen35Big =>
      'Penaakulan kuat untuk soalan sukar, matematik dan penjelasan panjang.';

  @override
  String get aiModelDescGemma4E4b =>
      'Paling pintar dan fasih. Untuk telefon mewah dengan RAM besar.';

  @override
  String assistantDownloadBodyModel(String name, String size) {
    return '$name ($size). Berjalan pada telefon anda; tiada kunci awan. Wi‑Fi disyorkan.';
  }

  @override
  String assistantSettingsModel(String name) {
    return 'Model: $name';
  }

  @override
  String get aiNoTrip =>
      'Belum ada laluan atau navigasi. Beritahu saya destinasi dahulu, contohnya \"bawa saya ke KLCC\".';

  @override
  String aiTripDistanceLeft(String distance) {
    return 'Baki jarak: **$distance**.';
  }

  @override
  String aiTripDistanceTotal(String distance) {
    return 'Jarak ke destinasi: **$distance**.';
  }

  @override
  String aiTripTimeLeft(String duration) {
    return 'Baki masa: kira-kira **$duration**.';
  }

  @override
  String aiTripTimeTotal(String duration) {
    return 'Perjalanan mengambil masa kira-kira **$duration**.';
  }

  @override
  String aiTripArrival(String time, String duration) {
    return 'Anda dijangka tiba pada pukul **$time** (lagi $duration).';
  }

  @override
  String get aiTripTollNone => 'Laluan ini tiada tol.';

  @override
  String aiTripToll(String amount) {
    return 'Anggaran tol laluan ini: **$amount**.';
  }

  @override
  String aiTripTollPartial(String amount) {
    return 'Anggaran tol sekurang-kurangnya **$amount** (ada plaza yang harganya tiada dalam data).';
  }

  @override
  String get aiTripTollPending =>
      'Laluan ini ada tol tetapi anggarannya masih dikira. Tanya lagi sebentar nanti.';

  @override
  String get aiTripTollUnknown =>
      'Laluan ini ada tol tetapi harganya tiada dalam data kami.';

  @override
  String get aiTripTollMotorcycle =>
      'Harga tol motosikal tiada dalam data kami (kebanyakan lebuh raya percuma untuk motosikal, tetapi tidak semua). Saya tidak mahu meneka.';

  @override
  String aiTripFuel(
    String amount,
    String distance,
    String price,
    String liters,
  ) {
    return 'Anggaran kos minyak: **$amount** untuk $distance (RM$price seliter, $liters L/100 km).';
  }

  @override
  String get aiTripFuelNoPrice =>
      'Harga minyak belum diketahui (tiada data dan tiada harga yang anda tetapkan). Tetapkan harga di Tetapan > Minyak.';

  @override
  String aiTripNextTurn(String action, String distance) {
    return 'Seterusnya: **$action** dalam $distance.';
  }

  @override
  String aiTripNextTurnNow(String action) {
    return 'Seterusnya: **$action**.';
  }

  @override
  String get aiTripNoNav =>
      'Navigasi belum bermula, jadi saya tiada arahan seterusnya. Mulakan navigasi dahulu.';

  @override
  String aiTripSpeedLimit(String kmh) {
    return 'Had laju di jalan ini: **$kmh km/j**.';
  }

  @override
  String get aiTripSpeedUnknown => 'Had laju jalan ini tiada dalam data.';

  @override
  String get aiHomeNotSet =>
      'Anda belum menetapkan Rumah. Ketik Rumah pada skrin carian untuk menetapkannya, kemudian minta lagi.';

  @override
  String get aiWorkNotSet =>
      'Anda belum menetapkan Kerja. Ketik Kerja pada skrin carian untuk menetapkannya, kemudian minta lagi.';

  @override
  String get aiVehicleCar => 'Baik, kenderaan ditukar kepada **kereta**.';

  @override
  String get aiVehicleMotorcycle =>
      'Baik, kenderaan ditukar kepada **motosikal**.';

  @override
  String get aiVoiceOn => 'Suara panduan dihidupkan.';

  @override
  String get aiVoiceOff => 'Suara panduan dimatikan.';

  @override
  String get aiThemeDark => 'Baik, mod gelap dihidupkan.';

  @override
  String get aiThemeLight => 'Baik, mod cerah dihidupkan.';

  @override
  String get aiThemeSystem => 'Baik, tema mengikut sistem peranti.';

  @override
  String get aiNavStopped => 'Navigasi dihentikan.';

  @override
  String get aiAck =>
      'Baik. Beritahu saya bila perlu bantuan peta, contohnya \"bawa saya ke KLCC\".';

  @override
  String get aiAskRadio =>
      'Stesen radio mana? Contohnya \"play Era\" atau \"pasang Hitz\".';

  @override
  String get aiAskMusic =>
      'Lagu atau artis apa? Contohnya \"mainkan lagu Siti Nurhaliza\".';

  @override
  String get aiNoMoreResults =>
      'Tiada pilihan lain dalam senarai tadi. Cuba cari dengan nama yang lebih tepat.';

  @override
  String aiGuessedPlace(String query) {
    return 'Saya tidak pasti maksud anda, jadi saya cari \"$query\" sebagai tempat. Ketik salah satu untuk ke sana.';
  }

  @override
  String get searchCatBarber => 'Kedai gunting';

  @override
  String get searchCatPharmacy => 'Farmasi';

  @override
  String get searchCatClinic => 'Klinik';

  @override
  String get searchCatAtm => 'ATM';

  @override
  String get searchCatBank => 'Bank';

  @override
  String get searchCatConvenience => 'Kedai runcit';

  @override
  String get searchCatSupermarket => 'Pasar raya';

  @override
  String get searchCatMall => 'Pusat beli-belah';

  @override
  String get searchCatCarWash => 'Cuci kereta';

  @override
  String get searchCatWorkshop => 'Bengkel kereta';

  @override
  String get searchCatTyres => 'Kedai tayar';

  @override
  String get searchCatLaundry => 'Dobi';

  @override
  String get searchCatHotel => 'Hotel & penginapan';

  @override
  String get searchCatPolice => 'Balai polis';

  @override
  String get searchCatPostOffice => 'Pejabat pos';

  @override
  String get searchCatEvCharging => 'Pengecas EV';

  @override
  String get searchCatTrainStation => 'Stesen LRT / MRT / KTM';

  @override
  String aiDateToday(String date) {
    return 'Hari ini **$date**.';
  }

  @override
  String aiTimeNow(String time) {
    return 'Sekarang pukul **$time**.';
  }

  @override
  String get aiUserIdentity =>
      'Saya tak tahu nama anda. FGMaps tak minta akaun atau maklumat peribadi, jadi anda kekal tanpa nama. Yang saya tahu hanyalah lokasi anda pada peta bila anda benarkan GPS. Nak saya carikan sesuatu berdekatan?';

  @override
  String get aiHowAreYou =>
      'Alhamdulillah baik, terima kasih! Saya sedia membantu anda bergerak. Nak ke mana, atau perlukan apa?';

  @override
  String get aiFarewell =>
      'Selamat jalan! Panggil saya bila-bila masa anda perlukan arah.';

  @override
  String get aiDrowsy =>
      'Mengantuk semasa memandu sangat bahaya. Berhenti di tempat selamat seperti stesen minyak, R&R atau surau, dan rehat sekurang-kurangnya 15 minit sebelum sambung. Mahu saya carikan?';

  @override
  String aiAskNearest(String category) {
    return '$category terdekat';
  }

  @override
  String get aiAskWeather => 'Cuaca sekarang';

  @override
  String get aiAskPrayer => 'Waktu solat';

  @override
  String get aiNoAnswer =>
      'Saya belum pasti jawapan untuk itu. Saya paling mahir tentang peta dan tempat: laluan, minyak, makan, farmasi, kedai gunting, ATM, cuaca, waktu solat dan kiblat. Cuba salah satu:';

  @override
  String get aiPlaceNearest => 'Terdekat';

  @override
  String get aiPlaceGo => 'Pergi';

  @override
  String get aiTryAsking => 'Cuba tanya';

  @override
  String get settingsLiteMode => 'Mod Lite (telefon lemah)';

  @override
  String settingsLiteModeHint(String ram, String state) {
    return 'Telefon ini: RAM $ram GB · $state. Mod Lite mematikan bangunan 3D, kesan kabur dan animasi hiasan, mengurangkan GPS ketika peta terbiar dan menyimpan bateri.';
  }

  @override
  String get settingsLiteAuto => 'Auto';

  @override
  String get settingsLiteOn => 'Hidup';

  @override
  String get settingsLiteOff => 'Mati';

  @override
  String get settingsLiteActive => 'Mod Lite aktif';

  @override
  String get settingsLiteInactive => 'Mod Lite tidak aktif';

  @override
  String settingsLiteModeHintNoRam(String state) {
    return '$state. Mod Lite mematikan bangunan 3D, kesan kabur dan animasi hiasan, mengurangkan GPS ketika peta terbiar dan menyimpan bateri.';
  }

  @override
  String get aiBrowsing => 'Mencari di internet…';

  @override
  String get aiWebSources => 'Sumber web';

  @override
  String aiWebResultsTitle(String query) {
    return 'Maklumat terkini: $query';
  }

  @override
  String aiWebNewsTitle(String query) {
    return 'Berita terkini: $query';
  }

  @override
  String aiWebNothing(String query) {
    return 'Saya tidak jumpa maklumat terkini tentang \"$query\". Cuba perkataan lain atau lebih khusus.';
  }

  @override
  String get aiWebUnreadable =>
      'Saya tidak dapat membaca pautan itu (halaman tidak boleh dicapai, bukan HTTPS, atau tiada teks).';

  @override
  String aiFuelPricesTitle(String date) {
    return 'Harga minyak semasa (berkuat kuasa $date)';
  }

  @override
  String aiAgoMinutes(int n) {
    return '$n min lalu';
  }

  @override
  String aiAgoHours(int n) {
    return '$n j lalu';
  }

  @override
  String get aiSearchWebAsk => 'Cari di internet';

  @override
  String get assistantAutoWebTitle => 'Cari di internet secara automatik';

  @override
  String get assistantAutoWebSubtitle =>
      'FG AI menyemak berita, Wikipedia dan data rasmi bila soalan perlukan maklumat terkini. Permintaan \"cari online\" sentiasa dijalankan.';

  @override
  String get aiModelRecommended => 'Disyorkan untuk telefon ini';

  @override
  String aiModelTooHeavy(String ram) {
    return 'Terlalu berat untuk telefon ini (RAM $ram GB)';
  }

  @override
  String get aiModelTooHeavyTitle => 'Model ini mungkin terlalu berat';

  @override
  String aiModelTooHeavyBody(String name, String ram) {
    return '$name memerlukan lebih RAM daripada telefon ini ($ram GB). Ia mungkin sangat perlahan atau ditutup oleh sistem. Teruskan muat turun?';
  }

  @override
  String get agentStop => 'Henti';

  @override
  String get agentWorking => 'FG AI sedang menggunakan app…';

  @override
  String get agentStepMap => 'Kembali ke peta';

  @override
  String agentStepOpen(String x) {
    return 'Buka $x';
  }

  @override
  String agentStepSearch(String x) {
    return 'Cari \"$x\"';
  }

  @override
  String agentStepType(String x) {
    return 'Taip \"$x\"';
  }

  @override
  String get agentStepPickFirst => 'Pilih hasil teratas';

  @override
  String get agentStepPickNearest => 'Pilih yang terdekat';

  @override
  String get agentStepOpenSearch => 'Buka carian';

  @override
  String agentStepCategory(String x) {
    return 'Tekan $x';
  }

  @override
  String get agentStepRouteReady => 'Tunggu laluan siap';

  @override
  String get agentStepStart => 'Mula navigasi';

  @override
  String get agentStepRecenter => 'Pusatkan peta pada lokasi saya';

  @override
  String get agentReport => 'Laporan jalan';

  @override
  String agentFindTitle(String x) {
    return 'Cari $x';
  }

  @override
  String get agentDone => 'Siap. Ini yang saya lakukan:';

  @override
  String get agentStopped => 'Dihentikan. Setakat ini:';

  @override
  String get agentFailed => 'Saya tidak dapat menyiapkannya. Ini yang berlaku:';
}
