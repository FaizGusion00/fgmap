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
  /// **'© penyumbang OpenStreetMap · OpenFreeMap'**
  String get mapAttribution;

  /// No description provided for @locationRationaleTitle.
  ///
  /// In ms, this message translates to:
  /// **'Benarkan akses lokasi?'**
  String get locationRationaleTitle;

  /// No description provided for @locationRationaleBody.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar ke pelayan FGMaps hanya untuk mengira laluan.'**
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
  /// **'Muat turun peta Malaysia sekali supaya laluan boleh dikira tanpa internet. Dengan internet, laluan dikira secara online (lebih terkini) dan peta offline menjadi sandaran.'**
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
  /// **'Anda perlu memuat turunnya semula untuk menggunakan laluan offline.'**
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
  /// **'Masjid'**
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
  /// **'Notifikasi azan'**
  String get azanEnable;

  /// No description provided for @azanEnableHint.
  ///
  /// In ms, this message translates to:
  /// **'Beritahu saya setiap kali masuk waktu solat di lokasi semasa.'**
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
  /// **'Taip nama lagu atau artis, kemudian ketik untuk main. Lagu daripada Audius (katalog terbuka, percuma).'**
  String get musicEmptySongs;

  /// No description provided for @musicEmptyRadio.
  ///
  /// In ms, this message translates to:
  /// **'Stesen radio Malaysia. Ketik untuk dengar siaran langsung.'**
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

  /// No description provided for @searchCategories.
  ///
  /// In ms, this message translates to:
  /// **'Cari berhampiran'**
  String get searchCategories;

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
  /// **'Data peta © penyumbang OpenStreetMap (ODbL). Gaya dan jubin: OpenFreeMap, OpenMapTiles. Laluan: Valhalla. Carian: Photon (komoot) dan Nominatim. Harga petrol: data.gov.my. Muzik: Audius (Open Music License) dan Radio Browser; strim radio daripada stesen masing-masing. Rakaman azan: Aaqib Azeez / Atcovi, Wikimedia Commons, CC BY-SA 4.0.'**
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
