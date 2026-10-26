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
  /// **'FGMap'**
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
  /// **'Lokasi anda digunakan untuk menunjukkan kedudukan anda di peta dan sebagai titik mula laluan. Ia dihantar ke pelayan FGMap hanya untuk mengira laluan.'**
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

  /// No description provided for @routeFromMapCenter.
  ///
  /// In ms, this message translates to:
  /// **'Lokasi anda tidak tersedia, jadi laluan dikira dari pusat peta.'**
  String get routeFromMapCenter;

  /// No description provided for @routeOptionLabel.
  ///
  /// In ms, this message translates to:
  /// **'Laluan {index}'**
  String routeOptionLabel(int index);

  /// No description provided for @routeAvoidTolls.
  ///
  /// In ms, this message translates to:
  /// **'Elak tol'**
  String get routeAvoidTolls;

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
  /// **'Paparan'**
  String get appearanceTooltip;

  /// No description provided for @appearanceTitle.
  ///
  /// In ms, this message translates to:
  /// **'Paparan'**
  String get appearanceTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In ms, this message translates to:
  /// **'Tentang FGMap'**
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
  /// **'Cari tempat atau alamat'**
  String get searchHint;

  /// No description provided for @searchPillHint.
  ///
  /// In ms, this message translates to:
  /// **'Cari destinasi'**
  String get searchPillHint;

  /// No description provided for @searchClear.
  ///
  /// In ms, this message translates to:
  /// **'Kosongkan'**
  String get searchClear;

  /// No description provided for @searchPrompt.
  ///
  /// In ms, this message translates to:
  /// **'Taip nama tempat, jalan atau alamat. Anda juga boleh tekan lama pada peta.'**
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
  /// **'Tiada hasil untuk “{query}”.'**
  String searchNoResults(String query);

  /// No description provided for @searchErrorNetwork.
  ///
  /// In ms, this message translates to:
  /// **'Tiada sambungan internet. Carian memerlukan internet; anda masih boleh tekan lama pada peta untuk memilih destinasi.'**
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
  /// **'Bahasa Melayu'**
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
