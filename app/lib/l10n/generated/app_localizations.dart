import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms'),
  ];

  /// No description provided for @appName.
  ///
  /// In ms, this message translates to:
  /// **'FGMaps'**
  String get appName;

  /// No description provided for @mapHintLongPress.
  ///
  /// In ms, this message translates to:
  /// **'Tekan lama pada peta untuk pilih destinasi'**
  String get mapHintLongPress;

  /// No description provided for @mapZoomIn.
  ///
  /// In ms, this message translates to:
  /// **'Zum masuk'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In ms, this message translates to:
  /// **'Zum keluar'**
  String get mapZoomOut;

  /// No description provided for @myLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi saya'**
  String get myLocation;

  /// No description provided for @locationFixUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'GPS belum dapat lokasi yang cukup tepat. Pergi ke kawasan terbuka dan cuba lagi.'**
  String get locationFixUnavailable;

  /// No description provided for @locationAccuracy.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran ketepatan lokasi ±{meters} m'**
  String locationAccuracy(int meters);

  /// No description provided for @mapAttribution.
  ///
  /// In ms, this message translates to:
  /// **'© penyumbang OpenStreetMap · © OpenMapTiles · OpenFreeMap'**
  String get mapAttribution;

  /// No description provided for @locationRationaleTitle.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan akses lokasi?'**
  String get locationRationaleTitle;

  /// No description provided for @locationRationaleBody.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar terus ke perkhidmatan laluan awam hanya untuk mengira laluan dan tidak disimpan di mana-mana pelayan kami.'**
  String get locationRationaleBody;

  /// No description provided for @locationAllow.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan'**
  String get locationAllow;

  /// No description provided for @locationNotNow.
  ///
  /// In ms, this message translates to:
  /// **'Bukan sekarang'**
  String get locationNotNow;

  /// No description provided for @locationOpenSettings.
  ///
  /// In ms, this message translates to:
  /// **'Buka Tetapan'**
  String get locationOpenSettings;

  /// No description provided for @locationDeniedForeverBody.
  ///
  /// In ms, this message translates to:
  /// **'Akses lokasi dimatikan. Aktifkan dalam Tetapan untuk guna lokasi semasa anda.'**
  String get locationDeniedForeverBody;

  /// No description provided for @locationServiceOffBody.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan lokasi dimatikan. Hidupkan GPS untuk guna lokasi semasa anda.'**
  String get locationServiceOffBody;

  /// No description provided for @routeSheetSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Ringkasan laluan'**
  String get routeSheetSemantics;

  /// No description provided for @routeCalculating.
  ///
  /// In ms, this message translates to:
  /// **'Mengira laluan…'**
  String get routeCalculating;

  /// No description provided for @routeLocationUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi GPS yang tepat belum tersedia. Semak kebenaran lokasi dan GPS, kemudian cuba lagi.'**
  String get routeLocationUnavailable;

  /// No description provided for @routeHasTolls.
  ///
  /// In ms, this message translates to:
  /// **'Ada tol'**
  String get routeHasTolls;

  /// No description provided for @routeNoTolls.
  ///
  /// In ms, this message translates to:
  /// **'Tiada tol'**
  String get routeNoTolls;

  /// No description provided for @routeClear.
  ///
  /// In ms, this message translates to:
  /// **'Padam laluan'**
  String get routeClear;

  /// No description provided for @routeRetry.
  ///
  /// In ms, this message translates to:
  /// **'Cuba lagi'**
  String get routeRetry;

  /// No description provided for @routeErrorNoRoute.
  ///
  /// In ms, this message translates to:
  /// **'Tiada laluan ditemui ke tempat ini. Cuba pilih jalan lain berdekatan.'**
  String get routeErrorNoRoute;

  /// No description provided for @routeErrorUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan laluan tidak tersedia buat masa ini. Cuba sebentar lagi.'**
  String get routeErrorUnavailable;

  /// No description provided for @routeErrorTimeout.
  ///
  /// In ms, this message translates to:
  /// **'Pengiraan laluan mengambil masa terlalu lama. Cuba lagi.'**
  String get routeErrorTimeout;

  /// No description provided for @routeErrorNetwork.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sambungan ke pelayan. Semak internet anda.'**
  String get routeErrorNetwork;

  /// No description provided for @routeErrorRateLimited.
  ///
  /// In ms, this message translates to:
  /// **'Terlalu banyak permintaan. Tunggu sebentar.'**
  String get routeErrorRateLimited;

  /// No description provided for @routeErrorGeneric.
  ///
  /// In ms, this message translates to:
  /// **'Sesuatu tidak kena. Cuba lagi.'**
  String get routeErrorGeneric;

  /// No description provided for @distanceMeters.
  ///
  /// In ms, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(int meters);

  /// No description provided for @distanceKilometers.
  ///
  /// In ms, this message translates to:
  /// **'{km} km'**
  String distanceKilometers(String km);

  /// No description provided for @durationMinutes.
  ///
  /// In ms, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In ms, this message translates to:
  /// **'{hours} j {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @appearanceTooltip.
  ///
  /// In ms, this message translates to:
  /// **'Tetapan'**
  String get appearanceTooltip;

  /// No description provided for @appearanceTitle.
  ///
  /// In ms, this message translates to:
  /// **'Paparan'**
  String get appearanceTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tentang FGMaps'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In ms, this message translates to:
  /// **'Aplikasi navigasi komuniti Malaysia'**
  String get aboutDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In ms, this message translates to:
  /// **'Versi'**
  String get aboutVersion;

  /// No description provided for @aboutVersionLoading.
  ///
  /// In ms, this message translates to:
  /// **'Memuatkan…'**
  String get aboutVersionLoading;

  /// No description provided for @aboutVersionUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Maklumat versi tidak tersedia'**
  String get aboutVersionUnavailable;

  /// No description provided for @aboutDeveloper.
  ///
  /// In ms, this message translates to:
  /// **'Dibangunkan oleh'**
  String get aboutDeveloper;

  /// No description provided for @aboutDeveloperName.
  ///
  /// In ms, this message translates to:
  /// **'Faiz Nasir'**
  String get aboutDeveloperName;

  /// No description provided for @aboutOwner.
  ///
  /// In ms, this message translates to:
  /// **'Dimiliki oleh'**
  String get aboutOwner;

  /// No description provided for @aboutOwnerName.
  ///
  /// In ms, this message translates to:
  /// **'FG Universal Empire Company'**
  String get aboutOwnerName;

  /// No description provided for @aboutCopyright.
  ///
  /// In ms, this message translates to:
  /// **'© {year} FG Universal Empire Company. Hak cipta terpelihara.'**
  String aboutCopyright(int year);

  /// No description provided for @themeSystem.
  ///
  /// In ms, this message translates to:
  /// **'Ikut sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ms, this message translates to:
  /// **'Cerah'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ms, this message translates to:
  /// **'Gelap'**
  String get themeDark;

  /// No description provided for @themeAmoled.
  ///
  /// In ms, this message translates to:
  /// **'Hitam AMOLED'**
  String get themeAmoled;

  /// No description provided for @themeAmoledHint.
  ///
  /// In ms, this message translates to:
  /// **'Latar hitam tulen. Jimat bateri pada skrin OLED dan kurang silau waktu malam.'**
  String get themeAmoledHint;

  /// No description provided for @routeErrorOfflineRequired.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sambungan internet. Muat turun peta offline untuk mengira laluan tanpa internet.'**
  String get routeErrorOfflineRequired;

  /// No description provided for @routeErrorOfflineEngine.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline tidak dapat digunakan. Cuba muat turun semula.'**
  String get routeErrorOfflineEngine;

  /// No description provided for @routeSourceOffline.
  ///
  /// In ms, this message translates to:
  /// **'Offline'**
  String get routeSourceOffline;

  /// No description provided for @offlineMapsOpen.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline'**
  String get offlineMapsOpen;

  /// No description provided for @offlineMapsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline'**
  String get offlineMapsTitle;

  /// No description provided for @offlineMapsIntro.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun peta Malaysia sekali untuk melihat peta, merancang laluan dan mencari tempat tanpa internet. Dengan internet, laluan dan carian menggunakan perkhidmatan dalam talian (lebih terkini) dan peta offline menjadi sandaran.'**
  String get offlineMapsIntro;

  /// No description provided for @offlineMapsNotConfigured.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun peta offline belum dikonfigurasi dalam binaan ini.'**
  String get offlineMapsNotConfigured;

  /// No description provided for @offlineMapsNotInstalled.
  ///
  /// In ms, this message translates to:
  /// **'Belum dimuat turun'**
  String get offlineMapsNotInstalled;

  /// No description provided for @offlineMapsInstalled.
  ///
  /// In ms, this message translates to:
  /// **'Dipasang: {date}'**
  String offlineMapsInstalled(String date);

  /// No description provided for @offlineMapsSize.
  ///
  /// In ms, this message translates to:
  /// **'Saiz muat turun {size}'**
  String offlineMapsSize(String size);

  /// No description provided for @offlineMapsUpdateAvailable.
  ///
  /// In ms, this message translates to:
  /// **'Kemas kini tersedia: {date}'**
  String offlineMapsUpdateAvailable(String date);

  /// No description provided for @offlineMapsUpToDate.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline terkini'**
  String get offlineMapsUpToDate;

  /// No description provided for @offlineMapsDownload.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun'**
  String get offlineMapsDownload;

  /// No description provided for @offlineMapsRetry.
  ///
  /// In ms, this message translates to:
  /// **'Cuba lagi'**
  String get offlineMapsRetry;

  /// No description provided for @offlineMapsUpdate.
  ///
  /// In ms, this message translates to:
  /// **'Kemas kini'**
  String get offlineMapsUpdate;

  /// No description provided for @offlineMapsDelete.
  ///
  /// In ms, this message translates to:
  /// **'Padam'**
  String get offlineMapsDelete;

  /// No description provided for @offlineMapsCancel.
  ///
  /// In ms, this message translates to:
  /// **'Batal'**
  String get offlineMapsCancel;

  /// No description provided for @offlineMapsChecking.
  ///
  /// In ms, this message translates to:
  /// **'Menyemak…'**
  String get offlineMapsChecking;

  /// No description provided for @offlineMapsDownloading.
  ///
  /// In ms, this message translates to:
  /// **'Memuat turun… {percent}%'**
  String offlineMapsDownloading(int percent);

  /// No description provided for @offlineMapsVerifying.
  ///
  /// In ms, this message translates to:
  /// **'Mengesahkan fail…'**
  String get offlineMapsVerifying;

  /// No description provided for @offlineMapsInstalling.
  ///
  /// In ms, this message translates to:
  /// **'Memasang…'**
  String get offlineMapsInstalling;

  /// No description provided for @offlineMapsMobileDataTitle.
  ///
  /// In ms, this message translates to:
  /// **'Guna data mudah alih?'**
  String get offlineMapsMobileDataTitle;

  /// No description provided for @offlineMapsMobileDataBody.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun ini kira-kira {size}. Anda tidak bersambung ke Wi-Fi.'**
  String offlineMapsMobileDataBody(String size);

  /// No description provided for @offlineMapsDeleteTitle.
  ///
  /// In ms, this message translates to:
  /// **'Padam peta offline?'**
  String get offlineMapsDeleteTitle;

  /// No description provided for @offlineMapsDeleteBody.
  ///
  /// In ms, this message translates to:
  /// **'Anda perlu memuat turunnya semula untuk menggunakan paparan peta, laluan dan carian offline.'**
  String get offlineMapsDeleteBody;

  /// No description provided for @offlineMapsErrorNetwork.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat menyambung ke pelayan peta offline. Semak internet dan cuba lagi.'**
  String get offlineMapsErrorNetwork;

  /// No description provided for @offlineMapsErrorStorage.
  ///
  /// In ms, this message translates to:
  /// **'Ruang simpanan tidak mencukupi. Bebaskan ruang dan cuba lagi.'**
  String get offlineMapsErrorStorage;

  /// No description provided for @offlineMapsErrorChecksum.
  ///
  /// In ms, this message translates to:
  /// **'Fail yang dimuat turun rosak. Cuba lagi.'**
  String get offlineMapsErrorChecksum;

  /// No description provided for @offlineMapsErrorIncompatible.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline ini tidak serasi dengan versi app. Kemas kini app.'**
  String get offlineMapsErrorIncompatible;

  /// No description provided for @offlineMapsErrorInvalid.
  ///
  /// In ms, this message translates to:
  /// **'Maklumat peta offline tidak sah.'**
  String get offlineMapsErrorInvalid;

  /// No description provided for @offlineMapsErrorGeneric.
  ///
  /// In ms, this message translates to:
  /// **'Sesuatu tidak kena. Cuba lagi.'**
  String get offlineMapsErrorGeneric;

  /// No description provided for @routingModeTitle.
  ///
  /// In ms, this message translates to:
  /// **'Sumber laluan'**
  String get routingModeTitle;

  /// No description provided for @routingModeAuto.
  ///
  /// In ms, this message translates to:
  /// **'Auto'**
  String get routingModeAuto;

  /// No description provided for @routingModeOnline.
  ///
  /// In ms, this message translates to:
  /// **'Online sahaja'**
  String get routingModeOnline;

  /// No description provided for @routingModeOffline.
  ///
  /// In ms, this message translates to:
  /// **'Offline sahaja'**
  String get routingModeOffline;

  /// No description provided for @routingModeAutoHint.
  ///
  /// In ms, this message translates to:
  /// **'Online dahulu; jika gagal, guna peta offline.'**
  String get routingModeAutoHint;

  /// No description provided for @tripPlannerTitle.
  ///
  /// In ms, this message translates to:
  /// **'Rancang perjalanan'**
  String get tripPlannerTitle;

  /// No description provided for @tripFrom.
  ///
  /// In ms, this message translates to:
  /// **'Dari'**
  String get tripFrom;

  /// No description provided for @tripTo.
  ///
  /// In ms, this message translates to:
  /// **'Ke'**
  String get tripTo;

  /// No description provided for @searchHint.
  ///
  /// In ms, this message translates to:
  /// **'Tempat, alamat, koordinat atau pautan Maps'**
  String get searchHint;

  /// No description provided for @searchPillHint.
  ///
  /// In ms, this message translates to:
  /// **'Ke mana?'**
  String get searchPillHint;

  /// No description provided for @searchClear.
  ///
  /// In ms, this message translates to:
  /// **'Kosongkan'**
  String get searchClear;

  /// No description provided for @searchPrompt.
  ///
  /// In ms, this message translates to:
  /// **'Taip nama tempat, atau pilih Rumah / Kerja di bawah. Boleh juga tampal koordinat (3.14, 101.68) atau pautan Google Maps / Waze.'**
  String get searchPrompt;

  /// No description provided for @searchHistory.
  ///
  /// In ms, this message translates to:
  /// **'Tempat terkini'**
  String get searchHistory;

  /// No description provided for @searchClearHistory.
  ///
  /// In ms, this message translates to:
  /// **'Padam sejarah'**
  String get searchClearHistory;

  /// No description provided for @sharedLocationStopNavigation.
  ///
  /// In ms, this message translates to:
  /// **'Tamatkan navigasi semasa sebelum membuka destinasi yang dikongsi.'**
  String get sharedLocationStopNavigation;

  /// No description provided for @searchNoResults.
  ///
  /// In ms, this message translates to:
  /// **'Tiada hasil untuk “{query}”. Tampal koordinat atau pautan Google Maps / Waze — kami hanya perlukan lat/lng.'**
  String searchNoResults(String query);

  /// No description provided for @searchNoNearby.
  ///
  /// In ms, this message translates to:
  /// **'Tiada “{category}” ditemui berhampiran dalam OpenStreetMap. Cuba kawasan lain atau cari mengikut nama.'**
  String searchNoNearby(String category);

  /// No description provided for @searchNearbyRefining.
  ///
  /// In ms, this message translates to:
  /// **'Mencari lebih jauh…'**
  String get searchNearbyRefining;

  /// No description provided for @searchNeedLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda belum diketahui. Hidupkan lokasi untuk mencari tempat berhampiran.'**
  String get searchNeedLocation;

  /// No description provided for @searchNearbySaved.
  ///
  /// In ms, this message translates to:
  /// **'Pelayan data peta tidak dapat dicapai. Memaparkan hasil tersimpan dari {when}.'**
  String searchNearbySaved(String when);

  /// No description provided for @searchErrorNetwork.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sambungan internet. Carian memerlukan internet; anda masih boleh tampal koordinat atau pautan Maps.'**
  String get searchErrorNetwork;

  /// No description provided for @searchErrorRateLimited.
  ///
  /// In ms, this message translates to:
  /// **'Terlalu banyak carian. Tunggu sebentar.'**
  String get searchErrorRateLimited;

  /// No description provided for @searchErrorUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan carian tidak tersedia buat masa ini.'**
  String get searchErrorUnavailable;

  /// No description provided for @searchOfflinePackPrompt.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun indeks tempat offline untuk carian Malaysia yang lebih lengkap — tiada suis berasingan.'**
  String get searchOfflinePackPrompt;

  /// No description provided for @searchOfflinePackUpdate.
  ///
  /// In ms, this message translates to:
  /// **'Kemas kini pek peta offline untuk dapat tempat baharu.'**
  String get searchOfflinePackUpdate;

  /// No description provided for @searchOfflinePackAction.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline'**
  String get searchOfflinePackAction;

  /// No description provided for @searchQuickDestinations.
  ///
  /// In ms, this message translates to:
  /// **'Pergi sekarang'**
  String get searchQuickDestinations;

  /// No description provided for @searchResultOffline.
  ///
  /// In ms, this message translates to:
  /// **'Offline'**
  String get searchResultOffline;

  /// No description provided for @routeFromTo.
  ///
  /// In ms, this message translates to:
  /// **'{from} → {to}'**
  String routeFromTo(String from, String to);

  /// No description provided for @navStart.
  ///
  /// In ms, this message translates to:
  /// **'Mula'**
  String get navStart;

  /// No description provided for @navSimulate.
  ///
  /// In ms, this message translates to:
  /// **'Simulasi'**
  String get navSimulate;

  /// No description provided for @navSimSpeedTitle.
  ///
  /// In ms, this message translates to:
  /// **'Kelajuan simulasi'**
  String get navSimSpeedTitle;

  /// No description provided for @navSimSpeedHint.
  ///
  /// In ms, this message translates to:
  /// **'Pilih kelajuan jelajah. Auto ikut anggaran laluan (kadang ~18 km/j di bandar). Semasa simulasi, guna butang 1×–4× untuk lebih pantas.'**
  String get navSimSpeedHint;

  /// No description provided for @navSimSpeedAuto.
  ///
  /// In ms, this message translates to:
  /// **'Auto'**
  String get navSimSpeedAuto;

  /// No description provided for @navSimSpeedKmh.
  ///
  /// In ms, this message translates to:
  /// **'{kmh} km/j'**
  String navSimSpeedKmh(int kmh);

  /// No description provided for @navSimSpeedMult.
  ///
  /// In ms, this message translates to:
  /// **'{n}×'**
  String navSimSpeedMult(int n);

  /// No description provided for @navEnd.
  ///
  /// In ms, this message translates to:
  /// **'Tamat'**
  String get navEnd;

  /// No description provided for @navEndTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tamatkan navigasi?'**
  String get navEndTitle;

  /// No description provided for @navEndKeep.
  ///
  /// In ms, this message translates to:
  /// **'Teruskan'**
  String get navEndKeep;

  /// No description provided for @navDone.
  ///
  /// In ms, this message translates to:
  /// **'Selesai'**
  String get navDone;

  /// No description provided for @navArrived.
  ///
  /// In ms, this message translates to:
  /// **'Anda telah sampai'**
  String get navArrived;

  /// No description provided for @navArrivalSub.
  ///
  /// In ms, this message translates to:
  /// **'Sampai di destinasi'**
  String get navArrivalSub;

  /// No description provided for @navRerouting.
  ///
  /// In ms, this message translates to:
  /// **'Mengira semula laluan…'**
  String get navRerouting;

  /// No description provided for @navRerouteRetry.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sambungan. Mencuba semula…'**
  String get navRerouteRetry;

  /// No description provided for @navGpsWeak.
  ///
  /// In ms, this message translates to:
  /// **'Isyarat GPS lemah'**
  String get navGpsWeak;

  /// No description provided for @navGpsEstimating.
  ///
  /// In ms, this message translates to:
  /// **'Tiada isyarat GPS. Kedudukan dianggar.'**
  String get navGpsEstimating;

  /// No description provided for @navLocationLost.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi tidak dapat diakses. Semak kebenaran lokasi.'**
  String get navLocationLost;

  /// No description provided for @navRecenter.
  ///
  /// In ms, this message translates to:
  /// **'Pusatkan'**
  String get navRecenter;

  /// No description provided for @navMute.
  ///
  /// In ms, this message translates to:
  /// **'Senyapkan suara'**
  String get navMute;

  /// No description provided for @navUnmute.
  ///
  /// In ms, this message translates to:
  /// **'Hidupkan suara'**
  String get navUnmute;

  /// No description provided for @navOverview.
  ///
  /// In ms, this message translates to:
  /// **'Lihat keseluruhan laluan'**
  String get navOverview;

  /// No description provided for @navChangeRoute.
  ///
  /// In ms, this message translates to:
  /// **'Tukar laluan'**
  String get navChangeRoute;

  /// No description provided for @navRoutesTitle.
  ///
  /// In ms, this message translates to:
  /// **'Pilih laluan dari sini'**
  String get navRoutesTitle;

  /// No description provided for @navRoutesCurrent.
  ///
  /// In ms, this message translates to:
  /// **'Laluan semasa'**
  String get navRoutesCurrent;

  /// No description provided for @navRoutesLoading.
  ///
  /// In ms, this message translates to:
  /// **'Mencari laluan dari lokasi anda…'**
  String get navRoutesLoading;

  /// No description provided for @navRoutesError.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat mencari laluan lain sekarang.'**
  String get navRoutesError;

  /// No description provided for @navRoutesNone.
  ///
  /// In ms, this message translates to:
  /// **'Tiada laluan lain dari sini.'**
  String get navRoutesNone;

  /// No description provided for @navRoutesSame.
  ///
  /// In ms, this message translates to:
  /// **'Masa sama'**
  String get navRoutesSame;

  /// No description provided for @navRoutesFaster.
  ///
  /// In ms, this message translates to:
  /// **'{time} lebih cepat'**
  String navRoutesFaster(String time);

  /// No description provided for @navRoutesSlower.
  ///
  /// In ms, this message translates to:
  /// **'{time} lebih lambat'**
  String navRoutesSlower(String time);

  /// No description provided for @navRoutesSwitched.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ditukar'**
  String get navRoutesSwitched;

  /// No description provided for @navCameraAuto.
  ///
  /// In ms, this message translates to:
  /// **'Kamera auto 3D/2D'**
  String get navCameraAuto;

  /// No description provided for @navCameraFlat.
  ///
  /// In ms, this message translates to:
  /// **'Kamera 2D'**
  String get navCameraFlat;

  /// No description provided for @navCameraTilted.
  ///
  /// In ms, this message translates to:
  /// **'Kamera 3D'**
  String get navCameraTilted;

  /// No description provided for @navThen.
  ///
  /// In ms, this message translates to:
  /// **'Kemudian'**
  String get navThen;

  /// No description provided for @navRoundaboutExitSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Bulatan, ambil simpang keluar ke-{n}'**
  String navRoundaboutExitSemantics(int n);

  /// No description provided for @navLaneLeft.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong kiri'**
  String get navLaneLeft;

  /// No description provided for @navLaneRight.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong kanan'**
  String get navLaneRight;

  /// No description provided for @navLaneStripSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Lorong: {lanes}'**
  String navLaneStripSemantics(String lanes);

  /// No description provided for @navLaneUse.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong yang ditanda'**
  String get navLaneUse;

  /// No description provided for @navLaneRightmost.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong paling kanan'**
  String get navLaneRightmost;

  /// No description provided for @navLaneLeftmost.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong paling kiri'**
  String get navLaneLeftmost;

  /// No description provided for @navLaneRightmostN.
  ///
  /// In ms, this message translates to:
  /// **'Guna {count} lorong paling kanan'**
  String navLaneRightmostN(int count);

  /// No description provided for @navLaneLeftmostN.
  ///
  /// In ms, this message translates to:
  /// **'Guna {count} lorong paling kiri'**
  String navLaneLeftmostN(int count);

  /// No description provided for @navLaneNthFromLeft.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong ke-{n} dari kiri'**
  String navLaneNthFromLeft(int n);

  /// No description provided for @navLaneNthFromRight.
  ///
  /// In ms, this message translates to:
  /// **'Guna lorong ke-{n} dari kanan'**
  String navLaneNthFromRight(int n);

  /// No description provided for @navLaneEstimated.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran lorong'**
  String get navLaneEstimated;

  /// No description provided for @navJunctionCross.
  ///
  /// In ms, this message translates to:
  /// **'Simpang 4'**
  String get navJunctionCross;

  /// No description provided for @navJunctionTee.
  ///
  /// In ms, this message translates to:
  /// **'Simpang 3'**
  String get navJunctionTee;

  /// No description provided for @navJunctionRoundabout.
  ///
  /// In ms, this message translates to:
  /// **'Bulatan · keluar ke-{n}'**
  String navJunctionRoundabout(int n);

  /// No description provided for @navJunctionSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Gambar simpang: {kind}'**
  String navJunctionSemantics(String kind);

  /// No description provided for @navLaneViewSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Paparan {count} lorong'**
  String navLaneViewSemantics(int count);

  /// No description provided for @navLaneViewHintSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Paparan lorong. {hint}'**
  String navLaneViewHintSemantics(String hint);

  /// No description provided for @navGetReady.
  ///
  /// In ms, this message translates to:
  /// **'Bersedia'**
  String get navGetReady;

  /// No description provided for @navSimulatedBadge.
  ///
  /// In ms, this message translates to:
  /// **'Simulasi'**
  String get navSimulatedBadge;

  /// No description provided for @navSpeedUnit.
  ///
  /// In ms, this message translates to:
  /// **'km/j'**
  String get navSpeedUnit;

  /// No description provided for @navSpeedLabel.
  ///
  /// In ms, this message translates to:
  /// **'Kelajuan'**
  String get navSpeedLabel;

  /// No description provided for @navSettingsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tetapan navigasi'**
  String get navSettingsTitle;

  /// No description provided for @navVoiceTitle.
  ///
  /// In ms, this message translates to:
  /// **'Suara navigasi'**
  String get navVoiceTitle;

  /// No description provided for @navVoiceLanguage.
  ///
  /// In ms, this message translates to:
  /// **'Bahasa suara'**
  String get navVoiceLanguage;

  /// No description provided for @navVoiceFollowApp.
  ///
  /// In ms, this message translates to:
  /// **'Ikut app'**
  String get navVoiceFollowApp;

  /// No description provided for @navVoiceMalay.
  ///
  /// In ms, this message translates to:
  /// **'Melayu'**
  String get navVoiceMalay;

  /// No description provided for @navVoiceEnglish.
  ///
  /// In ms, this message translates to:
  /// **'English'**
  String get navVoiceEnglish;

  /// No description provided for @navCameraTitle.
  ///
  /// In ms, this message translates to:
  /// **'Paparan kamera'**
  String get navCameraTitle;

  /// No description provided for @navCameraAutoHint.
  ///
  /// In ms, this message translates to:
  /// **'3D di jalan lurus, 2D menghampiri selekoh dan bulatan'**
  String get navCameraAutoHint;

  /// No description provided for @navSettingsOpen.
  ///
  /// In ms, this message translates to:
  /// **'Tetapan navigasi'**
  String get navSettingsOpen;

  /// No description provided for @navContinue.
  ///
  /// In ms, this message translates to:
  /// **'Teruskan'**
  String get navContinue;

  /// No description provided for @navEta.
  ///
  /// In ms, this message translates to:
  /// **'Tiba {time}'**
  String navEta(String time);

  /// No description provided for @navAcquiring.
  ///
  /// In ms, this message translates to:
  /// **'Mencari isyarat GPS…'**
  String get navAcquiring;

  /// No description provided for @routeFastest.
  ///
  /// In ms, this message translates to:
  /// **'Terpantas'**
  String get routeFastest;

  /// No description provided for @routeShortest.
  ///
  /// In ms, this message translates to:
  /// **'Terpendek'**
  String get routeShortest;

  /// No description provided for @routeNoHighways.
  ///
  /// In ms, this message translates to:
  /// **'Tanpa lebuh raya'**
  String get routeNoHighways;

  /// No description provided for @routeAlternative.
  ///
  /// In ms, this message translates to:
  /// **'Alternatif'**
  String get routeAlternative;

  /// No description provided for @routeVia.
  ///
  /// In ms, this message translates to:
  /// **'melalui {road}'**
  String routeVia(String road);

  /// No description provided for @routeFindingTo.
  ///
  /// In ms, this message translates to:
  /// **'Mencari laluan ke {place}…'**
  String routeFindingTo(String place);

  /// No description provided for @routeVehicleCar.
  ///
  /// In ms, this message translates to:
  /// **'Kereta'**
  String get routeVehicleCar;

  /// No description provided for @routeVehicleMotorcycle.
  ///
  /// In ms, this message translates to:
  /// **'Motosikal'**
  String get routeVehicleMotorcycle;

  /// No description provided for @settingsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tetapan'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In ms, this message translates to:
  /// **'Paparan'**
  String get settingsAppearance;

  /// No description provided for @settingsNavigation.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi'**
  String get settingsNavigation;

  /// No description provided for @settingsMaps.
  ///
  /// In ms, this message translates to:
  /// **'Peta'**
  String get settingsMaps;

  /// No description provided for @settingsOfflineHint.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun peta untuk navigasi tanpa internet'**
  String get settingsOfflineHint;

  /// No description provided for @settingsAboutHint.
  ///
  /// In ms, this message translates to:
  /// **'Versi, pembangun dan hak cipta'**
  String get settingsAboutHint;

  /// No description provided for @themeSystemShort.
  ///
  /// In ms, this message translates to:
  /// **'Sistem'**
  String get themeSystemShort;

  /// No description provided for @searchCatFuel.
  ///
  /// In ms, this message translates to:
  /// **'Stesen minyak'**
  String get searchCatFuel;

  /// No description provided for @searchCatFood.
  ///
  /// In ms, this message translates to:
  /// **'Makan'**
  String get searchCatFood;

  /// No description provided for @searchCatMosque.
  ///
  /// In ms, this message translates to:
  /// **'Masjid / surau'**
  String get searchCatMosque;

  /// No description provided for @searchCatToilet.
  ///
  /// In ms, this message translates to:
  /// **'Tandas'**
  String get searchCatToilet;

  /// No description provided for @searchCatParking.
  ///
  /// In ms, this message translates to:
  /// **'Parkir'**
  String get searchCatParking;

  /// No description provided for @searchCatHospital.
  ///
  /// In ms, this message translates to:
  /// **'Hospital'**
  String get searchCatHospital;

  /// No description provided for @searchCategories.
  ///
  /// In ms, this message translates to:
  /// **'Berhampiran dari lokasi anda'**
  String get searchCategories;

  /// No description provided for @placeKindShopping.
  ///
  /// In ms, this message translates to:
  /// **'Beli-belah'**
  String get placeKindShopping;

  /// No description provided for @placeKindFuel.
  ///
  /// In ms, this message translates to:
  /// **'Stesen minyak'**
  String get placeKindFuel;

  /// No description provided for @placeKindFood.
  ///
  /// In ms, this message translates to:
  /// **'Makan'**
  String get placeKindFood;

  /// No description provided for @placeKindWorship.
  ///
  /// In ms, this message translates to:
  /// **'Tempat ibadat'**
  String get placeKindWorship;

  /// No description provided for @placeKindHealth.
  ///
  /// In ms, this message translates to:
  /// **'Kesihatan'**
  String get placeKindHealth;

  /// No description provided for @placeKindParking.
  ///
  /// In ms, this message translates to:
  /// **'Parkir'**
  String get placeKindParking;

  /// No description provided for @placeKindToilets.
  ///
  /// In ms, this message translates to:
  /// **'Tandas'**
  String get placeKindToilets;

  /// No description provided for @placeKindTransit.
  ///
  /// In ms, this message translates to:
  /// **'Perhentian atau stesen'**
  String get placeKindTransit;

  /// No description provided for @placeKindRoad.
  ///
  /// In ms, this message translates to:
  /// **'Jalan'**
  String get placeKindRoad;

  /// No description provided for @placeKindArea.
  ///
  /// In ms, this message translates to:
  /// **'Kawasan'**
  String get placeKindArea;

  /// No description provided for @placeKindAddress.
  ///
  /// In ms, this message translates to:
  /// **'Alamat'**
  String get placeKindAddress;

  /// No description provided for @placeKindPlace.
  ///
  /// In ms, this message translates to:
  /// **'Tempat'**
  String get placeKindPlace;

  /// No description provided for @placeOppositeSide.
  ///
  /// In ms, this message translates to:
  /// **'seberang jalan'**
  String get placeOppositeSide;

  /// No description provided for @themeSun.
  ///
  /// In ms, this message translates to:
  /// **'Matahari'**
  String get themeSun;

  /// No description provided for @themeSunHint.
  ///
  /// In ms, this message translates to:
  /// **'Gelap antara matahari terbenam dan terbit di lokasi anda. Dikira dalam peranti, tanpa internet.'**
  String get themeSunHint;

  /// No description provided for @savedHome.
  ///
  /// In ms, this message translates to:
  /// **'Rumah'**
  String get savedHome;

  /// No description provided for @savedWork.
  ///
  /// In ms, this message translates to:
  /// **'Kerja'**
  String get savedWork;

  /// No description provided for @savedFavorite.
  ///
  /// In ms, this message translates to:
  /// **'Kegemaran'**
  String get savedFavorite;

  /// No description provided for @savedSetHome.
  ///
  /// In ms, this message translates to:
  /// **'Tetapkan Rumah'**
  String get savedSetHome;

  /// No description provided for @savedSetWork.
  ///
  /// In ms, this message translates to:
  /// **'Tetapkan Kerja'**
  String get savedSetWork;

  /// No description provided for @savedSection.
  ///
  /// In ms, this message translates to:
  /// **'Tempat disimpan'**
  String get savedSection;

  /// No description provided for @savedSaveTooltip.
  ///
  /// In ms, this message translates to:
  /// **'Simpan tempat'**
  String get savedSaveTooltip;

  /// No description provided for @savedSheetTitle.
  ///
  /// In ms, this message translates to:
  /// **'Simpan sebagai'**
  String get savedSheetTitle;

  /// No description provided for @savedChange.
  ///
  /// In ms, this message translates to:
  /// **'Tukar'**
  String get savedChange;

  /// No description provided for @savedRemove.
  ///
  /// In ms, this message translates to:
  /// **'Padam'**
  String get savedRemove;

  /// No description provided for @savedTapToSet.
  ///
  /// In ms, this message translates to:
  /// **'Ketik untuk tetapkan'**
  String get savedTapToSet;

  /// No description provided for @savedFavoriteAdd.
  ///
  /// In ms, this message translates to:
  /// **'Tambah ke kegemaran'**
  String get savedFavoriteAdd;

  /// No description provided for @savedFavoriteRemove.
  ///
  /// In ms, this message translates to:
  /// **'Buang daripada kegemaran'**
  String get savedFavoriteRemove;

  /// No description provided for @savedAssigning.
  ///
  /// In ms, this message translates to:
  /// **'Cari alamat {kind} anda'**
  String savedAssigning(String kind);

  /// No description provided for @savedDone.
  ///
  /// In ms, this message translates to:
  /// **'Disimpan sebagai {label}'**
  String savedDone(String label);

  /// No description provided for @savedRemoved.
  ///
  /// In ms, this message translates to:
  /// **'{label} dipadam'**
  String savedRemoved(String label);

  /// No description provided for @onbSkip.
  ///
  /// In ms, this message translates to:
  /// **'Langkau'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya'**
  String get onbNext;

  /// No description provided for @onbStart.
  ///
  /// In ms, this message translates to:
  /// **'Mula'**
  String get onbStart;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi untuk Malaysia'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In ms, this message translates to:
  /// **'Panduan belok demi belok untuk kereta dan motosikal, dengan suara dalam Bahasa Melayu atau English.'**
  String get onbWelcomeBody;

  /// No description provided for @onbFeatureRoutes.
  ///
  /// In ms, this message translates to:
  /// **'Laluan terpantas, tanpa tol dan alternatif'**
  String get onbFeatureRoutes;

  /// No description provided for @onbFeatureNearby.
  ///
  /// In ms, this message translates to:
  /// **'Cari minyak, makan, surau dan tandas berhampiran'**
  String get onbFeatureNearby;

  /// No description provided for @onbFeatureReports.
  ///
  /// In ms, this message translates to:
  /// **'Laporkan bahaya dan polis di jalan'**
  String get onbFeatureReports;

  /// No description provided for @onbFeatureOffline.
  ///
  /// In ms, this message translates to:
  /// **'Peta offline untuk bila tiada isyarat'**
  String get onbFeatureOffline;

  /// No description provided for @onbPrivacyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Privasi anda'**
  String get onbPrivacyTitle;

  /// No description provided for @onbPrivacyLocal.
  ///
  /// In ms, this message translates to:
  /// **'Tiada akaun dan tiada penjejakan. Tempat, sejarah dan laporan anda kekal pada telefon ini.'**
  String get onbPrivacyLocal;

  /// No description provided for @onbPrivacyServers.
  ///
  /// In ms, this message translates to:
  /// **'Untuk carian dan laluan, app menghantar teks carian dan koordinat perjalanan ke perkhidmatan awam OpenStreetMap. Tiada yang lain dihantar.'**
  String get onbPrivacyServers;

  /// No description provided for @onbPrivacyLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi hanya digunakan semasa app dibuka, untuk menunjukkan kedudukan anda dan memandu anda.'**
  String get onbPrivacyLocation;

  /// No description provided for @onbSetupTitle.
  ///
  /// In ms, this message translates to:
  /// **'Sediakan dalam 10 saat'**
  String get onbSetupTitle;

  /// No description provided for @onbVehicleQuestion.
  ///
  /// In ms, this message translates to:
  /// **'Anda bergerak dengan apa?'**
  String get onbVehicleQuestion;

  /// No description provided for @onbVoiceQuestion.
  ///
  /// In ms, this message translates to:
  /// **'Bahasa suara'**
  String get onbVoiceQuestion;

  /// No description provided for @onbAllowLocation.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan lokasi'**
  String get onbAllowLocation;

  /// No description provided for @onbLocationGranted.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi dibenarkan'**
  String get onbLocationGranted;

  /// No description provided for @onbLocationHint.
  ///
  /// In ms, this message translates to:
  /// **'Anda juga boleh buat ini kemudian apabila memulakan perjalanan pertama.'**
  String get onbLocationHint;

  /// No description provided for @onbPageOf.
  ///
  /// In ms, this message translates to:
  /// **'Halaman {current} daripada {total}'**
  String onbPageOf(int current, int total);

  /// No description provided for @settingsTextSize.
  ///
  /// In ms, this message translates to:
  /// **'Saiz teks'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeHint.
  ///
  /// In ms, this message translates to:
  /// **'Dikenakan di atas saiz teks telefon anda.'**
  String get settingsTextSizeHint;

  /// No description provided for @settingsEasyMode.
  ///
  /// In ms, this message translates to:
  /// **'Mod mudah'**
  String get settingsEasyMode;

  /// No description provided for @settingsEasyModeHint.
  ///
  /// In ms, this message translates to:
  /// **'Teks dan butang lebih besar, kad arahan berkontras tinggi, kawalan lebih sedikit semasa memandu. Sesuai untuk warga emas.'**
  String get settingsEasyModeHint;

  /// No description provided for @onbEasyMode.
  ///
  /// In ms, this message translates to:
  /// **'Paparan besar & mudah'**
  String get onbEasyMode;

  /// No description provided for @onbEasyModeHint.
  ///
  /// In ms, this message translates to:
  /// **'Teks lebih besar, arahan lebih jelas, butang lebih sedikit. Boleh ditukar bila-bila masa dalam Tetapan.'**
  String get onbEasyModeHint;

  /// No description provided for @navGpsWeakHint.
  ///
  /// In ms, this message translates to:
  /// **'Teruskan memandu. Kami sedang mencari isyarat.'**
  String get navGpsWeakHint;

  /// No description provided for @routeMoreOptions.
  ///
  /// In ms, this message translates to:
  /// **'Lanjut'**
  String get routeMoreOptions;

  /// No description provided for @settingsAzan.
  ///
  /// In ms, this message translates to:
  /// **'Waktu Azan'**
  String get settingsAzan;

  /// No description provided for @azanTitle.
  ///
  /// In ms, this message translates to:
  /// **'Waktu solat'**
  String get azanTitle;

  /// No description provided for @azanEnable.
  ///
  /// In ms, this message translates to:
  /// **'Sentiasa ingatkan waktu azan'**
  String get azanEnable;

  /// No description provided for @azanEnableHint.
  ///
  /// In ms, this message translates to:
  /// **'Notifikasi dan bunyi azan pada setiap waktu solat, walaupun app ditutup.'**
  String get azanEnableHint;

  /// No description provided for @azanPrayerFajr.
  ///
  /// In ms, this message translates to:
  /// **'Subuh'**
  String get azanPrayerFajr;

  /// No description provided for @azanPrayerSunrise.
  ///
  /// In ms, this message translates to:
  /// **'Syuruk'**
  String get azanPrayerSunrise;

  /// No description provided for @azanPrayerDhuhr.
  ///
  /// In ms, this message translates to:
  /// **'Zohor'**
  String get azanPrayerDhuhr;

  /// No description provided for @azanPrayerAsr.
  ///
  /// In ms, this message translates to:
  /// **'Asar'**
  String get azanPrayerAsr;

  /// No description provided for @azanPrayerMaghrib.
  ///
  /// In ms, this message translates to:
  /// **'Maghrib'**
  String get azanPrayerMaghrib;

  /// No description provided for @azanPrayerIsha.
  ///
  /// In ms, this message translates to:
  /// **'Isyak'**
  String get azanPrayerIsha;

  /// No description provided for @azanPrayersLabel.
  ///
  /// In ms, this message translates to:
  /// **'Waktu yang diberitahu'**
  String get azanPrayersLabel;

  /// No description provided for @azanSoundLabel.
  ///
  /// In ms, this message translates to:
  /// **'Bunyi'**
  String get azanSoundLabel;

  /// No description provided for @azanSoundFull.
  ///
  /// In ms, this message translates to:
  /// **'Azan penuh'**
  String get azanSoundFull;

  /// No description provided for @azanSoundShort.
  ///
  /// In ms, this message translates to:
  /// **'Nada pendek'**
  String get azanSoundShort;

  /// No description provided for @azanSoundSilent.
  ///
  /// In ms, this message translates to:
  /// **'Senyap'**
  String get azanSoundSilent;

  /// No description provided for @azanSoundHint.
  ///
  /// In ms, this message translates to:
  /// **'Azan penuh ialah lalai. Nada pendek atau senyap jika anda mahu lebih tenang.'**
  String get azanSoundHint;

  /// No description provided for @azanMethodLabel.
  ///
  /// In ms, this message translates to:
  /// **'Kaedah pengiraan'**
  String get azanMethodLabel;

  /// No description provided for @azanMethodJakim.
  ///
  /// In ms, this message translates to:
  /// **'JAKIM (Malaysia)'**
  String get azanMethodJakim;

  /// No description provided for @azanMethodMwl.
  ///
  /// In ms, this message translates to:
  /// **'Liga Muslim Sedunia'**
  String get azanMethodMwl;

  /// No description provided for @azanMethodEgyptian.
  ///
  /// In ms, this message translates to:
  /// **'Mesir'**
  String get azanMethodEgyptian;

  /// No description provided for @azanMethodKarachi.
  ///
  /// In ms, this message translates to:
  /// **'Karachi'**
  String get azanMethodKarachi;

  /// No description provided for @azanMethodUmmAlQura.
  ///
  /// In ms, this message translates to:
  /// **'Umm al-Qura (Makkah)'**
  String get azanMethodUmmAlQura;

  /// No description provided for @azanMadhabLabel.
  ///
  /// In ms, this message translates to:
  /// **'Mazhab (waktu Asar)'**
  String get azanMadhabLabel;

  /// No description provided for @azanMadhabShafi.
  ///
  /// In ms, this message translates to:
  /// **'Syafie'**
  String get azanMadhabShafi;

  /// No description provided for @azanMadhabHanafi.
  ///
  /// In ms, this message translates to:
  /// **'Hanafi'**
  String get azanMadhabHanafi;

  /// No description provided for @azanReminderLabel.
  ///
  /// In ms, this message translates to:
  /// **'Peringatan awal'**
  String get azanReminderLabel;

  /// No description provided for @azanReminderNone.
  ///
  /// In ms, this message translates to:
  /// **'Tiada'**
  String get azanReminderNone;

  /// No description provided for @azanReminderMinutes.
  ///
  /// In ms, this message translates to:
  /// **'{n} min sebelum'**
  String azanReminderMinutes(int n);

  /// No description provided for @azanPlayDuringNav.
  ///
  /// In ms, this message translates to:
  /// **'Main azan penuh semasa navigasi'**
  String get azanPlayDuringNav;

  /// No description provided for @azanPlayDuringNavHint.
  ///
  /// In ms, this message translates to:
  /// **'Jika mati: hanya bunyi pendek dan cip pada HUD supaya arahan suara tidak terganggu. Notifikasi tetap dihantar.'**
  String get azanPlayDuringNavHint;

  /// No description provided for @azanLocationLabel.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi'**
  String get azanLocationLabel;

  /// No description provided for @azanLocationAuto.
  ///
  /// In ms, this message translates to:
  /// **'Ikut lokasi peranti'**
  String get azanLocationAuto;

  /// No description provided for @azanLocationCity.
  ///
  /// In ms, this message translates to:
  /// **'Pilih bandar'**
  String get azanLocationCity;

  /// No description provided for @azanLocationAutoHint.
  ///
  /// In ms, this message translates to:
  /// **'Dikira pada telefon ini daripada lokasi anda (dibundarkan ~1 km). Tiada data dihantar.'**
  String get azanLocationAutoHint;

  /// No description provided for @azanNextIn.
  ///
  /// In ms, this message translates to:
  /// **'{prayer} {time} · {remaining} lagi'**
  String azanNextIn(String prayer, String time, String remaining);

  /// No description provided for @azanNextPrayer.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya: {prayer} pada {time}'**
  String azanNextPrayer(String prayer, String time);

  /// No description provided for @azanAllDone.
  ///
  /// In ms, this message translates to:
  /// **'Semua waktu hari ini telah berlalu'**
  String get azanAllDone;

  /// No description provided for @azanNextTomorrow.
  ///
  /// In ms, this message translates to:
  /// **'Esok: {prayer} {time}'**
  String azanNextTomorrow(String prayer, String time);

  /// No description provided for @azanRemainingLeft.
  ///
  /// In ms, this message translates to:
  /// **'{remaining} lagi'**
  String azanRemainingLeft(String remaining);

  /// No description provided for @azanNowTitle.
  ///
  /// In ms, this message translates to:
  /// **'Waktu {prayer}'**
  String azanNowTitle(String prayer);

  /// No description provided for @azanNowBody.
  ///
  /// In ms, this message translates to:
  /// **'Telah masuk waktu solat.'**
  String get azanNowBody;

  /// No description provided for @azanStop.
  ///
  /// In ms, this message translates to:
  /// **'Hentikan azan'**
  String get azanStop;

  /// No description provided for @azanListen.
  ///
  /// In ms, this message translates to:
  /// **'Dengar azan'**
  String get azanListen;

  /// No description provided for @azanStopListening.
  ///
  /// In ms, this message translates to:
  /// **'Berhenti'**
  String get azanStopListening;

  /// No description provided for @azanEstimateNote.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran daripada pengiraan astronomi ({method}). Jadual rasmi e-Solat JAKIM mungkin berbeza beberapa minit; ikut jadual rasmi untuk berbuka dan imsak.'**
  String azanEstimateNote(String method);

  /// No description provided for @azanExactAlarmTitle.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan penggera tepat'**
  String get azanExactAlarmTitle;

  /// No description provided for @azanExactAlarmBody.
  ///
  /// In ms, this message translates to:
  /// **'Tanpa kebenaran ini, Android mungkin melewatkan notifikasi beberapa minit.'**
  String get azanExactAlarmBody;

  /// No description provided for @azanExactAlarmAction.
  ///
  /// In ms, this message translates to:
  /// **'Buka tetapan'**
  String get azanExactAlarmAction;

  /// No description provided for @azanPermissionDenied.
  ///
  /// In ms, this message translates to:
  /// **'Notifikasi tidak dibenarkan. Benarkan dalam tetapan telefon untuk menerima azan.'**
  String get azanPermissionDenied;

  /// No description provided for @azanReminderTitle.
  ///
  /// In ms, this message translates to:
  /// **'{prayer} dalam {n} minit'**
  String azanReminderTitle(String prayer, int n);

  /// No description provided for @azanReminderBody.
  ///
  /// In ms, this message translates to:
  /// **'Bersedia untuk solat.'**
  String get azanReminderBody;

  /// No description provided for @azanChannelFull.
  ///
  /// In ms, this message translates to:
  /// **'Azan (penuh)'**
  String get azanChannelFull;

  /// No description provided for @azanChannelShort.
  ///
  /// In ms, this message translates to:
  /// **'Azan (nada pendek)'**
  String get azanChannelShort;

  /// No description provided for @azanChannelSilent.
  ///
  /// In ms, this message translates to:
  /// **'Azan (senyap)'**
  String get azanChannelSilent;

  /// No description provided for @azanChannelReminder.
  ///
  /// In ms, this message translates to:
  /// **'Peringatan solat'**
  String get azanChannelReminder;

  /// No description provided for @azanOpenSettings.
  ///
  /// In ms, this message translates to:
  /// **'Tetapan azan'**
  String get azanOpenSettings;

  /// No description provided for @azanRemainingHours.
  ///
  /// In ms, this message translates to:
  /// **'{h} j {m} min'**
  String azanRemainingHours(int h, int m);

  /// No description provided for @azanRemainingMinutes.
  ///
  /// In ms, this message translates to:
  /// **'{m} min'**
  String azanRemainingMinutes(int m);

  /// No description provided for @azanForCity.
  ///
  /// In ms, this message translates to:
  /// **'Untuk {city}'**
  String azanForCity(String city);

  /// No description provided for @azanForCurrentLocation.
  ///
  /// In ms, this message translates to:
  /// **'Untuk lokasi semasa'**
  String get azanForCurrentLocation;

  /// No description provided for @azanNotNow.
  ///
  /// In ms, this message translates to:
  /// **'Bukan sekarang'**
  String get azanNotNow;

  /// No description provided for @settingsMusic.
  ///
  /// In ms, this message translates to:
  /// **'Muzik'**
  String get settingsMusic;

  /// No description provided for @musicTitle.
  ///
  /// In ms, this message translates to:
  /// **'Muzik'**
  String get musicTitle;

  /// No description provided for @musicOpen.
  ///
  /// In ms, this message translates to:
  /// **'Muzik'**
  String get musicOpen;

  /// No description provided for @musicSearchHint.
  ///
  /// In ms, this message translates to:
  /// **'Cari lagu, artis atau radio…'**
  String get musicSearchHint;

  /// No description provided for @musicTabSongs.
  ///
  /// In ms, this message translates to:
  /// **'Lagu'**
  String get musicTabSongs;

  /// No description provided for @musicTabRadio.
  ///
  /// In ms, this message translates to:
  /// **'Radio'**
  String get musicTabRadio;

  /// No description provided for @musicTabLocal.
  ///
  /// In ms, this message translates to:
  /// **'Fail saya'**
  String get musicTabLocal;

  /// No description provided for @musicEmptySongs.
  ///
  /// In ms, this message translates to:
  /// **'Taip nama lagu atau artis, atau ketik cadangan di atas. Katalog percuma Audius ialah muzik bebas; lagu artis label besar tiada di sini. Untuk lagu penuh artis label besar, ketik Spotify atau YouTube Music di atas untuk cari dalam app anda sendiri, atau cuba tab Radio.'**
  String get musicEmptySongs;

  /// No description provided for @musicEmptyRadio.
  ///
  /// In ms, this message translates to:
  /// **'Pilih kawasan di atas, atau taip nama stesen (cth. Hitz, Prambors, KBS). Ketik untuk dengar siaran langsung.'**
  String get musicEmptyRadio;

  /// No description provided for @musicEmptyLocal.
  ///
  /// In ms, this message translates to:
  /// **'Import lagu dari telefon anda. Ia disimpan dalam app dan sentiasa boleh dimainkan tanpa internet.'**
  String get musicEmptyLocal;

  /// No description provided for @musicNoResults.
  ///
  /// In ms, this message translates to:
  /// **'Tiada hasil untuk “{query}”.'**
  String musicNoResults(String query);

  /// No description provided for @musicOffline.
  ///
  /// In ms, this message translates to:
  /// **'Tiada internet. Hanya fail saya boleh dimainkan.'**
  String get musicOffline;

  /// No description provided for @musicErrorSource.
  ///
  /// In ms, this message translates to:
  /// **'{source} tidak dapat dihubungi sekarang.'**
  String musicErrorSource(String source);

  /// No description provided for @musicImport.
  ///
  /// In ms, this message translates to:
  /// **'Import dari telefon'**
  String get musicImport;

  /// No description provided for @musicImported.
  ///
  /// In ms, this message translates to:
  /// **'{n} lagu ditambah'**
  String musicImported(int n);

  /// No description provided for @musicRemove.
  ///
  /// In ms, this message translates to:
  /// **'Buang'**
  String get musicRemove;

  /// No description provided for @musicLive.
  ///
  /// In ms, this message translates to:
  /// **'LANGSUNG'**
  String get musicLive;

  /// No description provided for @musicViaAudius.
  ///
  /// In ms, this message translates to:
  /// **'via Audius'**
  String get musicViaAudius;

  /// No description provided for @musicAttribution.
  ///
  /// In ms, this message translates to:
  /// **'Lagu daripada Audius · Radio daripada Radio Browser · Fail anda kekal pada telefon'**
  String get musicAttribution;

  /// No description provided for @musicNowPlaying.
  ///
  /// In ms, this message translates to:
  /// **'Sedang dimainkan'**
  String get musicNowPlaying;

  /// No description provided for @musicPlay.
  ///
  /// In ms, this message translates to:
  /// **'Main'**
  String get musicPlay;

  /// No description provided for @musicPause.
  ///
  /// In ms, this message translates to:
  /// **'Jeda'**
  String get musicPause;

  /// No description provided for @musicNext.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya'**
  String get musicNext;

  /// No description provided for @musicPrevious.
  ///
  /// In ms, this message translates to:
  /// **'Sebelumnya'**
  String get musicPrevious;

  /// No description provided for @musicStop.
  ///
  /// In ms, this message translates to:
  /// **'Tutup pemain'**
  String get musicStop;

  /// No description provided for @musicVolume.
  ///
  /// In ms, this message translates to:
  /// **'Kelantangan'**
  String get musicVolume;

  /// No description provided for @musicQueue.
  ///
  /// In ms, this message translates to:
  /// **'Baris gilir'**
  String get musicQueue;

  /// No description provided for @musicEqualizer.
  ///
  /// In ms, this message translates to:
  /// **'Penyama (Equalizer)'**
  String get musicEqualizer;

  /// No description provided for @musicEqPresetNormal.
  ///
  /// In ms, this message translates to:
  /// **'Normal'**
  String get musicEqPresetNormal;

  /// No description provided for @musicEqPresetBass.
  ///
  /// In ms, this message translates to:
  /// **'Bes'**
  String get musicEqPresetBass;

  /// No description provided for @musicEqPresetTreble.
  ///
  /// In ms, this message translates to:
  /// **'Trebel'**
  String get musicEqPresetTreble;

  /// No description provided for @musicEqPresetVocal.
  ///
  /// In ms, this message translates to:
  /// **'Suara'**
  String get musicEqPresetVocal;

  /// No description provided for @musicEqPresetCustom.
  ///
  /// In ms, this message translates to:
  /// **'Tersuai'**
  String get musicEqPresetCustom;

  /// No description provided for @musicEqUnsupported.
  ///
  /// In ms, this message translates to:
  /// **'Penyama hanya tersedia pada Android.'**
  String get musicEqUnsupported;

  /// No description provided for @musicEqEnable.
  ///
  /// In ms, this message translates to:
  /// **'Hidupkan penyama'**
  String get musicEqEnable;

  /// No description provided for @musicDuckTitle.
  ///
  /// In ms, this message translates to:
  /// **'Semasa suara navigasi bercakap'**
  String get musicDuckTitle;

  /// No description provided for @musicDuckLower.
  ///
  /// In ms, this message translates to:
  /// **'Perlahankan muzik'**
  String get musicDuckLower;

  /// No description provided for @musicDuckLowerHint.
  ///
  /// In ms, this message translates to:
  /// **'Lalai. Muzik diperlahankan semasa arahan, kemudian pulih.'**
  String get musicDuckLowerHint;

  /// No description provided for @musicDuckPause.
  ///
  /// In ms, this message translates to:
  /// **'Jeda muzik'**
  String get musicDuckPause;

  /// No description provided for @musicDuckPauseHint.
  ///
  /// In ms, this message translates to:
  /// **'Muzik berhenti sepenuhnya semasa arahan, kemudian sambung.'**
  String get musicDuckPauseHint;

  /// No description provided for @musicOpenPlayer.
  ///
  /// In ms, this message translates to:
  /// **'Buka Muzik'**
  String get musicOpenPlayer;

  /// No description provided for @musicClearLocal.
  ///
  /// In ms, this message translates to:
  /// **'Padam semua fail saya'**
  String get musicClearLocal;

  /// No description provided for @musicSourceAudius.
  ///
  /// In ms, this message translates to:
  /// **'Audius'**
  String get musicSourceAudius;

  /// No description provided for @musicSourceAppleMusic.
  ///
  /// In ms, this message translates to:
  /// **'Apple Music'**
  String get musicSourceAppleMusic;

  /// No description provided for @musicViaAppleMusic.
  ///
  /// In ms, this message translates to:
  /// **'via Apple Music'**
  String get musicViaAppleMusic;

  /// No description provided for @musicAppleConnectTitle.
  ///
  /// In ms, this message translates to:
  /// **'Lagu penuh dengan Apple Music'**
  String get musicAppleConnectTitle;

  /// No description provided for @musicAppleConnectBody.
  ///
  /// In ms, this message translates to:
  /// **'Sambung langganan Apple Music anda untuk cari dan main lagu penuh Malay, Indonesia, Japan dan K-pop. Carian dan lagu terus melalui Apple; FGMaps tidak melihat akaun anda.'**
  String get musicAppleConnectBody;

  /// No description provided for @musicAppleConnect.
  ///
  /// In ms, this message translates to:
  /// **'Sambung Apple Music'**
  String get musicAppleConnect;

  /// No description provided for @musicAppleDenied.
  ///
  /// In ms, this message translates to:
  /// **'Akses Apple Music ditolak. Hidupkan di Tetapan iPhone > FGMaps > Media & Apple Music.'**
  String get musicAppleDenied;

  /// No description provided for @musicAppleNeedsSubscription.
  ///
  /// In ms, this message translates to:
  /// **'Lagu penuh perlukan langganan Apple Music yang aktif. Langgan dalam app Apple Music, kemudian buka semula tab ini.'**
  String get musicAppleNeedsSubscription;

  /// No description provided for @musicAppleUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Apple Music tidak boleh dimain dengan akaun ini.'**
  String get musicAppleUnavailable;

  /// No description provided for @musicOpenSpotify.
  ///
  /// In ms, this message translates to:
  /// **'Spotify'**
  String get musicOpenSpotify;

  /// No description provided for @musicOpenYoutubeMusic.
  ///
  /// In ms, this message translates to:
  /// **'YouTube Music'**
  String get musicOpenYoutubeMusic;

  /// No description provided for @musicExternalHint.
  ///
  /// In ms, this message translates to:
  /// **'Cari lagu penuh dalam app anda sendiri (FGMaps hanya membuka carian):'**
  String get musicExternalHint;

  /// No description provided for @musicExternalFailed.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat membuka app atau pelayar itu.'**
  String get musicExternalFailed;

  /// No description provided for @musicSourceDevice.
  ///
  /// In ms, this message translates to:
  /// **'Muzik telefon'**
  String get musicSourceDevice;

  /// No description provided for @musicViaDevice.
  ///
  /// In ms, this message translates to:
  /// **'pada telefon ini'**
  String get musicViaDevice;

  /// No description provided for @musicDeviceTitle.
  ///
  /// In ms, this message translates to:
  /// **'Muzik pada telefon'**
  String get musicDeviceTitle;

  /// No description provided for @musicDeviceBody.
  ///
  /// In ms, this message translates to:
  /// **'Mainkan lagu yang sudah ada pada telefon anda. FGMaps hanya membaca tajuk dan artis pada peranti; tiada apa-apa dihantar ke mana-mana.'**
  String get musicDeviceBody;

  /// No description provided for @musicDeviceAllow.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan akses muzik'**
  String get musicDeviceAllow;

  /// No description provided for @musicDeviceDenied.
  ///
  /// In ms, this message translates to:
  /// **'Akses muzik ditolak. Hidupkan untuk FGMaps dalam Tetapan telefon anda.'**
  String get musicDeviceDenied;

  /// No description provided for @musicSourceRadio.
  ///
  /// In ms, this message translates to:
  /// **'Radio Browser'**
  String get musicSourceRadio;

  /// No description provided for @musicSourceLocal.
  ///
  /// In ms, this message translates to:
  /// **'Fail saya'**
  String get musicSourceLocal;

  /// No description provided for @musicLoading.
  ///
  /// In ms, this message translates to:
  /// **'Memuatkan…'**
  String get musicLoading;

  /// No description provided for @musicError.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat dimainkan. Cuba lagu lain.'**
  String get musicError;

  /// No description provided for @musicDucked.
  ///
  /// In ms, this message translates to:
  /// **'Suara navigasi'**
  String get musicDucked;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In ms, this message translates to:
  /// **'Kurangkan animasi'**
  String get settingsReduceMotion;

  /// No description provided for @settingsReduceMotionHint.
  ///
  /// In ms, this message translates to:
  /// **'Kurang kesan bergerak. Turut mengikut tetapan telefon anda.'**
  String get settingsReduceMotionHint;

  /// No description provided for @settingsHaptics.
  ///
  /// In ms, this message translates to:
  /// **'Maklum balas getaran'**
  String get settingsHaptics;

  /// No description provided for @settingsLanguage.
  ///
  /// In ms, this message translates to:
  /// **'Bahasa app'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ms, this message translates to:
  /// **'Peranti'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageMalay.
  ///
  /// In ms, this message translates to:
  /// **'Bahasa Melayu'**
  String get settingsLanguageMalay;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In ms, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsVoice.
  ///
  /// In ms, this message translates to:
  /// **'Suara'**
  String get settingsVoice;

  /// No description provided for @settingsVoiceVolume.
  ///
  /// In ms, this message translates to:
  /// **'Kelantangan suara'**
  String get settingsVoiceVolume;

  /// No description provided for @settingsVolumeLow.
  ///
  /// In ms, this message translates to:
  /// **'Perlahan'**
  String get settingsVolumeLow;

  /// No description provided for @settingsVolumeMedium.
  ///
  /// In ms, this message translates to:
  /// **'Sederhana'**
  String get settingsVolumeMedium;

  /// No description provided for @settingsVolumeHigh.
  ///
  /// In ms, this message translates to:
  /// **'Kuat'**
  String get settingsVolumeHigh;

  /// No description provided for @settingsSpeechRate.
  ///
  /// In ms, this message translates to:
  /// **'Kelajuan pertuturan'**
  String get settingsSpeechRate;

  /// No description provided for @settingsRateSlow.
  ///
  /// In ms, this message translates to:
  /// **'Perlahan'**
  String get settingsRateSlow;

  /// No description provided for @settingsRateNormal.
  ///
  /// In ms, this message translates to:
  /// **'Biasa'**
  String get settingsRateNormal;

  /// No description provided for @settingsRateFast.
  ///
  /// In ms, this message translates to:
  /// **'Pantas'**
  String get settingsRateFast;

  /// No description provided for @settingsReports.
  ///
  /// In ms, this message translates to:
  /// **'Laporan'**
  String get settingsReports;

  /// No description provided for @settingsReportAlerts.
  ///
  /// In ms, this message translates to:
  /// **'Amaran laporan semasa memandu'**
  String get settingsReportAlerts;

  /// No description provided for @settingsReportAlertsHint.
  ///
  /// In ms, this message translates to:
  /// **'Mengumumkan laporan di hadapan dan bertanya jika masih ada.'**
  String get settingsReportAlertsHint;

  /// No description provided for @settingsPrivacy.
  ///
  /// In ms, this message translates to:
  /// **'Privasi'**
  String get settingsPrivacy;

  /// No description provided for @settingsLocationAllowed.
  ///
  /// In ms, this message translates to:
  /// **'Akses lokasi: dibenarkan'**
  String get settingsLocationAllowed;

  /// No description provided for @settingsLocationNotAllowed.
  ///
  /// In ms, this message translates to:
  /// **'Akses lokasi: tidak dibenarkan'**
  String get settingsLocationNotAllowed;

  /// No description provided for @settingsLocationOff.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan lokasi dimatikan'**
  String get settingsLocationOff;

  /// No description provided for @settingsLocationOpen.
  ///
  /// In ms, this message translates to:
  /// **'Buka tetapan telefon'**
  String get settingsLocationOpen;

  /// No description provided for @settingsClearHistory.
  ///
  /// In ms, this message translates to:
  /// **'Padam sejarah carian'**
  String get settingsClearHistory;

  /// No description provided for @settingsClearSaved.
  ///
  /// In ms, this message translates to:
  /// **'Padam tempat disimpan'**
  String get settingsClearSaved;

  /// No description provided for @settingsClearReports.
  ///
  /// In ms, this message translates to:
  /// **'Padam laporan saya'**
  String get settingsClearReports;

  /// No description provided for @settingsConfirmTitle.
  ///
  /// In ms, this message translates to:
  /// **'Padam data ini?'**
  String get settingsConfirmTitle;

  /// No description provided for @settingsConfirmBody.
  ///
  /// In ms, this message translates to:
  /// **'Ini hanya melibatkan telefon ini dan tidak boleh dibatalkan.'**
  String get settingsConfirmBody;

  /// No description provided for @settingsConfirmDelete.
  ///
  /// In ms, this message translates to:
  /// **'Padam'**
  String get settingsConfirmDelete;

  /// No description provided for @settingsConfirmCancel.
  ///
  /// In ms, this message translates to:
  /// **'Batal'**
  String get settingsConfirmCancel;

  /// No description provided for @settingsDeleted.
  ///
  /// In ms, this message translates to:
  /// **'Dipadam'**
  String get settingsDeleted;

  /// No description provided for @settingsHelp.
  ///
  /// In ms, this message translates to:
  /// **'Bantuan & tentang'**
  String get settingsHelp;

  /// No description provided for @settingsWelcomeAgain.
  ///
  /// In ms, this message translates to:
  /// **'Papar semula sambutan'**
  String get settingsWelcomeAgain;

  /// No description provided for @settingsLicences.
  ///
  /// In ms, this message translates to:
  /// **'Lesen sumber terbuka'**
  String get settingsLicences;

  /// No description provided for @splashTagline.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi komuniti Malaysia'**
  String get splashTagline;

  /// No description provided for @reportTitle.
  ///
  /// In ms, this message translates to:
  /// **'Laporkan di sini'**
  String get reportTitle;

  /// No description provided for @reportButtonTooltip.
  ///
  /// In ms, this message translates to:
  /// **'Laporkan'**
  String get reportButtonTooltip;

  /// No description provided for @reportTypePolice.
  ///
  /// In ms, this message translates to:
  /// **'Polis'**
  String get reportTypePolice;

  /// No description provided for @reportTypeAccident.
  ///
  /// In ms, this message translates to:
  /// **'Kemalangan'**
  String get reportTypeAccident;

  /// No description provided for @reportTypeHazard.
  ///
  /// In ms, this message translates to:
  /// **'Bahaya'**
  String get reportTypeHazard;

  /// No description provided for @reportTypeJam.
  ///
  /// In ms, this message translates to:
  /// **'Sesak'**
  String get reportTypeJam;

  /// No description provided for @reportTypeClosed.
  ///
  /// In ms, this message translates to:
  /// **'Jalan ditutup'**
  String get reportTypeClosed;

  /// No description provided for @reportTypeBrokenDown.
  ///
  /// In ms, this message translates to:
  /// **'Kenderaan rosak'**
  String get reportTypeBrokenDown;

  /// No description provided for @reportTypeFlood.
  ///
  /// In ms, this message translates to:
  /// **'Banjir'**
  String get reportTypeFlood;

  /// No description provided for @reportCreated.
  ///
  /// In ms, this message translates to:
  /// **'Laporan dihantar. Terima kasih!'**
  String get reportCreated;

  /// No description provided for @reportConfirmedExisting.
  ///
  /// In ms, this message translates to:
  /// **'Laporan serupa sudah ada berdekatan; ia disahkan.'**
  String get reportConfirmedExisting;

  /// No description provided for @reportNoLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda tidak tersedia. Laporan mesti dibuat dari lokasi sebenar anda.'**
  String get reportNoLocation;

  /// No description provided for @reportLocalOnlyNote.
  ///
  /// In ms, this message translates to:
  /// **'Laporan disimpan pada peranti ini sahaja dan belum dikongsi dengan pemandu lain.'**
  String get reportLocalOnlyNote;

  /// No description provided for @reportStillThereTitle.
  ///
  /// In ms, this message translates to:
  /// **'{type} masih ada?'**
  String reportStillThereTitle(String type);

  /// No description provided for @reportStillThereYes.
  ///
  /// In ms, this message translates to:
  /// **'Ya, masih ada'**
  String get reportStillThereYes;

  /// No description provided for @reportStillThereNo.
  ///
  /// In ms, this message translates to:
  /// **'Tiada'**
  String get reportStillThereNo;

  /// No description provided for @reportAhead.
  ///
  /// In ms, this message translates to:
  /// **'{type} {distance} di hadapan'**
  String reportAhead(String type, String distance);

  /// No description provided for @navSpeedLimit.
  ///
  /// In ms, this message translates to:
  /// **'Had laju'**
  String get navSpeedLimit;

  /// No description provided for @navOverspeedTitle.
  ///
  /// In ms, this message translates to:
  /// **'Amaran laju lebih'**
  String get navOverspeedTitle;

  /// No description provided for @navOverspeedOff.
  ///
  /// In ms, this message translates to:
  /// **'Mati'**
  String get navOverspeedOff;

  /// No description provided for @navOverspeedHint.
  ///
  /// In ms, this message translates to:
  /// **'Bunyi dan tanda merah apabila melebihi had laju. Had laju tidak lengkap di semua jalan.'**
  String get navOverspeedHint;

  /// No description provided for @savedBySearch.
  ///
  /// In ms, this message translates to:
  /// **'Cari alamat'**
  String get savedBySearch;

  /// No description provided for @savedBySearchHint.
  ///
  /// In ms, this message translates to:
  /// **'Taip nama tempat atau alamat'**
  String get savedBySearchHint;

  /// No description provided for @savedByCurrent.
  ///
  /// In ms, this message translates to:
  /// **'Guna lokasi semasa'**
  String get savedByCurrent;

  /// No description provided for @savedByCurrentHint.
  ///
  /// In ms, this message translates to:
  /// **'Simpan kedudukan anda sekarang'**
  String get savedByCurrentHint;

  /// No description provided for @savedCurrentLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi semasa'**
  String get savedCurrentLocation;

  /// No description provided for @savedLocating.
  ///
  /// In ms, this message translates to:
  /// **'Mencari lokasi anda…'**
  String get savedLocating;

  /// No description provided for @savedGoHint.
  ///
  /// In ms, this message translates to:
  /// **'Ketik untuk mula navigasi · tekan lama untuk tukar'**
  String get savedGoHint;

  /// No description provided for @autoStartCancel.
  ///
  /// In ms, this message translates to:
  /// **'Batal'**
  String get autoStartCancel;

  /// No description provided for @navThemeTitle.
  ///
  /// In ms, this message translates to:
  /// **'Paparan peta'**
  String get navThemeTitle;

  /// No description provided for @settingsSavedPlaces.
  ///
  /// In ms, this message translates to:
  /// **'Rumah dan Kerja'**
  String get settingsSavedPlaces;

  /// No description provided for @savedNotSet.
  ///
  /// In ms, this message translates to:
  /// **'Belum ditetapkan'**
  String get savedNotSet;

  /// No description provided for @autoStartCountdown.
  ///
  /// In ms, this message translates to:
  /// **'Memulakan navigasi ke {name} dalam {seconds}…'**
  String autoStartCountdown(String name, int seconds);

  /// No description provided for @routeRecommended.
  ///
  /// In ms, this message translates to:
  /// **'Disyorkan'**
  String get routeRecommended;

  /// No description provided for @routeSimplest.
  ///
  /// In ms, this message translates to:
  /// **'Paling mudah'**
  String get routeSimplest;

  /// No description provided for @routeSearchingMore.
  ///
  /// In ms, this message translates to:
  /// **'Mencari laluan lain…'**
  String get routeSearchingMore;

  /// No description provided for @routeHasHighway.
  ///
  /// In ms, this message translates to:
  /// **'Lebuh raya'**
  String get routeHasHighway;

  /// No description provided for @routeHasFerry.
  ///
  /// In ms, this message translates to:
  /// **'Feri'**
  String get routeHasFerry;

  /// No description provided for @routeTurns.
  ///
  /// In ms, this message translates to:
  /// **'{count, plural, =0{Tiada belokan} =1{1 belokan} other{{count} belokan}}'**
  String routeTurns(int count);

  /// No description provided for @routeCount.
  ///
  /// In ms, this message translates to:
  /// **'{count} laluan'**
  String routeCount(int count);

  /// No description provided for @routeMore.
  ///
  /// In ms, this message translates to:
  /// **'Lagi {count}'**
  String routeMore(int count);

  /// No description provided for @routeTollRm.
  ///
  /// In ms, this message translates to:
  /// **'RM {amount}'**
  String routeTollRm(String amount);

  /// No description provided for @routeTollRmPartial.
  ///
  /// In ms, this message translates to:
  /// **'RM {amount}+'**
  String routeTollRmPartial(String amount);

  /// No description provided for @routeTollPlazaCount.
  ///
  /// In ms, this message translates to:
  /// **'{count} plaza'**
  String routeTollPlazaCount(int count);

  /// No description provided for @routeTollEstimateExact.
  ///
  /// In ms, this message translates to:
  /// **'Tol RM {amount}'**
  String routeTollEstimateExact(String amount);

  /// No description provided for @routeTollEstimatePartial.
  ///
  /// In ms, this message translates to:
  /// **'Tol RM {amount}+ (sebahagian)'**
  String routeTollEstimatePartial(String amount);

  /// No description provided for @routeTollPlazasUnknown.
  ///
  /// In ms, this message translates to:
  /// **'{count, plural, =1{1 plaza tol} other{{count} plaza tol}}, harga tidak diketahui'**
  String routeTollPlazasUnknown(int count);

  /// No description provided for @routeTollOn.
  ///
  /// In ms, this message translates to:
  /// **'Tol: {roads}'**
  String routeTollOn(String roads);

  /// No description provided for @routeTollDisclaimer.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran untuk kereta (kelas 1) daripada kadar Lembaga Lebuhraya Malaysia; semak harga di plaza.'**
  String get routeTollDisclaimer;

  /// No description provided for @settingsClearAll.
  ///
  /// In ms, this message translates to:
  /// **'Padam semua data saya'**
  String get settingsClearAll;

  /// No description provided for @settingsClearAllHint.
  ///
  /// In ms, this message translates to:
  /// **'Sejarah carian, tempat disimpan, laporan dan data simpanan lokasi pada peranti ini.'**
  String get settingsClearAllHint;

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Dasar Privasi'**
  String get legalPrivacyTitle;

  /// No description provided for @legalTermsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Terma Penggunaan'**
  String get legalTermsTitle;

  /// No description provided for @legalLoadFailed.
  ///
  /// In ms, this message translates to:
  /// **'Dokumen tidak dapat dimuatkan.'**
  String get legalLoadFailed;

  /// No description provided for @legalDraftNotice.
  ///
  /// In ms, this message translates to:
  /// **'Draf: dokumen ini belum disemak oleh peguam dan tidak boleh dianggap nasihat undang-undang.'**
  String get legalDraftNotice;

  /// No description provided for @legalConsent.
  ///
  /// In ms, this message translates to:
  /// **'Dengan meneruskan, anda bersetuju dengan Terma Penggunaan dan Dasar Privasi.'**
  String get legalConsent;

  /// No description provided for @legalAttribution.
  ///
  /// In ms, this message translates to:
  /// **'Data peta © penyumbang OpenStreetMap (ODbL). Gaya dan jubin: OpenFreeMap, OpenMapTiles. Laluan: Valhalla. Carian: Photon (komoot) dan Nominatim. Harga petrol: data.gov.my. Waktu solat: JAKIM e-Solat melalui WaktuSolat API (api.waktusolat.app), dan pengiraan Adhan. Muzik: Audius (Open Music License), Radio Browser, dan Apple Music di iPhone (pelanggan, melalui MusicKit Apple); strim radio daripada stesen masing-masing. Rakaman azan: Aaqib Azeez / Atcovi, Wikimedia Commons, CC BY-SA 4.0.'**
  String get legalAttribution;

  /// No description provided for @aboutAttributionTitle.
  ///
  /// In ms, this message translates to:
  /// **'Sumber data'**
  String get aboutAttributionTitle;

  /// No description provided for @settingsFuel.
  ///
  /// In ms, this message translates to:
  /// **'Kos minyak'**
  String get settingsFuel;

  /// No description provided for @fuelTypeRon95.
  ///
  /// In ms, this message translates to:
  /// **'RON95'**
  String get fuelTypeRon95;

  /// No description provided for @fuelTypeRon97.
  ///
  /// In ms, this message translates to:
  /// **'RON97'**
  String get fuelTypeRon97;

  /// No description provided for @fuelTypeDiesel.
  ///
  /// In ms, this message translates to:
  /// **'Diesel'**
  String get fuelTypeDiesel;

  /// No description provided for @fuelConsumptionCar.
  ///
  /// In ms, this message translates to:
  /// **'Penggunaan kereta (L/100 km)'**
  String get fuelConsumptionCar;

  /// No description provided for @fuelConsumptionMoto.
  ///
  /// In ms, this message translates to:
  /// **'Penggunaan motosikal (L/100 km)'**
  String get fuelConsumptionMoto;

  /// No description provided for @fuelManualPrice.
  ///
  /// In ms, this message translates to:
  /// **'Harga seliter saya (RM)'**
  String get fuelManualPrice;

  /// No description provided for @fuelManualPriceHint.
  ///
  /// In ms, this message translates to:
  /// **'Kosongkan untuk guna harga data.gov.my. Isi jika harga yang anda bayar berbeza (cth. RON95 subsidi).'**
  String get fuelManualPriceHint;

  /// No description provided for @fuelPriceUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Harga terkini tidak dapat diambil. Isi harga sendiri untuk melihat anggaran kos minyak.'**
  String get fuelPriceUnavailable;

  /// No description provided for @fuelEstimateNote.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran kos minyak berdasarkan jarak, penggunaan dan harga di atas.'**
  String get fuelEstimateNote;

  /// No description provided for @shareDestinationTooltip.
  ///
  /// In ms, this message translates to:
  /// **'Kongsi destinasi'**
  String get shareDestinationTooltip;

  /// No description provided for @shareEtaAction.
  ///
  /// In ms, this message translates to:
  /// **'Kongsi masa tiba'**
  String get shareEtaAction;

  /// No description provided for @shareFailed.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat membuka lembaran kongsi.'**
  String get shareFailed;

  /// No description provided for @emergencyTooltip.
  ///
  /// In ms, this message translates to:
  /// **'Kecemasan'**
  String get emergencyTooltip;

  /// No description provided for @emergencyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Kecemasan'**
  String get emergencyTitle;

  /// No description provided for @emergencyBody.
  ///
  /// In ms, this message translates to:
  /// **'Dalam kecemasan, hubungi terus. Butang ini hanya jalan pintas dan tidak menjamin panggilan, ketepatan lokasi atau bantuan tiba.'**
  String get emergencyBody;

  /// No description provided for @emergencyCall999.
  ///
  /// In ms, this message translates to:
  /// **'Hubungi 999'**
  String get emergencyCall999;

  /// No description provided for @emergencyCall999Hint.
  ///
  /// In ms, this message translates to:
  /// **'Polis, bomba, ambulans'**
  String get emergencyCall999Hint;

  /// No description provided for @emergencyCall112.
  ///
  /// In ms, this message translates to:
  /// **'Hubungi 112'**
  String get emergencyCall112;

  /// No description provided for @emergencyCall112Hint.
  ///
  /// In ms, this message translates to:
  /// **'Nombor kecemasan antarabangsa untuk telefon bimbit'**
  String get emergencyCall112Hint;

  /// No description provided for @emergencyConfirmCall.
  ///
  /// In ms, this message translates to:
  /// **'Hubungi'**
  String get emergencyConfirmCall;

  /// No description provided for @emergencyConfirmBody.
  ///
  /// In ms, this message translates to:
  /// **'Papan nombor akan dibuka. Tekan butang panggil untuk menyambung.'**
  String get emergencyConfirmBody;

  /// No description provided for @emergencyShareLocation.
  ///
  /// In ms, this message translates to:
  /// **'Kongsi lokasi tepat saya'**
  String get emergencyShareLocation;

  /// No description provided for @emergencyNoLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda belum diketahui. Cuba di tempat terbuka atau hidupkan lokasi.'**
  String get emergencyNoLocation;

  /// No description provided for @routeFuelCost.
  ///
  /// In ms, this message translates to:
  /// **'≈ RM {amount} minyak'**
  String routeFuelCost(String amount);

  /// No description provided for @fuelPriceSource.
  ///
  /// In ms, this message translates to:
  /// **'Harga data.gov.my: RM {price}/L ({date})'**
  String fuelPriceSource(String price, String date);

  /// No description provided for @emergencyConfirmTitle.
  ///
  /// In ms, this message translates to:
  /// **'Hubungi {number} sekarang?'**
  String emergencyConfirmTitle(String number);

  /// No description provided for @shareDestinationText.
  ///
  /// In ms, this message translates to:
  /// **'Saya menuju ke {name}. Anggaran tiba {eta} ({duration}, {distance}).\n{link}'**
  String shareDestinationText(
    String name,
    String eta,
    String duration,
    String distance,
    String link,
  );

  /// No description provided for @shareEtaText.
  ///
  /// In ms, this message translates to:
  /// **'Saya sedang menuju ke {name}. Anggaran tiba {eta}, baki {distance}.\n{link}'**
  String shareEtaText(String name, String eta, String distance, String link);

  /// No description provided for @emergencyShareText.
  ///
  /// In ms, this message translates to:
  /// **'Saya memerlukan bantuan. Lokasi saya: {coords}\n{link}'**
  String emergencyShareText(String coords, String link);

  /// No description provided for @emergencyDialFailed.
  ///
  /// In ms, this message translates to:
  /// **'Papan nombor tidak dapat dibuka. Dail {number} secara manual.'**
  String emergencyDialFailed(String number);

  /// No description provided for @errorWidgetMessage.
  ///
  /// In ms, this message translates to:
  /// **'Bahagian ini tidak dapat dipaparkan.'**
  String get errorWidgetMessage;

  /// No description provided for @settingsCopyErrorReport.
  ///
  /// In ms, this message translates to:
  /// **'Salin laporan ralat'**
  String get settingsCopyErrorReport;

  /// No description provided for @settingsCopyErrorReportHint.
  ///
  /// In ms, this message translates to:
  /// **'Log ralat disimpan pada telefon ini sahaja dan tidak dihantar. Salin dan hantar sendiri jika perlu.'**
  String get settingsCopyErrorReportHint;

  /// No description provided for @settingsErrorReportCopied.
  ///
  /// In ms, this message translates to:
  /// **'Laporan ralat disalin'**
  String get settingsErrorReportCopied;

  /// No description provided for @settingsErrorReportEmpty.
  ///
  /// In ms, this message translates to:
  /// **'Tiada ralat direkodkan'**
  String get settingsErrorReportEmpty;

  /// No description provided for @azanEnabledSnack.
  ///
  /// In ms, this message translates to:
  /// **'Azan dihidupkan. {source}'**
  String azanEnabledSnack(String source);

  /// No description provided for @azanSourceOfficial.
  ///
  /// In ms, this message translates to:
  /// **'Waktu rasmi JAKIM e-Solat, zon {zone}'**
  String azanSourceOfficial(String zone);

  /// No description provided for @azanSourceCalculated.
  ///
  /// In ms, this message translates to:
  /// **'Dikira pada telefon ({method})'**
  String azanSourceCalculated(String method);

  /// No description provided for @azanDeniedTitle.
  ///
  /// In ms, this message translates to:
  /// **'Notifikasi dimatikan'**
  String get azanDeniedTitle;

  /// No description provided for @azanDeniedBody.
  ///
  /// In ms, this message translates to:
  /// **'Tanpa kebenaran notifikasi, azan tidak boleh berbunyi apabila app ditutup. Buka tetapan dan benarkan notifikasi untuk FGMaps.'**
  String get azanDeniedBody;

  /// No description provided for @azanOpenAppSettings.
  ///
  /// In ms, this message translates to:
  /// **'Buka tetapan'**
  String get azanOpenAppSettings;

  /// No description provided for @azanExactDialogTitle.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan penggera tepat'**
  String get azanExactDialogTitle;

  /// No description provided for @azanExactDialogBody.
  ///
  /// In ms, this message translates to:
  /// **'Supaya azan berbunyi tepat pada waktunya dan bukan lewat beberapa minit, benarkan “Penggera & peringatan” untuk FGMaps pada skrin seterusnya.'**
  String get azanExactDialogBody;

  /// No description provided for @azanNotificationsOffTitle.
  ///
  /// In ms, this message translates to:
  /// **'Notifikasi azan dimatikan'**
  String get azanNotificationsOffTitle;

  /// No description provided for @azanNotificationsOffBody.
  ///
  /// In ms, this message translates to:
  /// **'Azan tidak akan berbunyi apabila app ditutup sehingga anda membenarkan notifikasi semula.'**
  String get azanNotificationsOffBody;

  /// No description provided for @azanBatteryTitle.
  ///
  /// In ms, this message translates to:
  /// **'Pastikan azan berbunyi apabila app ditutup'**
  String get azanBatteryTitle;

  /// No description provided for @azanBatteryBody.
  ///
  /// In ms, this message translates to:
  /// **'Sesetengah telefon menghentikan app di latar belakang. Jika azan tidak berbunyi, benarkan FGMaps berjalan di latar belakang.'**
  String get azanBatteryBody;

  /// No description provided for @azanBatteryAction.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan di latar belakang'**
  String get azanBatteryAction;

  /// No description provided for @azanBatteryList.
  ///
  /// In ms, this message translates to:
  /// **'Buka senarai bateri'**
  String get azanBatteryList;

  /// No description provided for @azanBatteryListHint.
  ///
  /// In ms, this message translates to:
  /// **'Atau buka senarai bateri: tukar penapis atas daripada “Not optimized” kepada “All apps”, kemudian pilih FGMaps dan “Don’t optimize”.'**
  String get azanBatteryListHint;

  /// No description provided for @azanLocationUnknown.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi belum diketahui. Waktu dikira untuk Kuala Lumpur. Benarkan lokasi atau pilih bandar di bawah.'**
  String get azanLocationUnknown;

  /// No description provided for @azanUseOfficial.
  ///
  /// In ms, this message translates to:
  /// **'Waktu rasmi JAKIM'**
  String get azanUseOfficial;

  /// No description provided for @azanUseOfficialHint.
  ///
  /// In ms, this message translates to:
  /// **'Ambil jadual e-Solat rasmi melalui internet (hanya lokasi ~1 km dihantar). Tanpa talian, waktu dikira pada telefon.'**
  String get azanUseOfficialHint;

  /// No description provided for @onbAzan.
  ///
  /// In ms, this message translates to:
  /// **'Ingatkan waktu azan'**
  String get onbAzan;

  /// No description provided for @onbAzanHint.
  ///
  /// In ms, this message translates to:
  /// **'Notifikasi dan azan pada setiap waktu solat, walaupun app ditutup. Kami akan minta kebenaran notifikasi.'**
  String get onbAzanHint;

  /// No description provided for @musicRegionMalaysia.
  ///
  /// In ms, this message translates to:
  /// **'Malaysia'**
  String get musicRegionMalaysia;

  /// No description provided for @musicRegionIndonesia.
  ///
  /// In ms, this message translates to:
  /// **'Indonesia'**
  String get musicRegionIndonesia;

  /// No description provided for @musicRegionFavorites.
  ///
  /// In ms, this message translates to:
  /// **'Kegemaran'**
  String get musicRegionFavorites;

  /// No description provided for @musicEmptyFavorites.
  ///
  /// In ms, this message translates to:
  /// **'Belum ada stesen kegemaran. Ketik bintang pada mana-mana stesen untuk simpan di sini.'**
  String get musicEmptyFavorites;

  /// No description provided for @musicFavoriteAdd.
  ///
  /// In ms, this message translates to:
  /// **'Tambah ke kegemaran'**
  String get musicFavoriteAdd;

  /// No description provided for @musicFavoriteRemove.
  ///
  /// In ms, this message translates to:
  /// **'Buang daripada kegemaran'**
  String get musicFavoriteRemove;

  /// No description provided for @musicRadioUnreachable.
  ///
  /// In ms, this message translates to:
  /// **'Gagal disambung tadi'**
  String get musicRadioUnreachable;

  /// No description provided for @musicRegionJapan.
  ///
  /// In ms, this message translates to:
  /// **'Japan'**
  String get musicRegionJapan;

  /// No description provided for @musicRegionJpop.
  ///
  /// In ms, this message translates to:
  /// **'J-pop'**
  String get musicRegionJpop;

  /// No description provided for @musicRegionKorea.
  ///
  /// In ms, this message translates to:
  /// **'Korea'**
  String get musicRegionKorea;

  /// No description provided for @musicRegionKpop.
  ///
  /// In ms, this message translates to:
  /// **'K-pop'**
  String get musicRegionKpop;

  /// No description provided for @musicNoResultsSongsHint.
  ///
  /// In ms, this message translates to:
  /// **'Katalog percuma Audius ialah muzik bebas; lagu artis label besar tiada di sini. Ketik Spotify atau YouTube Music di atas untuk cari dalam app anda sendiri, atau cuba Radio.'**
  String get musicNoResultsSongsHint;

  /// No description provided for @musicTryRadio.
  ///
  /// In ms, this message translates to:
  /// **'Cari dalam Radio'**
  String get musicTryRadio;

  /// No description provided for @aboutWhatsNewTitle.
  ///
  /// In ms, this message translates to:
  /// **'Baharu dalam versi {version}'**
  String aboutWhatsNewTitle(String version);

  /// No description provided for @aboutNew1.
  ///
  /// In ms, this message translates to:
  /// **'FG AI lebih faham ayat harian dan bahasa pasar. Cari 23 jenis tempat (farmasi, kedai gunting, ATM, hotel dan lagi) dengan kad jarak dan butang Pergi'**
  String get aboutNew1;

  /// No description provided for @aboutNew2.
  ///
  /// In ms, this message translates to:
  /// **'FG AI jawab soalan terkini dari web percuma: berita, kadar tukaran BNM dan harga minyak. Boleh dimatikan dalam Tetapan'**
  String get aboutNew2;

  /// No description provided for @aboutNew3.
  ///
  /// In ms, this message translates to:
  /// **'FG AI boleh menekan butang dalam app untuk anda. Mod Lite kurangkan animasi dan bangunan 3D pada telefon yang perlahan'**
  String get aboutNew3;

  /// No description provided for @aboutNew4.
  ///
  /// In ms, this message translates to:
  /// **'Kotak lorong dan anak panah arah di peta semasa memandu'**
  String get aboutNew4;

  /// No description provided for @aboutNew5.
  ///
  /// In ms, this message translates to:
  /// **'Android Auto: butang Berdekatan, carian suara dalam ayat biasa, waktu solat dan lorong sebenar'**
  String get aboutNew5;

  /// No description provided for @aboutNew6.
  ///
  /// In ms, this message translates to:
  /// **'Carian tempat di Malaysia lebih tepat dan lebih laju'**
  String get aboutNew6;

  /// No description provided for @alongRouteTitle.
  ///
  /// In ms, this message translates to:
  /// **'Sepanjang laluan'**
  String get alongRouteTitle;

  /// No description provided for @alongRouteDisclaimer.
  ///
  /// In ms, this message translates to:
  /// **'Data OpenStreetMap; mungkin tak lengkap.'**
  String get alongRouteDisclaimer;

  /// No description provided for @alongRouteUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Tidak dapat memuatkan tempat sepanjang laluan. Cuba lagi kemudian.'**
  String get alongRouteUnavailable;

  /// No description provided for @alongRouteEmpty.
  ///
  /// In ms, this message translates to:
  /// **'Tiada tempat dijumpai sepanjang laluan untuk kategori ini.'**
  String get alongRouteEmpty;

  /// No description provided for @alongRouteIn.
  ///
  /// In ms, this message translates to:
  /// **'Dalam {distance}'**
  String alongRouteIn(String distance);

  /// No description provided for @alongRouteRr.
  ///
  /// In ms, this message translates to:
  /// **'R&R'**
  String get alongRouteRr;

  /// No description provided for @alongRouteFuel.
  ///
  /// In ms, this message translates to:
  /// **'Minyak'**
  String get alongRouteFuel;

  /// No description provided for @alongRouteMosque.
  ///
  /// In ms, this message translates to:
  /// **'Surau'**
  String get alongRouteMosque;

  /// No description provided for @alongRouteToilets.
  ///
  /// In ms, this message translates to:
  /// **'Tandas'**
  String get alongRouteToilets;

  /// No description provided for @alongRouteAddStop.
  ///
  /// In ms, this message translates to:
  /// **'Tambah sebagai perhentian'**
  String get alongRouteAddStop;

  /// No description provided for @alongRouteAddedStop.
  ///
  /// In ms, this message translates to:
  /// **'Ditambah sebagai perhentian — mengira semula laluan'**
  String get alongRouteAddedStop;

  /// No description provided for @tripHistoryExport.
  ///
  /// In ms, this message translates to:
  /// **'Eksport JSON'**
  String get tripHistoryExport;

  /// No description provided for @tripHistoryExported.
  ///
  /// In ms, this message translates to:
  /// **'Sejarah perjalanan disalin'**
  String get tripHistoryExported;

  /// No description provided for @tripHistoryRetentionDays.
  ///
  /// In ms, this message translates to:
  /// **'{days} hari'**
  String tripHistoryRetentionDays(int days);

  /// No description provided for @tripHistoryRetentionForever.
  ///
  /// In ms, this message translates to:
  /// **'Selamanya'**
  String get tripHistoryRetentionForever;

  /// No description provided for @tripHistoryRetentionOff.
  ///
  /// In ms, this message translates to:
  /// **'Mati'**
  String get tripHistoryRetentionOff;

  /// No description provided for @pickingStopHint.
  ///
  /// In ms, this message translates to:
  /// **'Pilih perhentian, kemudian pilih destinasi'**
  String get pickingStopHint;

  /// No description provided for @cameraAwasAhead.
  ///
  /// In ms, this message translates to:
  /// **'Kamera AwAS di hadapan — patuhi had laju'**
  String get cameraAwasAhead;

  /// No description provided for @cameraOsmAhead.
  ///
  /// In ms, this message translates to:
  /// **'Kamera (OSM) di hadapan — patuhi had laju'**
  String get cameraOsmAhead;

  /// No description provided for @settingsCameras.
  ///
  /// In ms, this message translates to:
  /// **'Amaran kamera'**
  String get settingsCameras;

  /// No description provided for @settingsCamerasHint.
  ///
  /// In ms, this message translates to:
  /// **'Amaran AwAS rasmi (JPJ). Bukan semua kamera Malaysia.'**
  String get settingsCamerasHint;

  /// No description provided for @settingsCamerasOsm.
  ///
  /// In ms, this message translates to:
  /// **'Termasuk kamera OSM'**
  String get settingsCamerasOsm;

  /// No description provided for @settingsCamerasOsmHint.
  ///
  /// In ms, this message translates to:
  /// **'Data komuniti; mungkin tak lengkap atau usang.'**
  String get settingsCamerasOsmHint;

  /// No description provided for @settingsCamerasDistance.
  ///
  /// In ms, this message translates to:
  /// **'Jarak amaran'**
  String get settingsCamerasDistance;

  /// No description provided for @addStop.
  ///
  /// In ms, this message translates to:
  /// **'Tambah perhentian'**
  String get addStop;

  /// No description provided for @stopsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Perhentian'**
  String get stopsTitle;

  /// No description provided for @removeStop.
  ///
  /// In ms, this message translates to:
  /// **'Buang perhentian'**
  String get removeStop;

  /// No description provided for @nextStop.
  ///
  /// In ms, this message translates to:
  /// **'Perhentian seterusnya'**
  String get nextStop;

  /// No description provided for @skipStop.
  ///
  /// In ms, this message translates to:
  /// **'Langkau perhentian'**
  String get skipStop;

  /// No description provided for @tripHistoryTitle.
  ///
  /// In ms, this message translates to:
  /// **'Perjalanan'**
  String get tripHistoryTitle;

  /// No description provided for @tripHistoryEmpty.
  ///
  /// In ms, this message translates to:
  /// **'Belum ada perjalanan tersimpan.'**
  String get tripHistoryEmpty;

  /// No description provided for @tripHistoryMonth.
  ///
  /// In ms, this message translates to:
  /// **'Bulan ini'**
  String get tripHistoryMonth;

  /// No description provided for @tripHistoryKm.
  ///
  /// In ms, this message translates to:
  /// **'{km} km'**
  String tripHistoryKm(String km);

  /// No description provided for @tripHistoryDuration.
  ///
  /// In ms, this message translates to:
  /// **'{hours} j {mins} min'**
  String tripHistoryDuration(int hours, int mins);

  /// No description provided for @tripHistoryToll.
  ///
  /// In ms, this message translates to:
  /// **'Tol ~RM {amount}'**
  String tripHistoryToll(String amount);

  /// No description provided for @tripHistoryTrips.
  ///
  /// In ms, this message translates to:
  /// **'{count} perjalanan'**
  String tripHistoryTrips(int count);

  /// No description provided for @tripHistoryRetention.
  ///
  /// In ms, this message translates to:
  /// **'Simpan sejarah'**
  String get tripHistoryRetention;

  /// No description provided for @tripHistoryDeleteAll.
  ///
  /// In ms, this message translates to:
  /// **'Padam semua perjalanan'**
  String get tripHistoryDeleteAll;

  /// No description provided for @weatherTitle.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca'**
  String get weatherTitle;

  /// No description provided for @weatherAttribution.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca: Open-Meteo · lokasi GPS'**
  String get weatherAttribution;

  /// No description provided for @weatherUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca tidak tersedia'**
  String get weatherUnavailable;

  /// No description provided for @weatherRainAlong.
  ///
  /// In ms, this message translates to:
  /// **'Hujan dijangka sepanjang laluan'**
  String get weatherRainAlong;

  /// No description provided for @weatherSevere.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca buruk dijangka — pandu berhati-hati'**
  String get weatherSevere;

  /// No description provided for @weatherHere.
  ///
  /// In ms, this message translates to:
  /// **'Di sini'**
  String get weatherHere;

  /// No description provided for @weatherAtDestination.
  ///
  /// In ms, this message translates to:
  /// **'Destinasi'**
  String get weatherAtDestination;

  /// No description provided for @weatherFeelsLike.
  ///
  /// In ms, this message translates to:
  /// **'Rasa'**
  String get weatherFeelsLike;

  /// No description provided for @weatherCached.
  ///
  /// In ms, this message translates to:
  /// **'Cache'**
  String get weatherCached;

  /// No description provided for @settingsWeather.
  ///
  /// In ms, this message translates to:
  /// **'Amaran cuaca'**
  String get settingsWeather;

  /// No description provided for @settingsWeatherHint.
  ///
  /// In ms, this message translates to:
  /// **'Banner hujan lebat semasa navigasi'**
  String get settingsWeatherHint;

  /// No description provided for @settingsAlongRouteAnnounce.
  ///
  /// In ms, this message translates to:
  /// **'Umumkan R&R / minyak'**
  String get settingsAlongRouteAnnounce;

  /// No description provided for @settingsAlongRouteAnnounceHint.
  ///
  /// In ms, this message translates to:
  /// **'Suara bila R&R atau stesen minyak di hadapan (chip tetap dipaparkan)'**
  String get settingsAlongRouteAnnounceHint;

  /// No description provided for @airQualityTitle.
  ///
  /// In ms, this message translates to:
  /// **'Kualiti udara (IPU)'**
  String get airQualityTitle;

  /// No description provided for @airQualityOpen.
  ///
  /// In ms, this message translates to:
  /// **'Kualiti udara'**
  String get airQualityOpen;

  /// No description provided for @airQualityDisclaimer.
  ///
  /// In ms, this message translates to:
  /// **'Indeks Pencemar Udara rasmi daripada stesen pemantauan JAS yang terdekat.'**
  String get airQualityDisclaimer;

  /// No description provided for @airQualityHere.
  ///
  /// In ms, this message translates to:
  /// **'Di sini'**
  String get airQualityHere;

  /// No description provided for @airQualitySearchHint.
  ///
  /// In ms, this message translates to:
  /// **'Cari tempat lain'**
  String get airQualitySearchHint;

  /// No description provided for @airQualityUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'IPU tidak tersedia. Semak sambungan, kemudian cuba lagi.'**
  String get airQualityUnavailable;

  /// No description provided for @airQualityCached.
  ///
  /// In ms, this message translates to:
  /// **'Cache'**
  String get airQualityCached;

  /// No description provided for @airQualityAttribution.
  ///
  /// In ms, this message translates to:
  /// **'Sumber: Jabatan Alam Sekitar (APIMS/EQMS)'**
  String get airQualityAttribution;

  /// No description provided for @airQualityStation.
  ///
  /// In ms, this message translates to:
  /// **'Stesen: {name} · {distance}'**
  String airQualityStation(String name, String distance);

  /// No description provided for @airQualityRouteAlert.
  ///
  /// In ms, this message translates to:
  /// **'IPU tinggi sepanjang laluan — {name} · {ipu}'**
  String airQualityRouteAlert(String name, int ipu);

  /// No description provided for @airBandGood.
  ///
  /// In ms, this message translates to:
  /// **'Baik'**
  String get airBandGood;

  /// No description provided for @airBandModerate.
  ///
  /// In ms, this message translates to:
  /// **'Sederhana'**
  String get airBandModerate;

  /// No description provided for @airBandUnhealthy.
  ///
  /// In ms, this message translates to:
  /// **'Tidak sihat'**
  String get airBandUnhealthy;

  /// No description provided for @airBandVeryUnhealthy.
  ///
  /// In ms, this message translates to:
  /// **'Sangat tidak sihat'**
  String get airBandVeryUnhealthy;

  /// No description provided for @airBandHazardous.
  ///
  /// In ms, this message translates to:
  /// **'Berbahaya'**
  String get airBandHazardous;

  /// No description provided for @airQualityScale.
  ///
  /// In ms, this message translates to:
  /// **'Skala rasmi JAS'**
  String get airQualityScale;

  /// No description provided for @airQualityDominant.
  ///
  /// In ms, this message translates to:
  /// **'Pencemar dominan: {name}'**
  String airQualityDominant(String name);

  /// No description provided for @airQualityObserved.
  ///
  /// In ms, this message translates to:
  /// **'Bacaan {time}'**
  String airQualityObserved(String time);

  /// No description provided for @airPollutantPm25.
  ///
  /// In ms, this message translates to:
  /// **'PM2.5'**
  String get airPollutantPm25;

  /// No description provided for @airPollutantPm10.
  ///
  /// In ms, this message translates to:
  /// **'PM10'**
  String get airPollutantPm10;

  /// No description provided for @airPollutantSo2.
  ///
  /// In ms, this message translates to:
  /// **'SO₂'**
  String get airPollutantSo2;

  /// No description provided for @airPollutantNo2.
  ///
  /// In ms, this message translates to:
  /// **'NO₂'**
  String get airPollutantNo2;

  /// No description provided for @airPollutantO3.
  ///
  /// In ms, this message translates to:
  /// **'Ozon'**
  String get airPollutantO3;

  /// No description provided for @airPollutantCo.
  ///
  /// In ms, this message translates to:
  /// **'CO'**
  String get airPollutantCo;

  /// No description provided for @airPollutantSeveral.
  ///
  /// In ms, this message translates to:
  /// **'Lebih daripada satu'**
  String get airPollutantSeveral;

  /// No description provided for @airAdviceGood.
  ///
  /// In ms, this message translates to:
  /// **'Sesuai untuk aktiviti luar. Tiada kesan kesihatan.'**
  String get airAdviceGood;

  /// No description provided for @airAdviceModerate.
  ///
  /// In ms, this message translates to:
  /// **'Sesuai untuk aktiviti luar.'**
  String get airAdviceModerate;

  /// No description provided for @airAdviceUnhealthy.
  ///
  /// In ms, this message translates to:
  /// **'Kurangkan aktiviti luar yang lama. Kumpulan sensitif mungkin terjejas.'**
  String get airAdviceUnhealthy;

  /// No description provided for @airAdviceVeryUnhealthy.
  ///
  /// In ms, this message translates to:
  /// **'Elakkan aktiviti luar. Semua orang mungkin terjejas.'**
  String get airAdviceVeryUnhealthy;

  /// No description provided for @airAdviceHazardous.
  ///
  /// In ms, this message translates to:
  /// **'Kecemasan kesihatan. Tinggal di dalam bangunan.'**
  String get airAdviceHazardous;

  /// No description provided for @alongRouteEv.
  ///
  /// In ms, this message translates to:
  /// **'Pengecas EV'**
  String get alongRouteEv;

  /// No description provided for @qiblaTitle.
  ///
  /// In ms, this message translates to:
  /// **'Kiblat'**
  String get qiblaTitle;

  /// No description provided for @assistantOpen.
  ///
  /// In ms, this message translates to:
  /// **'Pembantu'**
  String get assistantOpen;

  /// No description provided for @assistantTitle.
  ///
  /// In ms, this message translates to:
  /// **'FG AI'**
  String get assistantTitle;

  /// No description provided for @assistantHint.
  ///
  /// In ms, this message translates to:
  /// **'Sembang umum dalam telefon serta alat peta (tempat, IPU, cuaca, laluan). Model dimuat turun sekali dan kekal di peranti.'**
  String get assistantHint;

  /// No description provided for @assistantInputHint.
  ///
  /// In ms, this message translates to:
  /// **'Tanya apa-apa atau beri arahan…'**
  String get assistantInputHint;

  /// No description provided for @assistantClearChat.
  ///
  /// In ms, this message translates to:
  /// **'Padam sembang'**
  String get assistantClearChat;

  /// No description provided for @assistantDownloadTitle.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun model tempatan'**
  String get assistantDownloadTitle;

  /// No description provided for @assistantDownloadBody.
  ///
  /// In ms, this message translates to:
  /// **'Qwen3 0.6B (~345 MB). Berjalan pada telefon; tiada kunci cloud. Wi‑Fi digalakkan.'**
  String get assistantDownloadBody;

  /// No description provided for @assistantDownloadAction.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun'**
  String get assistantDownloadAction;

  /// No description provided for @assistantDownloading.
  ///
  /// In ms, this message translates to:
  /// **'Memuat turun… {percent}%'**
  String assistantDownloading(int percent);

  /// No description provided for @assistantSettingsTitle.
  ///
  /// In ms, this message translates to:
  /// **'FG AI'**
  String get assistantSettingsTitle;

  /// No description provided for @assistantSettingsReady.
  ///
  /// In ms, this message translates to:
  /// **'Model sedia pada telefon ini.'**
  String get assistantSettingsReady;

  /// No description provided for @assistantSettingsMissing.
  ///
  /// In ms, this message translates to:
  /// **'Belum dimuat turun. Pilihan; tanpa model, ciri lain kekal berfungsi.'**
  String get assistantSettingsMissing;

  /// No description provided for @assistantDeleteModel.
  ///
  /// In ms, this message translates to:
  /// **'Padam model'**
  String get assistantDeleteModel;

  /// No description provided for @assistantModeFgmaps.
  ///
  /// In ms, this message translates to:
  /// **'FG AI'**
  String get assistantModeFgmaps;

  /// No description provided for @assistantModeMuslim.
  ///
  /// In ms, this message translates to:
  /// **'FGMuslim'**
  String get assistantModeMuslim;

  /// No description provided for @assistantEmptyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tanya apa-apa — peta, cuaca, atau soalan umum'**
  String get assistantEmptyTitle;

  /// No description provided for @assistantSuggestRoute.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ke KLCC'**
  String get assistantSuggestRoute;

  /// No description provided for @assistantSuggestIpu.
  ///
  /// In ms, this message translates to:
  /// **'IPU berhampiran'**
  String get assistantSuggestIpu;

  /// No description provided for @assistantSuggestGeneral.
  ///
  /// In ms, this message translates to:
  /// **'Jelaskan tol di MY'**
  String get assistantSuggestGeneral;

  /// No description provided for @muslimAiTitle.
  ///
  /// In ms, this message translates to:
  /// **'FGMuslim AI'**
  String get muslimAiTitle;

  /// No description provided for @muslimAiHint.
  ///
  /// In ms, this message translates to:
  /// **'Jawapan berpetikan teks klasik (islamic.app) serta pautan fatwa (deen.ai). Bukan nasihat JAKIM. Wallahu a\'lam.'**
  String get muslimAiHint;

  /// No description provided for @muslimAiInputHint.
  ///
  /// In ms, this message translates to:
  /// **'Tanya tentang Quran, hadis, atau fiqh…'**
  String get muslimAiInputHint;

  /// No description provided for @muslimAiGateTitle.
  ///
  /// In ms, this message translates to:
  /// **'Untuk Muslim yang memilih untuk aktifkan'**
  String get muslimAiGateTitle;

  /// No description provided for @muslimAiGateBody.
  ///
  /// In ms, this message translates to:
  /// **'FGMuslim AI guna sumber pihak ketiga berpetikan. Setuju syarat dulu — ini bukan autoriti agama rasmi.'**
  String get muslimAiGateBody;

  /// No description provided for @muslimAiEnableAction.
  ///
  /// In ms, this message translates to:
  /// **'Baca syarat & aktifkan'**
  String get muslimAiEnableAction;

  /// No description provided for @muslimAiEmptyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tanya dengan petikan — teks klasik dahulu'**
  String get muslimAiEmptyTitle;

  /// No description provided for @muslimAiSuggestZakat.
  ///
  /// In ms, this message translates to:
  /// **'Apa kata Islam tentang zakat?'**
  String get muslimAiSuggestZakat;

  /// No description provided for @muslimAiSuggestSolat.
  ///
  /// In ms, this message translates to:
  /// **'Apa itu sabar (sabr) dalam Islam?'**
  String get muslimAiSuggestSolat;

  /// No description provided for @muslimAiSuggestRiba.
  ///
  /// In ms, this message translates to:
  /// **'Apa itu riba?'**
  String get muslimAiSuggestRiba;

  /// No description provided for @muslimAiSettingsTitle.
  ///
  /// In ms, this message translates to:
  /// **'FGMuslim AI'**
  String get muslimAiSettingsTitle;

  /// No description provided for @muslimAiSettingsOn.
  ///
  /// In ms, this message translates to:
  /// **'Hidup — petikan islamic.app + deen.ai (opt-in).'**
  String get muslimAiSettingsOn;

  /// No description provided for @muslimAiSettingsOff.
  ///
  /// In ms, this message translates to:
  /// **'Mati. Pilihan; untuk pengguna Muslim selepas bersetuju syarat.'**
  String get muslimAiSettingsOff;

  /// No description provided for @muslimAiTermsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Syarat FGMuslim AI'**
  String get muslimAiTermsTitle;

  /// No description provided for @muslimAiTermsLead.
  ///
  /// In ms, this message translates to:
  /// **'Sila baca teliti. Topik agama di Malaysia sensitif. Tandakan setiap kotak untuk teruskan.'**
  String get muslimAiTermsLead;

  /// No description provided for @muslimAiTermsMuslim.
  ///
  /// In ms, this message translates to:
  /// **'Saya Muslim (atau mencari rujukan Islam untuk pembelajaran peribadi) dan memilih untuk mengaktifkan ciri pilihan ini.'**
  String get muslimAiTermsMuslim;

  /// No description provided for @muslimAiTermsNotOfficial.
  ///
  /// In ms, this message translates to:
  /// **'Saya faham FGMuslim AI BUKAN fatwa rasmi JAKIM, pejabat mufti negeri, atau FGMaps.'**
  String get muslimAiTermsNotOfficial;

  /// No description provided for @muslimAiTermsNotAdvice.
  ///
  /// In ms, this message translates to:
  /// **'Saya tidak akan anggap jawapan sebagai nasihat agama, undang-undang, atau perubatan peribadi. Untuk situasi saya, saya akan rujuk ulama yang berkelayakan.'**
  String get muslimAiTermsNotAdvice;

  /// No description provided for @muslimAiTermsThirdParty.
  ///
  /// In ms, this message translates to:
  /// **'Saya faham soalan dihantar ke islamic.app dan deen.ai (pihak ketiga). Jawapan mungkin tidak lengkap, berat sebelah, atau silap; saya akan semak petikan.'**
  String get muslimAiTermsThirdParty;

  /// No description provided for @muslimAiTermsHoldHarmless.
  ///
  /// In ms, this message translates to:
  /// **'Saya bersetuju FGMaps dan penulisnya tidak bertanggungjawab atas cara saya guna atau tafsir kandungan ini.'**
  String get muslimAiTermsHoldHarmless;

  /// No description provided for @muslimAiTermsAgree.
  ///
  /// In ms, this message translates to:
  /// **'Saya setuju — aktifkan FGMuslim AI'**
  String get muslimAiTermsAgree;

  /// No description provided for @muslimAiTermsCancel.
  ///
  /// In ms, this message translates to:
  /// **'Batal'**
  String get muslimAiTermsCancel;

  /// No description provided for @muslimAiOpenDeen.
  ///
  /// In ms, this message translates to:
  /// **'Buka islamic.app'**
  String get muslimAiOpenDeen;

  /// No description provided for @qiblaOpen.
  ///
  /// In ms, this message translates to:
  /// **'Kiblat'**
  String get qiblaOpen;

  /// No description provided for @qiblaDegrees.
  ///
  /// In ms, this message translates to:
  /// **'{degrees}° dari utara'**
  String qiblaDegrees(String degrees);

  /// No description provided for @qiblaHint.
  ///
  /// In ms, this message translates to:
  /// **'Halakan bahagian atas telefon ke ikon Kaabah.'**
  String get qiblaHint;

  /// No description provided for @qiblaFacing.
  ///
  /// In ms, this message translates to:
  /// **'Tepat ke arah kiblat'**
  String get qiblaFacing;

  /// No description provided for @qiblaTurnRight.
  ///
  /// In ms, this message translates to:
  /// **'Pusing ke kanan {degrees}°'**
  String qiblaTurnRight(String degrees);

  /// No description provided for @qiblaTurnLeft.
  ///
  /// In ms, this message translates to:
  /// **'Pusing ke kiri {degrees}°'**
  String qiblaTurnLeft(String degrees);

  /// No description provided for @qiblaWaitingSensor.
  ///
  /// In ms, this message translates to:
  /// **'Menyediakan kompas…'**
  String get qiblaWaitingSensor;

  /// No description provided for @qiblaLocating.
  ///
  /// In ms, this message translates to:
  /// **'Mencari lokasi anda…'**
  String get qiblaLocating;

  /// No description provided for @qiblaNoSensor.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sensor kompas pada telefon ini. Dail hanya mengikut arah perjalanan apabila anda bergerak.'**
  String get qiblaNoSensor;

  /// No description provided for @qiblaDirectionLabel.
  ///
  /// In ms, this message translates to:
  /// **'Arah kiblat'**
  String get qiblaDirectionLabel;

  /// No description provided for @qiblaDistanceLabel.
  ///
  /// In ms, this message translates to:
  /// **'Jarak ke Kaabah'**
  String get qiblaDistanceLabel;

  /// No description provided for @qiblaDistanceValue.
  ///
  /// In ms, this message translates to:
  /// **'{km} km'**
  String qiblaDistanceValue(String km);

  /// No description provided for @qiblaSensorLabel.
  ///
  /// In ms, this message translates to:
  /// **'Ketepatan sensor'**
  String get qiblaSensorLabel;

  /// No description provided for @qiblaAccuracyHigh.
  ///
  /// In ms, this message translates to:
  /// **'Tinggi'**
  String get qiblaAccuracyHigh;

  /// No description provided for @qiblaAccuracyMedium.
  ///
  /// In ms, this message translates to:
  /// **'Sederhana'**
  String get qiblaAccuracyMedium;

  /// No description provided for @qiblaAccuracyLow.
  ///
  /// In ms, this message translates to:
  /// **'Rendah'**
  String get qiblaAccuracyLow;

  /// No description provided for @qiblaAccuracyUnreliable.
  ///
  /// In ms, this message translates to:
  /// **'Perlu kalibrasi'**
  String get qiblaAccuracyUnreliable;

  /// No description provided for @qiblaCalibrateTitle.
  ///
  /// In ms, this message translates to:
  /// **'Kalibrasi kompas'**
  String get qiblaCalibrateTitle;

  /// No description provided for @qiblaCalibrateBody.
  ///
  /// In ms, this message translates to:
  /// **'Gerakkan telefon dalam bentuk angka 8 beberapa kali. Jauhkan daripada magnet, sarung bermagnet dan logam.'**
  String get qiblaCalibrateBody;

  /// No description provided for @qiblaFlatTip.
  ///
  /// In ms, this message translates to:
  /// **'Pegang telefon mendatar dan stabil untuk bacaan paling tepat.'**
  String get qiblaFlatTip;

  /// No description provided for @qiblaNorthTrue.
  ///
  /// In ms, this message translates to:
  /// **'Utara benar (deklinasi magnet dikira)'**
  String get qiblaNorthTrue;

  /// No description provided for @qiblaNorthMagnetic.
  ///
  /// In ms, this message translates to:
  /// **'Utara magnet (menunggu lokasi)'**
  String get qiblaNorthMagnetic;

  /// No description provided for @qiblaCardinals.
  ///
  /// In ms, this message translates to:
  /// **'U,T,S,B'**
  String get qiblaCardinals;

  /// No description provided for @qiblaKaaba.
  ///
  /// In ms, this message translates to:
  /// **'Kaabah'**
  String get qiblaKaaba;

  /// No description provided for @qiblaSemantics.
  ///
  /// In ms, this message translates to:
  /// **'Kompas kiblat. Arah telefon {heading} darjah, kiblat {qibla} darjah. {guidance}'**
  String qiblaSemantics(String heading, String qibla, String guidance);

  /// No description provided for @qiblaUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Perlukan GPS untuk arah kiblat.'**
  String get qiblaUnavailable;

  /// No description provided for @aiRouteReady.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ke {place} sedia: {summary}.'**
  String aiRouteReady(String place, String summary);

  /// No description provided for @aiTollAmount.
  ///
  /// In ms, this message translates to:
  /// **'tol {amount}'**
  String aiTollAmount(String amount);

  /// No description provided for @aiTollAmountPlus.
  ///
  /// In ms, this message translates to:
  /// **'tol {amount}+'**
  String aiTollAmountPlus(String amount);

  /// No description provided for @aiTollNone.
  ///
  /// In ms, this message translates to:
  /// **'tiada tol'**
  String get aiTollNone;

  /// No description provided for @aiTollUnknown.
  ///
  /// In ms, this message translates to:
  /// **'ada tol'**
  String get aiTollUnknown;

  /// No description provided for @aiReasonRecommended.
  ///
  /// In ms, this message translates to:
  /// **'Ini pilihan disyorkan: seimbang antara masa, belokan dan kualiti jalan.'**
  String get aiReasonRecommended;

  /// No description provided for @aiReasonFastest.
  ///
  /// In ms, this message translates to:
  /// **'Ini pilihan paling cepat.'**
  String get aiReasonFastest;

  /// No description provided for @aiReasonShortest.
  ///
  /// In ms, this message translates to:
  /// **'Ini jarak paling pendek.'**
  String get aiReasonShortest;

  /// No description provided for @aiReasonTollFree.
  ///
  /// In ms, this message translates to:
  /// **'Pilihan ini mengelak semua tol.'**
  String get aiReasonTollFree;

  /// No description provided for @aiReasonFewestTolls.
  ///
  /// In ms, this message translates to:
  /// **'Semua pilihan ada tol, jadi saya pilih yang paling sedikit jalan bertol.'**
  String get aiReasonFewestTolls;

  /// No description provided for @aiReasonNoHighways.
  ///
  /// In ms, this message translates to:
  /// **'Pilihan ini guna jalan biasa sebanyak mungkin.'**
  String get aiReasonNoHighways;

  /// No description provided for @aiReasonCheapest.
  ///
  /// In ms, this message translates to:
  /// **'Ini paling murah secara keseluruhan (tol dan anggaran minyak).'**
  String get aiReasonCheapest;

  /// No description provided for @aiReasonSafest.
  ///
  /// In ms, this message translates to:
  /// **'Saya pilih yang paling selamat: kebanyakannya jalan utama, kurang belokan dan pusingan-U, tiada feri. Ini berdasarkan jenis jalan, bukan data kemalangan.'**
  String get aiReasonSafest;

  /// No description provided for @aiOtherOptions.
  ///
  /// In ms, this message translates to:
  /// **'Pilihan lain:'**
  String get aiOtherOptions;

  /// No description provided for @aiNavStarting.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi dimulakan sekarang. Pandu cermat.'**
  String get aiNavStarting;

  /// No description provided for @aiNoRouteToStart.
  ///
  /// In ms, this message translates to:
  /// **'Belum ada laluan. Beritahu saya destinasi, contohnya \"Laluan ke KLCC\".'**
  String get aiNoRouteToStart;

  /// No description provided for @aiPlaceNotFound.
  ///
  /// In ms, this message translates to:
  /// **'Saya tak jumpa \"{place}\". Cuba nama yang lebih spesifik.'**
  String aiPlaceNotFound(String place);

  /// No description provided for @aiRouteFailed.
  ///
  /// In ms, this message translates to:
  /// **'Laluan tidak dapat dikira sekarang. Sila cuba lagi sebentar lagi.'**
  String get aiRouteFailed;

  /// No description provided for @aiBusy.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan carian dan laluan sedang sibuk. Cuba lagi sebentar lagi.'**
  String get aiBusy;

  /// No description provided for @aiServiceDown.
  ///
  /// In ms, this message translates to:
  /// **'Perkhidmatan dalam talian tidak menjawab sekarang. Cuba lagi sebentar, atau muat turun pek peta offline supaya saya boleh rancang laluan tanpanya.'**
  String get aiServiceDown;

  /// No description provided for @aiSlow.
  ///
  /// In ms, this message translates to:
  /// **'Sambungan anda nampak perlahan atau tidak stabil, jadi saya tak dapat siapkan. Sila cuba lagi.'**
  String get aiSlow;

  /// No description provided for @aiOfflineNotFound.
  ///
  /// In ms, this message translates to:
  /// **'Anda sedang luar talian, jadi saya hanya boleh cari \"{place}\" dalam peta offline dan tiada padanan. Carian offline perlukan pek peta Malaysia (Peta offline). Cuba ejaan lain, atau sambung ke internet.'**
  String aiOfflineNotFound(String place);

  /// No description provided for @aiOfflinePackNeeded.
  ///
  /// In ms, this message translates to:
  /// **'Anda luar talian dan pek peta offline belum dipasang, jadi saya tak dapat rancang laluan itu. Muat turun pek Malaysia dalam Peta offline semasa ada internet.'**
  String get aiOfflinePackNeeded;

  /// No description provided for @aiOfflineEngine.
  ///
  /// In ms, this message translates to:
  /// **'Enjin laluan offline tak dapat mengira laluan itu. Cuba lagi, atau muat turun semula pek peta offline.'**
  String get aiOfflineEngine;

  /// No description provided for @aiNoDrivableRoute.
  ///
  /// In ms, this message translates to:
  /// **'Saya jumpa {place}, tetapi tiada laluan boleh dipandu ke sana dari lokasi anda. Semak sama ada itu tempat yang betul.'**
  String aiNoDrivableRoute(String place);

  /// No description provided for @aiSearchFailed.
  ///
  /// In ms, this message translates to:
  /// **'Saya tak dapat cari tempat itu sekarang. Sila cuba lagi.'**
  String get aiSearchFailed;

  /// No description provided for @aiAskDestination.
  ///
  /// In ms, this message translates to:
  /// **'Anda nak ke mana? Cakap contohnya \"Bawa saya ke KLCC\" atau \"Navigate to Masjid Negara\".'**
  String get aiAskDestination;

  /// No description provided for @aiRouteReadyHint.
  ///
  /// In ms, this message translates to:
  /// **'Laluan sudah ada pada peta. Cakap \"start now\" atau tekan Mula untuk mula memandu.'**
  String get aiRouteReadyHint;

  /// No description provided for @aiNotUnderstood.
  ///
  /// In ms, this message translates to:
  /// **'Saya kurang faham. Saya boleh rancang laluan (\"Laluan ke KLCC\"), cari tempat berdekatan, beritahu lokasi anda, serta kiblat dan waktu solat. Cuba salah satu.'**
  String get aiNotUnderstood;

  /// No description provided for @aiNoLocation.
  ///
  /// In ms, this message translates to:
  /// **'Saya perlukan lokasi anda untuk ini. Hidupkan lokasi dan cuba lagi.'**
  String get aiNoLocation;

  /// No description provided for @aiOfflineTool.
  ///
  /// In ms, this message translates to:
  /// **'Itu perlukan internet dan anda sedang luar talian. Saya masih boleh beri lokasi GPS, kiblat, waktu solat dan laluan jika anda sudah muat turun pek peta offline. Cuba lagi bila online.'**
  String get aiOfflineTool;

  /// No description provided for @aiRouteCleared.
  ///
  /// In ms, this message translates to:
  /// **'Laluan dipadam.'**
  String get aiRouteCleared;

  /// No description provided for @aiNearbyTitle.
  ///
  /// In ms, this message translates to:
  /// **'{category} terdekat:'**
  String aiNearbyTitle(String category);

  /// No description provided for @aiNearbyAroundYou.
  ///
  /// In ms, this message translates to:
  /// **'Tempat berdekatan sekitar anda:'**
  String get aiNearbyAroundYou;

  /// No description provided for @aiNothingFound.
  ///
  /// In ms, this message translates to:
  /// **'Tiada apa-apa dijumpai berdekatan sekarang.'**
  String get aiNothingFound;

  /// No description provided for @aiSearchTitle.
  ///
  /// In ms, this message translates to:
  /// **'Ini yang saya jumpa untuk \"{query}\":'**
  String aiSearchTitle(String query);

  /// No description provided for @aiCurrentLocation.
  ///
  /// In ms, this message translates to:
  /// **'Anda di sini: {place}. Koordinat: {lat}, {lng}.'**
  String aiCurrentLocation(String place, String lat, String lng);

  /// No description provided for @aiCurrentLocationCoords.
  ///
  /// In ms, this message translates to:
  /// **'Kedudukan GPS anda ialah {lat}, {lng}. Nama tempat tidak dapat diselesaikan sekarang.'**
  String aiCurrentLocationCoords(String lat, String lng);

  /// No description provided for @aiCapabilities.
  ///
  /// In ms, this message translates to:
  /// **'Anda boleh minta saya rancang laluan, mula navigasi, cari minyak/masjid/makan berdekatan, cuaca atau IPU, kiblat, waktu solat, tempat sepanjang laluan, atau main muzik/radio. Arahan peta berfungsi tanpa model pada telefon.'**
  String get aiCapabilities;

  /// No description provided for @aiCapabilitiesOffline.
  ///
  /// In ms, this message translates to:
  /// **'Ciri pada telefon (luar talian): rancang laluan jika peta offline sudah dimuat turun, arah kiblat, dan waktu solat hari ini. Carian tempat, cuaca, IPU, muzik dan Wikipedia perlukan internet. Arahan seperti \"Laluan ke KLCC\" atau \"Di mana saya\" tidak akan memaparkan senarai alat.'**
  String get aiCapabilitiesOffline;

  /// No description provided for @aiWeatherNow.
  ///
  /// In ms, this message translates to:
  /// **'{place}: {condition}, {temp}°C (terasa {feels}°C).'**
  String aiWeatherNow(
    String place,
    String condition,
    String temp,
    String feels,
  );

  /// No description provided for @aiWeatherDetails.
  ///
  /// In ms, this message translates to:
  /// **'Peluang hujan {rain}%, kelembapan {humidity}%, angin {wind} km/j.'**
  String aiWeatherDetails(String rain, String humidity, String wind);

  /// No description provided for @aiHere.
  ///
  /// In ms, this message translates to:
  /// **'Di sini'**
  String get aiHere;

  /// No description provided for @aiAirLine.
  ///
  /// In ms, this message translates to:
  /// **'Kualiti udara berhampiran {station}: IPU {ipu}, {band}.'**
  String aiAirLine(String station, String ipu, String band);

  /// No description provided for @aiQiblaLine.
  ///
  /// In ms, this message translates to:
  /// **'Arah kiblat dari lokasi anda ialah {bearing}° dari utara benar, {distance} km ke Kaabah. Buka kompas Kiblat untuk arah secara langsung.'**
  String aiQiblaLine(String bearing, String distance);

  /// No description provided for @aiPrayerTitle.
  ///
  /// In ms, this message translates to:
  /// **'Waktu solat hari ini ({zone}):'**
  String aiPrayerTitle(String zone);

  /// No description provided for @aiPrayerTitleLocal.
  ///
  /// In ms, this message translates to:
  /// **'Waktu solat hari ini:'**
  String get aiPrayerTitleLocal;

  /// No description provided for @aiPrayerNext.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya: {prayer} pada {time}.'**
  String aiPrayerNext(String prayer, String time);

  /// No description provided for @aiUnavailable.
  ///
  /// In ms, this message translates to:
  /// **'Maklumat itu tiada buat masa ini. Cuba lagi sebentar.'**
  String get aiUnavailable;

  /// No description provided for @aiAlongTitle.
  ///
  /// In ms, this message translates to:
  /// **'{category} sepanjang laluan:'**
  String aiAlongTitle(String category);

  /// No description provided for @aiAlongIn.
  ///
  /// In ms, this message translates to:
  /// **'dalam {distance}'**
  String aiAlongIn(String distance);

  /// No description provided for @aiNeedRoute.
  ///
  /// In ms, this message translates to:
  /// **'Rancang laluan dahulu, kemudian saya boleh cari sepanjang laluan.'**
  String get aiNeedRoute;

  /// No description provided for @aiPlaying.
  ///
  /// In ms, this message translates to:
  /// **'Memainkan {title}.'**
  String aiPlaying(String title);

  /// No description provided for @aiNeedModel.
  ///
  /// In ms, this message translates to:
  /// **'Arahan peta boleh digunakan terus (laluan, tempat berdekatan, cuaca, kiblat). Untuk soalan umum, muat turun model pada telefon dahulu.'**
  String get aiNeedModel;

  /// No description provided for @aiError.
  ///
  /// In ms, this message translates to:
  /// **'Maaf, ada masalah. Sila cuba lagi.'**
  String get aiError;

  /// No description provided for @aiPreparing.
  ///
  /// In ms, this message translates to:
  /// **'Menyediakan model…'**
  String get aiPreparing;

  /// No description provided for @aiThinking.
  ///
  /// In ms, this message translates to:
  /// **'Sedang berfikir…'**
  String get aiThinking;

  /// No description provided for @aiWorking.
  ///
  /// In ms, this message translates to:
  /// **'Sedang diproses…'**
  String get aiWorking;

  /// No description provided for @aiSearchingSources.
  ///
  /// In ms, this message translates to:
  /// **'Mencari dalam teks klasik…'**
  String get aiSearchingSources;

  /// No description provided for @aiActionStart.
  ///
  /// In ms, this message translates to:
  /// **'Mula navigasi'**
  String get aiActionStart;

  /// No description provided for @aiActionShowRoute.
  ///
  /// In ms, this message translates to:
  /// **'Lihat di peta'**
  String get aiActionShowRoute;

  /// No description provided for @aiActionRouteTo.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ke {place}'**
  String aiActionRouteTo(String place);

  /// No description provided for @aiNewChat.
  ///
  /// In ms, this message translates to:
  /// **'Sembang baharu'**
  String get aiNewChat;

  /// No description provided for @aiChats.
  ///
  /// In ms, this message translates to:
  /// **'Sembang'**
  String get aiChats;

  /// No description provided for @aiRename.
  ///
  /// In ms, this message translates to:
  /// **'Namakan semula'**
  String get aiRename;

  /// No description provided for @aiRenameTitle.
  ///
  /// In ms, this message translates to:
  /// **'Namakan semula sembang'**
  String get aiRenameTitle;

  /// No description provided for @aiDelete.
  ///
  /// In ms, this message translates to:
  /// **'Padam'**
  String get aiDelete;

  /// No description provided for @aiDeleteAll.
  ///
  /// In ms, this message translates to:
  /// **'Padam semua sembang'**
  String get aiDeleteAll;

  /// No description provided for @aiDeleteAllConfirm.
  ///
  /// In ms, this message translates to:
  /// **'Padam semua sembang dalam {name}? Tindakan ini tidak boleh dibuat asal.'**
  String aiDeleteAllConfirm(String name);

  /// No description provided for @aiDeleted.
  ///
  /// In ms, this message translates to:
  /// **'Sembang dipadam'**
  String get aiDeleted;

  /// No description provided for @aiUndo.
  ///
  /// In ms, this message translates to:
  /// **'Buat asal'**
  String get aiUndo;

  /// No description provided for @aiSave.
  ///
  /// In ms, this message translates to:
  /// **'Simpan'**
  String get aiSave;

  /// No description provided for @aiCancel.
  ///
  /// In ms, this message translates to:
  /// **'Batal'**
  String get aiCancel;

  /// No description provided for @aiToday.
  ///
  /// In ms, this message translates to:
  /// **'Hari ini'**
  String get aiToday;

  /// No description provided for @aiPrevious7Days.
  ///
  /// In ms, this message translates to:
  /// **'7 hari lalu'**
  String get aiPrevious7Days;

  /// No description provided for @aiOlder.
  ///
  /// In ms, this message translates to:
  /// **'Lebih lama'**
  String get aiOlder;

  /// No description provided for @aiNoChats.
  ///
  /// In ms, this message translates to:
  /// **'Belum ada sembang. Mulakan di bawah.'**
  String get aiNoChats;

  /// No description provided for @aiCopy.
  ///
  /// In ms, this message translates to:
  /// **'Salin'**
  String get aiCopy;

  /// No description provided for @aiCopied.
  ///
  /// In ms, this message translates to:
  /// **'Disalin'**
  String get aiCopied;

  /// No description provided for @aiStop.
  ///
  /// In ms, this message translates to:
  /// **'Henti'**
  String get aiStop;

  /// No description provided for @muslimNoticeSummary.
  ///
  /// In ms, this message translates to:
  /// **'Ringkasan daripada teks klasik (islamic.app). Bukan fatwa rasmi JAKIM atau mufti negeri; semak petikan dan rujuk ulama untuk keputusan peribadi. Wallahu a\'lam.'**
  String get muslimNoticeSummary;

  /// No description provided for @muslimNoticeRateLimited.
  ///
  /// In ms, this message translates to:
  /// **'islamic.app sibuk sekarang (had permintaan). Cuba lagi sebentar. Pautan fatwa berkaitan di bawah jika ada.'**
  String get muslimNoticeRateLimited;

  /// No description provided for @muslimNoticeNotGrounded.
  ///
  /// In ms, this message translates to:
  /// **'Tiada petikan klasik yang cukup hampir untuk soalan ini. Sila rujuk ulama. Wallahu a\'lam.'**
  String get muslimNoticeNotGrounded;

  /// No description provided for @muslimNoticeUnreachable.
  ///
  /// In ms, this message translates to:
  /// **'Sumber rujukan tidak dapat dicapai sekarang. Cuba lagi, atau rujuk pejabat mufti tempatan. Wallahu a\'lam.'**
  String get muslimNoticeUnreachable;

  /// No description provided for @muslimSources.
  ///
  /// In ms, this message translates to:
  /// **'Sumber ({count})'**
  String muslimSources(int count);

  /// No description provided for @muslimClassical.
  ///
  /// In ms, this message translates to:
  /// **'Teks klasik'**
  String get muslimClassical;

  /// No description provided for @muslimFatwa.
  ///
  /// In ms, this message translates to:
  /// **'Fatwa berkaitan (indeks deen.ai, bukan rasmi di Malaysia)'**
  String get muslimFatwa;

  /// No description provided for @muslimPage.
  ///
  /// In ms, this message translates to:
  /// **'hlm. {page}'**
  String muslimPage(String page);

  /// No description provided for @assistantSuggestFuel.
  ///
  /// In ms, this message translates to:
  /// **'Stesen minyak terdekat'**
  String get assistantSuggestFuel;

  /// No description provided for @assistantSuggestWeather.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca di Kuala Terengganu'**
  String get assistantSuggestWeather;

  /// No description provided for @routeTollShort.
  ///
  /// In ms, this message translates to:
  /// **'Tol'**
  String get routeTollShort;

  /// No description provided for @qiblaCalibrateAction.
  ///
  /// In ms, this message translates to:
  /// **'Kalibrasi'**
  String get qiblaCalibrateAction;

  /// No description provided for @qiblaCalibrateSteps.
  ///
  /// In ms, this message translates to:
  /// **'Pegang telefon dan lukis angka 8 yang besar di udara tiga kali sambil memusingkan pergelangan tangan. Jauhkan daripada logam dan magnet.'**
  String get qiblaCalibrateSteps;

  /// No description provided for @qiblaCalibrateDone.
  ///
  /// In ms, this message translates to:
  /// **'Kompas sudah dikalibrasi'**
  String get qiblaCalibrateDone;

  /// No description provided for @qiblaCalibrateProgress.
  ///
  /// In ms, this message translates to:
  /// **'Teruskan… ketepatan ±{deg}°'**
  String qiblaCalibrateProgress(String deg);

  /// No description provided for @qiblaCalibrateProgressLevel.
  ///
  /// In ms, this message translates to:
  /// **'Teruskan… ketepatan: {level}'**
  String qiblaCalibrateProgressLevel(String level);

  /// No description provided for @qiblaInterferenceTitle.
  ///
  /// In ms, this message translates to:
  /// **'Gangguan magnet'**
  String get qiblaInterferenceTitle;

  /// No description provided for @qiblaInterferenceBody.
  ///
  /// In ms, this message translates to:
  /// **'Medan magnet di sekitar telefon luar biasa. Jauhkan daripada logam, magnet, kereta, pembesar suara dan sarung telefon bermagnet, kemudian kalibrasi semula.'**
  String get qiblaInterferenceBody;

  /// No description provided for @qiblaAccuracyDegrees.
  ///
  /// In ms, this message translates to:
  /// **'±{deg}°'**
  String qiblaAccuracyDegrees(String deg);

  /// No description provided for @qiblaDone.
  ///
  /// In ms, this message translates to:
  /// **'Selesai'**
  String get qiblaDone;

  /// No description provided for @qiblaNotAccurateYet.
  ///
  /// In ms, this message translates to:
  /// **'Kalibrasi untuk arah yang tepat'**
  String get qiblaNotAccurateYet;

  /// No description provided for @weatherCurrentLocation.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi saya'**
  String get weatherCurrentLocation;

  /// No description provided for @weatherHighLow.
  ///
  /// In ms, this message translates to:
  /// **'T:{high}°  R:{low}°'**
  String weatherHighLow(String high, String low);

  /// No description provided for @weatherFeelsLikeValue.
  ///
  /// In ms, this message translates to:
  /// **'Terasa {temp}°'**
  String weatherFeelsLikeValue(String temp);

  /// No description provided for @weatherHourly.
  ///
  /// In ms, this message translates to:
  /// **'Ramalan setiap jam'**
  String get weatherHourly;

  /// No description provided for @weatherDaily.
  ///
  /// In ms, this message translates to:
  /// **'Ramalan 10 hari'**
  String get weatherDaily;

  /// No description provided for @weatherNow.
  ///
  /// In ms, this message translates to:
  /// **'Kini'**
  String get weatherNow;

  /// No description provided for @weatherToday.
  ///
  /// In ms, this message translates to:
  /// **'Hari ini'**
  String get weatherToday;

  /// No description provided for @weatherHumidity.
  ///
  /// In ms, this message translates to:
  /// **'Kelembapan'**
  String get weatherHumidity;

  /// No description provided for @weatherWind.
  ///
  /// In ms, this message translates to:
  /// **'Angin'**
  String get weatherWind;

  /// No description provided for @weatherUv.
  ///
  /// In ms, this message translates to:
  /// **'Indeks UV'**
  String get weatherUv;

  /// No description provided for @weatherUvLow.
  ///
  /// In ms, this message translates to:
  /// **'Rendah'**
  String get weatherUvLow;

  /// No description provided for @weatherUvModerate.
  ///
  /// In ms, this message translates to:
  /// **'Sederhana'**
  String get weatherUvModerate;

  /// No description provided for @weatherUvHigh.
  ///
  /// In ms, this message translates to:
  /// **'Tinggi'**
  String get weatherUvHigh;

  /// No description provided for @weatherUvVeryHigh.
  ///
  /// In ms, this message translates to:
  /// **'Sangat tinggi'**
  String get weatherUvVeryHigh;

  /// No description provided for @weatherUvExtreme.
  ///
  /// In ms, this message translates to:
  /// **'Melampau'**
  String get weatherUvExtreme;

  /// No description provided for @weatherSunrise.
  ///
  /// In ms, this message translates to:
  /// **'Matahari terbit'**
  String get weatherSunrise;

  /// No description provided for @weatherSunset.
  ///
  /// In ms, this message translates to:
  /// **'Matahari terbenam'**
  String get weatherSunset;

  /// No description provided for @weatherPressure.
  ///
  /// In ms, this message translates to:
  /// **'Tekanan'**
  String get weatherPressure;

  /// No description provided for @weatherVisibility.
  ///
  /// In ms, this message translates to:
  /// **'Jarak penglihatan'**
  String get weatherVisibility;

  /// No description provided for @weatherRainToday.
  ///
  /// In ms, this message translates to:
  /// **'Hujan hari ini'**
  String get weatherRainToday;

  /// No description provided for @weatherRainChance.
  ///
  /// In ms, this message translates to:
  /// **'Peluang hujan'**
  String get weatherRainChance;

  /// No description provided for @weatherUpdated.
  ///
  /// In ms, this message translates to:
  /// **'Dikemas kini {time}'**
  String weatherUpdated(String time);

  /// No description provided for @weatherOfflineStale.
  ///
  /// In ms, this message translates to:
  /// **'Luar talian · dikemas kini {time}'**
  String weatherOfflineStale(String time);

  /// No description provided for @weatherSearchHint.
  ///
  /// In ms, this message translates to:
  /// **'Cari bandar atau tempat'**
  String get weatherSearchHint;

  /// No description provided for @weatherAddPlace.
  ///
  /// In ms, this message translates to:
  /// **'Tambah tempat'**
  String get weatherAddPlace;

  /// No description provided for @weatherRemovePlace.
  ///
  /// In ms, this message translates to:
  /// **'Buang tempat'**
  String get weatherRemovePlace;

  /// No description provided for @weatherSevereSoon.
  ///
  /// In ms, this message translates to:
  /// **'Ribut petir atau hujan lebat dijangka dalam 24 jam akan datang.'**
  String get weatherSevereSoon;

  /// No description provided for @weatherLoadFailed.
  ///
  /// In ms, this message translates to:
  /// **'Ramalan tidak dapat dimuat. Semak sambungan dan cuba lagi.'**
  String get weatherLoadFailed;

  /// No description provided for @weatherNoLocation.
  ///
  /// In ms, this message translates to:
  /// **'Hidupkan lokasi untuk melihat cuaca di tempat anda, atau cari tempat.'**
  String get weatherNoLocation;

  /// No description provided for @weatherSpeedKmh.
  ///
  /// In ms, this message translates to:
  /// **'{value} km/j'**
  String weatherSpeedKmh(String value);

  /// No description provided for @weatherMm.
  ///
  /// In ms, this message translates to:
  /// **'{value} mm'**
  String weatherMm(String value);

  /// No description provided for @weatherHpa.
  ///
  /// In ms, this message translates to:
  /// **'{value} hPa'**
  String weatherHpa(String value);

  /// No description provided for @weatherKm.
  ///
  /// In ms, this message translates to:
  /// **'{value} km'**
  String weatherKm(String value);

  /// No description provided for @weatherCardinals.
  ///
  /// In ms, this message translates to:
  /// **'U,TL,T,TG,S,BD,B,BL'**
  String get weatherCardinals;

  /// No description provided for @weatherFrom.
  ///
  /// In ms, this message translates to:
  /// **'dari {dir}'**
  String weatherFrom(String dir);

  /// No description provided for @weatherCodeClear.
  ///
  /// In ms, this message translates to:
  /// **'Cerah'**
  String get weatherCodeClear;

  /// No description provided for @weatherCodeMainlyClear.
  ///
  /// In ms, this message translates to:
  /// **'Kebanyakannya cerah'**
  String get weatherCodeMainlyClear;

  /// No description provided for @weatherCodePartlyCloudy.
  ///
  /// In ms, this message translates to:
  /// **'Sebahagian berawan'**
  String get weatherCodePartlyCloudy;

  /// No description provided for @weatherCodeOvercast.
  ///
  /// In ms, this message translates to:
  /// **'Mendung'**
  String get weatherCodeOvercast;

  /// No description provided for @weatherCodeFog.
  ///
  /// In ms, this message translates to:
  /// **'Berkabus'**
  String get weatherCodeFog;

  /// No description provided for @weatherCodeDrizzle.
  ///
  /// In ms, this message translates to:
  /// **'Gerimis'**
  String get weatherCodeDrizzle;

  /// No description provided for @weatherCodeRain.
  ///
  /// In ms, this message translates to:
  /// **'Hujan'**
  String get weatherCodeRain;

  /// No description provided for @weatherCodeHeavyRain.
  ///
  /// In ms, this message translates to:
  /// **'Hujan lebat'**
  String get weatherCodeHeavyRain;

  /// No description provided for @weatherCodeShowers.
  ///
  /// In ms, this message translates to:
  /// **'Hujan renyai'**
  String get weatherCodeShowers;

  /// No description provided for @weatherCodeHeavyShowers.
  ///
  /// In ms, this message translates to:
  /// **'Hujan renyai lebat'**
  String get weatherCodeHeavyShowers;

  /// No description provided for @weatherCodeThunderstorm.
  ///
  /// In ms, this message translates to:
  /// **'Ribut petir'**
  String get weatherCodeThunderstorm;

  /// No description provided for @weatherCodeSnow.
  ///
  /// In ms, this message translates to:
  /// **'Salji'**
  String get weatherCodeSnow;

  /// No description provided for @mapToolsMore.
  ///
  /// In ms, this message translates to:
  /// **'Alat lain'**
  String get mapToolsMore;

  /// No description provided for @weatherOpen.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca'**
  String get weatherOpen;

  /// No description provided for @offlineMapsSearchAvailable.
  ///
  /// In ms, this message translates to:
  /// **'Carian offline tersedia (+{size})'**
  String offlineMapsSearchAvailable(String size);

  /// No description provided for @offlineMapsMapAvailable.
  ///
  /// In ms, this message translates to:
  /// **'Paparan peta offline tersedia (+{size})'**
  String offlineMapsMapAvailable(String size);

  /// No description provided for @offlineMapsMapSearchAvailable.
  ///
  /// In ms, this message translates to:
  /// **'Paparan peta dan carian offline tersedia (+{size})'**
  String offlineMapsMapSearchAvailable(String size);

  /// No description provided for @aiIdentity.
  ///
  /// In ms, this message translates to:
  /// **'Saya FG AI, pembantu pintar dalam FGMaps, dibangunkan oleh Faiz Nasir dari FG Universal Empire. Saya berjalan terus pada telefon anda, jadi banyak perkara boleh dibuat tanpa internet: merancang laluan (dengan peta offline), arah kiblat, waktu solat, dan menjawab soalan umum. Dengan internet, saya juga boleh mencari tempat, menyemak cuaca dan banyak lagi.'**
  String get aiIdentity;

  /// No description provided for @aiGreeting.
  ///
  /// In ms, this message translates to:
  /// **'Hai! Saya FG AI. Nak ke mana hari ini, atau ada apa yang boleh saya bantu?'**
  String get aiGreeting;

  /// No description provided for @aiThanks.
  ///
  /// In ms, this message translates to:
  /// **'Sama-sama! Ada apa-apa lagi yang boleh saya bantu?'**
  String get aiThanks;

  /// No description provided for @aiPing.
  ///
  /// In ms, this message translates to:
  /// **'Ya, saya di sini. Tanya apa sahaja, contohnya \"laluan ke Ipoh\", \"cuaca di Kuantan\", \"masjid terdekat\" atau soalan umum.'**
  String get aiPing;

  /// No description provided for @aiWikiSource.
  ///
  /// In ms, this message translates to:
  /// **'Sumber: Wikipedia'**
  String get aiWikiSource;

  /// No description provided for @aiModelsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Model AI pada telefon'**
  String get aiModelsTitle;

  /// No description provided for @aiModelsIntro.
  ///
  /// In ms, this message translates to:
  /// **'Pilih satu model untuk FG AI. Model yang lebih besar lebih pintar dan lebih fasih, tetapi muat turunnya lebih besar, perlukan lebih RAM dan menjawab lebih perlahan. Hanya model yang digunakan dimuat ke memori; yang lain boleh kekal untuk ditukar bila-bila masa.'**
  String get aiModelsIntro;

  /// No description provided for @aiModelsManage.
  ///
  /// In ms, this message translates to:
  /// **'Pilih model AI'**
  String get aiModelsManage;

  /// No description provided for @aiModelTierBasic.
  ///
  /// In ms, this message translates to:
  /// **'Asas · pantas dan ringan'**
  String get aiModelTierBasic;

  /// No description provided for @aiModelTierMedium.
  ///
  /// In ms, this message translates to:
  /// **'Sederhana · seimbang'**
  String get aiModelTierMedium;

  /// No description provided for @aiModelTierHigh.
  ///
  /// In ms, this message translates to:
  /// **'Tinggi · paling pintar'**
  String get aiModelTierHigh;

  /// No description provided for @aiModelRam.
  ///
  /// In ms, this message translates to:
  /// **'RAM {gb} GB ke atas'**
  String aiModelRam(String gb);

  /// No description provided for @aiModelInUse.
  ///
  /// In ms, this message translates to:
  /// **'Sedang digunakan'**
  String get aiModelInUse;

  /// No description provided for @aiModelDownloaded.
  ///
  /// In ms, this message translates to:
  /// **'Dimuat turun'**
  String get aiModelDownloaded;

  /// No description provided for @aiModelUse.
  ///
  /// In ms, this message translates to:
  /// **'Guna'**
  String get aiModelUse;

  /// No description provided for @aiModelDownload.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun'**
  String get aiModelDownload;

  /// No description provided for @aiModelDownloadUse.
  ///
  /// In ms, this message translates to:
  /// **'Muat turun & guna'**
  String get aiModelDownloadUse;

  /// No description provided for @aiModelDelete.
  ///
  /// In ms, this message translates to:
  /// **'Padam'**
  String get aiModelDelete;

  /// No description provided for @aiModelDeleteTitle.
  ///
  /// In ms, this message translates to:
  /// **'Padam {name}?'**
  String aiModelDeleteTitle(String name);

  /// No description provided for @aiModelDeleteBody.
  ///
  /// In ms, this message translates to:
  /// **'Fail model dibuang dari telefon. Anda boleh memuat turunnya semula bila-bila masa.'**
  String get aiModelDeleteBody;

  /// No description provided for @aiModelSwitched.
  ///
  /// In ms, this message translates to:
  /// **'FG AI kini menggunakan {name}.'**
  String aiModelSwitched(String name);

  /// No description provided for @aiModelBusy.
  ///
  /// In ms, this message translates to:
  /// **'Tunggu muat turun semasa selesai dahulu.'**
  String get aiModelBusy;

  /// No description provided for @aiModelDescQwen3.
  ///
  /// In ms, this message translates to:
  /// **'Paling ringan dan pantas. Sesuai untuk telefon lama dan soalan ringkas.'**
  String get aiModelDescQwen3;

  /// No description provided for @aiModelDescQwen35Small.
  ///
  /// In ms, this message translates to:
  /// **'Asas yang lebih baharu: lebih fasih dalam BM dan BI, masih ringan.'**
  String get aiModelDescQwen35Small;

  /// No description provided for @aiModelDescGemma4E2b.
  ///
  /// In ms, this message translates to:
  /// **'Seimbang: jawapan jauh lebih bijak dan tepat, sesuai untuk kebanyakan telefon moden.'**
  String get aiModelDescGemma4E2b;

  /// No description provided for @aiModelDescQwen35Big.
  ///
  /// In ms, this message translates to:
  /// **'Penaakulan kuat untuk soalan sukar, matematik dan penjelasan panjang.'**
  String get aiModelDescQwen35Big;

  /// No description provided for @aiModelDescGemma4E4b.
  ///
  /// In ms, this message translates to:
  /// **'Paling pintar dan fasih. Untuk telefon mewah dengan RAM besar.'**
  String get aiModelDescGemma4E4b;

  /// No description provided for @assistantDownloadBodyModel.
  ///
  /// In ms, this message translates to:
  /// **'{name} ({size}). Berjalan pada telefon anda; tiada kunci awan. Wi‑Fi disyorkan.'**
  String assistantDownloadBodyModel(String name, String size);

  /// No description provided for @assistantSettingsModel.
  ///
  /// In ms, this message translates to:
  /// **'Model: {name}'**
  String assistantSettingsModel(String name);

  /// No description provided for @aiNoTrip.
  ///
  /// In ms, this message translates to:
  /// **'Belum ada laluan atau navigasi. Beritahu saya destinasi dahulu, contohnya \"bawa saya ke KLCC\".'**
  String get aiNoTrip;

  /// No description provided for @aiTripDistanceLeft.
  ///
  /// In ms, this message translates to:
  /// **'Baki jarak: **{distance}**.'**
  String aiTripDistanceLeft(String distance);

  /// No description provided for @aiTripDistanceTotal.
  ///
  /// In ms, this message translates to:
  /// **'Jarak ke destinasi: **{distance}**.'**
  String aiTripDistanceTotal(String distance);

  /// No description provided for @aiTripTimeLeft.
  ///
  /// In ms, this message translates to:
  /// **'Baki masa: kira-kira **{duration}**.'**
  String aiTripTimeLeft(String duration);

  /// No description provided for @aiTripTimeTotal.
  ///
  /// In ms, this message translates to:
  /// **'Perjalanan mengambil masa kira-kira **{duration}**.'**
  String aiTripTimeTotal(String duration);

  /// No description provided for @aiTripArrival.
  ///
  /// In ms, this message translates to:
  /// **'Anda dijangka tiba pada pukul **{time}** (lagi {duration}).'**
  String aiTripArrival(String time, String duration);

  /// No description provided for @aiTripTollNone.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ini tiada tol.'**
  String get aiTripTollNone;

  /// No description provided for @aiTripToll.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran tol laluan ini: **{amount}**.'**
  String aiTripToll(String amount);

  /// No description provided for @aiTripTollPartial.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran tol sekurang-kurangnya **{amount}** (ada plaza yang harganya tiada dalam data).'**
  String aiTripTollPartial(String amount);

  /// No description provided for @aiTripTollPending.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ini ada tol tetapi anggarannya masih dikira. Tanya lagi sebentar nanti.'**
  String get aiTripTollPending;

  /// No description provided for @aiTripTollUnknown.
  ///
  /// In ms, this message translates to:
  /// **'Laluan ini ada tol tetapi harganya tiada dalam data kami.'**
  String get aiTripTollUnknown;

  /// No description provided for @aiTripTollMotorcycle.
  ///
  /// In ms, this message translates to:
  /// **'Harga tol motosikal tiada dalam data kami (kebanyakan lebuh raya percuma untuk motosikal, tetapi tidak semua). Saya tidak mahu meneka.'**
  String get aiTripTollMotorcycle;

  /// No description provided for @aiTripFuel.
  ///
  /// In ms, this message translates to:
  /// **'Anggaran kos minyak: **{amount}** untuk {distance} (RM{price} seliter, {liters} L/100 km).'**
  String aiTripFuel(
    String amount,
    String distance,
    String price,
    String liters,
  );

  /// No description provided for @aiTripFuelNoPrice.
  ///
  /// In ms, this message translates to:
  /// **'Harga minyak belum diketahui (tiada data dan tiada harga yang anda tetapkan). Tetapkan harga di Tetapan > Minyak.'**
  String get aiTripFuelNoPrice;

  /// No description provided for @aiTripNextTurn.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya: **{action}** dalam {distance}.'**
  String aiTripNextTurn(String action, String distance);

  /// No description provided for @aiTripNextTurnNow.
  ///
  /// In ms, this message translates to:
  /// **'Seterusnya: **{action}**.'**
  String aiTripNextTurnNow(String action);

  /// No description provided for @aiTripNoNav.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi belum bermula, jadi saya tiada arahan seterusnya. Mulakan navigasi dahulu.'**
  String get aiTripNoNav;

  /// No description provided for @aiTripSpeedLimit.
  ///
  /// In ms, this message translates to:
  /// **'Had laju di jalan ini: **{kmh} km/j**.'**
  String aiTripSpeedLimit(String kmh);

  /// No description provided for @aiTripSpeedUnknown.
  ///
  /// In ms, this message translates to:
  /// **'Had laju jalan ini tiada dalam data.'**
  String get aiTripSpeedUnknown;

  /// No description provided for @aiHomeNotSet.
  ///
  /// In ms, this message translates to:
  /// **'Anda belum menetapkan Rumah. Ketik Rumah pada skrin carian untuk menetapkannya, kemudian minta lagi.'**
  String get aiHomeNotSet;

  /// No description provided for @aiWorkNotSet.
  ///
  /// In ms, this message translates to:
  /// **'Anda belum menetapkan Kerja. Ketik Kerja pada skrin carian untuk menetapkannya, kemudian minta lagi.'**
  String get aiWorkNotSet;

  /// No description provided for @aiVehicleCar.
  ///
  /// In ms, this message translates to:
  /// **'Baik, kenderaan ditukar kepada **kereta**.'**
  String get aiVehicleCar;

  /// No description provided for @aiVehicleMotorcycle.
  ///
  /// In ms, this message translates to:
  /// **'Baik, kenderaan ditukar kepada **motosikal**.'**
  String get aiVehicleMotorcycle;

  /// No description provided for @aiVoiceOn.
  ///
  /// In ms, this message translates to:
  /// **'Suara panduan dihidupkan.'**
  String get aiVoiceOn;

  /// No description provided for @aiVoiceOff.
  ///
  /// In ms, this message translates to:
  /// **'Suara panduan dimatikan.'**
  String get aiVoiceOff;

  /// No description provided for @aiThemeDark.
  ///
  /// In ms, this message translates to:
  /// **'Baik, mod gelap dihidupkan.'**
  String get aiThemeDark;

  /// No description provided for @aiThemeLight.
  ///
  /// In ms, this message translates to:
  /// **'Baik, mod cerah dihidupkan.'**
  String get aiThemeLight;

  /// No description provided for @aiThemeSystem.
  ///
  /// In ms, this message translates to:
  /// **'Baik, tema mengikut sistem peranti.'**
  String get aiThemeSystem;

  /// No description provided for @aiNavStopped.
  ///
  /// In ms, this message translates to:
  /// **'Navigasi dihentikan.'**
  String get aiNavStopped;

  /// No description provided for @aiAck.
  ///
  /// In ms, this message translates to:
  /// **'Baik. Beritahu saya bila perlu bantuan peta, contohnya \"bawa saya ke KLCC\".'**
  String get aiAck;

  /// No description provided for @aiAskRadio.
  ///
  /// In ms, this message translates to:
  /// **'Stesen radio mana? Contohnya \"play Era\" atau \"pasang Hitz\".'**
  String get aiAskRadio;

  /// No description provided for @aiAskMusic.
  ///
  /// In ms, this message translates to:
  /// **'Lagu atau artis apa? Contohnya \"mainkan lagu Siti Nurhaliza\".'**
  String get aiAskMusic;

  /// No description provided for @aiNoMoreResults.
  ///
  /// In ms, this message translates to:
  /// **'Tiada pilihan lain dalam senarai tadi. Cuba cari dengan nama yang lebih tepat.'**
  String get aiNoMoreResults;

  /// No description provided for @aiGuessedPlace.
  ///
  /// In ms, this message translates to:
  /// **'Saya tidak pasti maksud anda, jadi saya cari \"{query}\" sebagai tempat. Ketik salah satu untuk ke sana.'**
  String aiGuessedPlace(String query);

  /// No description provided for @searchCatBarber.
  ///
  /// In ms, this message translates to:
  /// **'Kedai gunting'**
  String get searchCatBarber;

  /// No description provided for @searchCatPharmacy.
  ///
  /// In ms, this message translates to:
  /// **'Farmasi'**
  String get searchCatPharmacy;

  /// No description provided for @searchCatClinic.
  ///
  /// In ms, this message translates to:
  /// **'Klinik'**
  String get searchCatClinic;

  /// No description provided for @searchCatAtm.
  ///
  /// In ms, this message translates to:
  /// **'ATM'**
  String get searchCatAtm;

  /// No description provided for @searchCatBank.
  ///
  /// In ms, this message translates to:
  /// **'Bank'**
  String get searchCatBank;

  /// No description provided for @searchCatConvenience.
  ///
  /// In ms, this message translates to:
  /// **'Kedai runcit'**
  String get searchCatConvenience;

  /// No description provided for @searchCatSupermarket.
  ///
  /// In ms, this message translates to:
  /// **'Pasar raya'**
  String get searchCatSupermarket;

  /// No description provided for @searchCatMall.
  ///
  /// In ms, this message translates to:
  /// **'Pusat beli-belah'**
  String get searchCatMall;

  /// No description provided for @searchCatCarWash.
  ///
  /// In ms, this message translates to:
  /// **'Cuci kereta'**
  String get searchCatCarWash;

  /// No description provided for @searchCatWorkshop.
  ///
  /// In ms, this message translates to:
  /// **'Bengkel kereta'**
  String get searchCatWorkshop;

  /// No description provided for @searchCatTyres.
  ///
  /// In ms, this message translates to:
  /// **'Kedai tayar'**
  String get searchCatTyres;

  /// No description provided for @searchCatLaundry.
  ///
  /// In ms, this message translates to:
  /// **'Dobi'**
  String get searchCatLaundry;

  /// No description provided for @searchCatHotel.
  ///
  /// In ms, this message translates to:
  /// **'Hotel & penginapan'**
  String get searchCatHotel;

  /// No description provided for @searchCatPolice.
  ///
  /// In ms, this message translates to:
  /// **'Balai polis'**
  String get searchCatPolice;

  /// No description provided for @searchCatPostOffice.
  ///
  /// In ms, this message translates to:
  /// **'Pejabat pos'**
  String get searchCatPostOffice;

  /// No description provided for @searchCatEvCharging.
  ///
  /// In ms, this message translates to:
  /// **'Pengecas EV'**
  String get searchCatEvCharging;

  /// No description provided for @searchCatTrainStation.
  ///
  /// In ms, this message translates to:
  /// **'Stesen LRT / MRT / KTM'**
  String get searchCatTrainStation;

  /// No description provided for @aiDateToday.
  ///
  /// In ms, this message translates to:
  /// **'Hari ini **{date}**.'**
  String aiDateToday(String date);

  /// No description provided for @aiTimeNow.
  ///
  /// In ms, this message translates to:
  /// **'Sekarang pukul **{time}**.'**
  String aiTimeNow(String time);

  /// No description provided for @aiUserIdentity.
  ///
  /// In ms, this message translates to:
  /// **'Saya tak tahu nama anda. FGMaps tak minta akaun atau maklumat peribadi, jadi anda kekal tanpa nama. Yang saya tahu hanyalah lokasi anda pada peta bila anda benarkan GPS. Nak saya carikan sesuatu berdekatan?'**
  String get aiUserIdentity;

  /// No description provided for @aiHowAreYou.
  ///
  /// In ms, this message translates to:
  /// **'Alhamdulillah baik, terima kasih! Saya sedia membantu anda bergerak. Nak ke mana, atau perlukan apa?'**
  String get aiHowAreYou;

  /// No description provided for @aiFarewell.
  ///
  /// In ms, this message translates to:
  /// **'Selamat jalan! Panggil saya bila-bila masa anda perlukan arah.'**
  String get aiFarewell;

  /// No description provided for @aiDrowsy.
  ///
  /// In ms, this message translates to:
  /// **'Mengantuk semasa memandu sangat bahaya. Berhenti di tempat selamat seperti stesen minyak, R&R atau surau, dan rehat sekurang-kurangnya 15 minit sebelum sambung. Mahu saya carikan?'**
  String get aiDrowsy;

  /// No description provided for @aiAskNearest.
  ///
  /// In ms, this message translates to:
  /// **'{category} terdekat'**
  String aiAskNearest(String category);

  /// No description provided for @aiAskWeather.
  ///
  /// In ms, this message translates to:
  /// **'Cuaca sekarang'**
  String get aiAskWeather;

  /// No description provided for @aiAskPrayer.
  ///
  /// In ms, this message translates to:
  /// **'Waktu solat'**
  String get aiAskPrayer;

  /// No description provided for @aiNoAnswer.
  ///
  /// In ms, this message translates to:
  /// **'Saya belum pasti jawapan untuk itu. Saya paling mahir tentang peta dan tempat: laluan, minyak, makan, farmasi, kedai gunting, ATM, cuaca, waktu solat dan kiblat. Cuba salah satu:'**
  String get aiNoAnswer;

  /// No description provided for @aiPlaceNearest.
  ///
  /// In ms, this message translates to:
  /// **'Terdekat'**
  String get aiPlaceNearest;

  /// No description provided for @aiPlaceGo.
  ///
  /// In ms, this message translates to:
  /// **'Pergi'**
  String get aiPlaceGo;

  /// No description provided for @aiTryAsking.
  ///
  /// In ms, this message translates to:
  /// **'Cuba tanya'**
  String get aiTryAsking;

  /// No description provided for @settingsLiteMode.
  ///
  /// In ms, this message translates to:
  /// **'Mod Lite (telefon lemah)'**
  String get settingsLiteMode;

  /// No description provided for @settingsLiteModeHint.
  ///
  /// In ms, this message translates to:
  /// **'Telefon ini: RAM {ram} GB · {state}. Mod Lite mematikan bangunan 3D, kesan kabur dan animasi hiasan, mengurangkan GPS ketika peta terbiar dan menyimpan bateri.'**
  String settingsLiteModeHint(String ram, String state);

  /// No description provided for @settingsLiteAuto.
  ///
  /// In ms, this message translates to:
  /// **'Auto'**
  String get settingsLiteAuto;

  /// No description provided for @settingsLiteOn.
  ///
  /// In ms, this message translates to:
  /// **'Hidup'**
  String get settingsLiteOn;

  /// No description provided for @settingsLiteOff.
  ///
  /// In ms, this message translates to:
  /// **'Mati'**
  String get settingsLiteOff;

  /// No description provided for @settingsLiteActive.
  ///
  /// In ms, this message translates to:
  /// **'Mod Lite aktif'**
  String get settingsLiteActive;

  /// No description provided for @settingsLiteInactive.
  ///
  /// In ms, this message translates to:
  /// **'Mod Lite tidak aktif'**
  String get settingsLiteInactive;

  /// No description provided for @settingsLiteModeHintNoRam.
  ///
  /// In ms, this message translates to:
  /// **'{state}. Mod Lite mematikan bangunan 3D, kesan kabur dan animasi hiasan, mengurangkan GPS ketika peta terbiar dan menyimpan bateri.'**
  String settingsLiteModeHintNoRam(String state);

  /// No description provided for @aiBrowsing.
  ///
  /// In ms, this message translates to:
  /// **'Mencari di internet…'**
  String get aiBrowsing;

  /// No description provided for @aiWebSources.
  ///
  /// In ms, this message translates to:
  /// **'Sumber web'**
  String get aiWebSources;

  /// No description provided for @aiWebResultsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Maklumat terkini: {query}'**
  String aiWebResultsTitle(String query);

  /// No description provided for @aiWebNewsTitle.
  ///
  /// In ms, this message translates to:
  /// **'Berita terkini: {query}'**
  String aiWebNewsTitle(String query);

  /// No description provided for @aiWebNothing.
  ///
  /// In ms, this message translates to:
  /// **'Saya tidak jumpa maklumat terkini tentang \"{query}\". Cuba perkataan lain atau lebih khusus.'**
  String aiWebNothing(String query);

  /// No description provided for @aiWebUnreadable.
  ///
  /// In ms, this message translates to:
  /// **'Saya tidak dapat membaca pautan itu (halaman tidak boleh dicapai, bukan HTTPS, atau tiada teks).'**
  String get aiWebUnreadable;

  /// No description provided for @aiFuelPricesTitle.
  ///
  /// In ms, this message translates to:
  /// **'Harga minyak semasa (berkuat kuasa {date})'**
  String aiFuelPricesTitle(String date);

  /// No description provided for @aiAgoMinutes.
  ///
  /// In ms, this message translates to:
  /// **'{n} min lalu'**
  String aiAgoMinutes(int n);

  /// No description provided for @aiAgoHours.
  ///
  /// In ms, this message translates to:
  /// **'{n} j lalu'**
  String aiAgoHours(int n);

  /// No description provided for @aiSearchWebAsk.
  ///
  /// In ms, this message translates to:
  /// **'Cari di internet'**
  String get aiSearchWebAsk;

  /// No description provided for @assistantAutoWebTitle.
  ///
  /// In ms, this message translates to:
  /// **'Cari di internet secara automatik'**
  String get assistantAutoWebTitle;

  /// No description provided for @assistantAutoWebSubtitle.
  ///
  /// In ms, this message translates to:
  /// **'FG AI menyemak berita, Wikipedia dan data rasmi bila soalan perlukan maklumat terkini. Permintaan \"cari online\" sentiasa dijalankan.'**
  String get assistantAutoWebSubtitle;

  /// No description provided for @aiModelRecommended.
  ///
  /// In ms, this message translates to:
  /// **'Disyorkan untuk telefon ini'**
  String get aiModelRecommended;

  /// No description provided for @aiModelTooHeavy.
  ///
  /// In ms, this message translates to:
  /// **'Terlalu berat untuk telefon ini (RAM {ram} GB)'**
  String aiModelTooHeavy(String ram);

  /// No description provided for @aiModelTooHeavyTitle.
  ///
  /// In ms, this message translates to:
  /// **'Model ini mungkin terlalu berat'**
  String get aiModelTooHeavyTitle;

  /// No description provided for @aiModelTooHeavyBody.
  ///
  /// In ms, this message translates to:
  /// **'{name} memerlukan lebih RAM daripada telefon ini ({ram} GB). Ia mungkin sangat perlahan atau ditutup oleh sistem. Teruskan muat turun?'**
  String aiModelTooHeavyBody(String name, String ram);

  /// No description provided for @agentStop.
  ///
  /// In ms, this message translates to:
  /// **'Henti'**
  String get agentStop;

  /// No description provided for @agentWorking.
  ///
  /// In ms, this message translates to:
  /// **'FG AI sedang menggunakan app…'**
  String get agentWorking;

  /// No description provided for @agentStepMap.
  ///
  /// In ms, this message translates to:
  /// **'Kembali ke peta'**
  String get agentStepMap;

  /// No description provided for @agentStepOpen.
  ///
  /// In ms, this message translates to:
  /// **'Buka {x}'**
  String agentStepOpen(String x);

  /// No description provided for @agentStepSearch.
  ///
  /// In ms, this message translates to:
  /// **'Cari \"{x}\"'**
  String agentStepSearch(String x);

  /// No description provided for @agentStepType.
  ///
  /// In ms, this message translates to:
  /// **'Taip \"{x}\"'**
  String agentStepType(String x);

  /// No description provided for @agentStepPickFirst.
  ///
  /// In ms, this message translates to:
  /// **'Pilih hasil teratas'**
  String get agentStepPickFirst;

  /// No description provided for @agentStepPickNearest.
  ///
  /// In ms, this message translates to:
  /// **'Pilih yang terdekat'**
  String get agentStepPickNearest;

  /// No description provided for @agentStepOpenSearch.
  ///
  /// In ms, this message translates to:
  /// **'Buka carian'**
  String get agentStepOpenSearch;

  /// No description provided for @agentStepCategory.
  ///
  /// In ms, this message translates to:
  /// **'Tekan {x}'**
  String agentStepCategory(String x);

  /// No description provided for @agentStepRouteReady.
  ///
  /// In ms, this message translates to:
  /// **'Tunggu laluan siap'**
  String get agentStepRouteReady;

  /// No description provided for @agentStepStart.
  ///
  /// In ms, this message translates to:
  /// **'Mula navigasi'**
  String get agentStepStart;

  /// No description provided for @agentStepRecenter.
  ///
  /// In ms, this message translates to:
  /// **'Pusatkan peta pada lokasi saya'**
  String get agentStepRecenter;

  /// No description provided for @agentReport.
  ///
  /// In ms, this message translates to:
  /// **'Laporan jalan'**
  String get agentReport;

  /// No description provided for @agentFindTitle.
  ///
  /// In ms, this message translates to:
  /// **'Cari {x}'**
  String agentFindTitle(String x);

  /// No description provided for @agentDone.
  ///
  /// In ms, this message translates to:
  /// **'Siap. Ini yang saya lakukan:'**
  String get agentDone;

  /// No description provided for @agentStopped.
  ///
  /// In ms, this message translates to:
  /// **'Dihentikan. Setakat ini:'**
  String get agentStopped;

  /// No description provided for @agentFailed.
  ///
  /// In ms, this message translates to:
  /// **'Saya tidak dapat menyiapkannya. Ini yang berlaku:'**
  String get agentFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
