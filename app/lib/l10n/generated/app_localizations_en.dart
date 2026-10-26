// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FGMaps';

  @override
  String get mapHintLongPress => 'Long-press the map to choose a destination';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get myLocation => 'My location';

  @override
  String get locationFixUnavailable =>
      'GPS hasn\'t found an accurate location yet. Move to an open area and try again.';

  @override
  String locationAccuracy(int meters) {
    return 'Estimated location accuracy ±$meters m';
  }

  @override
  String get mapAttribution => '© OpenStreetMap contributors · OpenFreeMap';

  @override
  String get locationRationaleTitle => 'Allow location access?';

  @override
  String get locationRationaleBody =>
      'Your location is used to show where you are on the map and as the starting point of a route. It is sent to the FGMaps server only to calculate the route.';

  @override
  String get locationAllow => 'Allow';

  @override
  String get locationNotNow => 'Not now';

  @override
  String get locationOpenSettings => 'Open Settings';

  @override
  String get locationDeniedForeverBody =>
      'Location access is turned off. Enable it in Settings to use your current location.';

  @override
  String get locationServiceOffBody =>
      'Location services are turned off. Turn on GPS to use your current location.';

  @override
  String get routeSheetSemantics => 'Route summary';

  @override
  String get routeCalculating => 'Calculating route…';

  @override
  String get routeLocationUnavailable =>
      'Can\'t get an accurate GPS fix. Check location access and GPS, then try again.';

  @override
  String get routeHasTolls => 'Has tolls';

  @override
  String get routeNoTolls => 'No tolls';

  @override
  String get routeClear => 'Clear route';

  @override
  String get routeRetry => 'Try again';

  @override
  String get routeErrorNoRoute =>
      'No route found to this place. Try picking a nearby road.';

  @override
  String get routeErrorUnavailable =>
      'Routing is unavailable right now. Please try again shortly.';

  @override
  String get routeErrorTimeout =>
      'Calculating the route took too long. Please try again.';

  @override
  String get routeErrorNetwork =>
      'Can\'t reach the server. Check your internet connection.';

  @override
  String get routeErrorRateLimited =>
      'Too many requests. Please wait a moment.';

  @override
  String get routeErrorGeneric => 'Something went wrong. Please try again.';

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
    return '$hours h $minutes min';
  }

  @override
  String get appearanceTooltip => 'Settings';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get aboutTitle => 'About FGMaps';

  @override
  String get aboutDescription => 'Community navigation for Malaysia';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutVersionLoading => 'Loading…';

  @override
  String get aboutVersionUnavailable => 'Version information unavailable';

  @override
  String get aboutDeveloper => 'Developed by';

  @override
  String get aboutDeveloperName => 'Faiz Nasir';

  @override
  String get aboutOwner => 'Owned by';

  @override
  String get aboutOwnerName => 'FG Universal Empire Company';

  @override
  String aboutCopyright(int year) {
    return '© $year FG Universal Empire Company. All rights reserved.';
  }

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAmoled => 'AMOLED black';

  @override
  String get themeAmoledHint =>
      'Pure black background. Saves battery on OLED screens and reduces glare at night.';

  @override
  String get routeErrorOfflineRequired =>
      'No internet connection. Download the offline map to plan routes without internet.';

  @override
  String get routeErrorOfflineEngine =>
      'The offline map can\'t be used. Try downloading it again.';

  @override
  String get routeSourceOffline => 'Offline';

  @override
  String get offlineMapsOpen => 'Offline map';

  @override
  String get offlineMapsTitle => 'Offline map';

  @override
  String get offlineMapsIntro =>
      'Download the Malaysia map once to plan routes without internet. With internet, routes are planned online (more up to date) and the offline map is the fallback.';

  @override
  String get offlineMapsNotConfigured =>
      'Offline map download isn\'t configured in this build.';

  @override
  String get offlineMapsNotInstalled => 'Not downloaded';

  @override
  String offlineMapsInstalled(String date) {
    return 'Installed: $date';
  }

  @override
  String offlineMapsSize(String size) {
    return 'Download size $size';
  }

  @override
  String offlineMapsUpdateAvailable(String date) {
    return 'Update available: $date';
  }

  @override
  String get offlineMapsUpToDate => 'Offline map is up to date';

  @override
  String get offlineMapsDownload => 'Download';

  @override
  String get offlineMapsRetry => 'Try again';

  @override
  String get offlineMapsUpdate => 'Update';

  @override
  String get offlineMapsDelete => 'Delete';

  @override
  String get offlineMapsCancel => 'Cancel';

  @override
  String get offlineMapsChecking => 'Checking…';

  @override
  String offlineMapsDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get offlineMapsVerifying => 'Verifying file…';

  @override
  String get offlineMapsInstalling => 'Installing…';

  @override
  String get offlineMapsMobileDataTitle => 'Use mobile data?';

  @override
  String offlineMapsMobileDataBody(String size) {
    return 'This download is about $size. You\'re not connected to Wi-Fi.';
  }

  @override
  String get offlineMapsDeleteTitle => 'Delete offline map?';

  @override
  String get offlineMapsDeleteBody =>
      'You\'ll need to download it again to use offline routing.';

  @override
  String get offlineMapsErrorNetwork =>
      'Couldn\'t connect to the offline map server. Check your internet and try again.';

  @override
  String get offlineMapsErrorStorage =>
      'Not enough storage. Free some space and try again.';

  @override
  String get offlineMapsErrorChecksum =>
      'The downloaded file is corrupted. Try again.';

  @override
  String get offlineMapsErrorIncompatible =>
      'This offline map isn\'t compatible with this app version. Update the app.';

  @override
  String get offlineMapsErrorInvalid =>
      'The offline map information is invalid.';

  @override
  String get offlineMapsErrorGeneric =>
      'Something went wrong. Please try again.';

  @override
  String get routingModeTitle => 'Route source';

  @override
  String get routingModeAuto => 'Auto';

  @override
  String get routingModeOnline => 'Online only';

  @override
  String get routingModeOffline => 'Offline only';

  @override
  String get routingModeAutoHint =>
      'Online first; falls back to the offline map if that fails.';

  @override
  String get tripPlannerTitle => 'Plan a trip';

  @override
  String get tripFrom => 'From';

  @override
  String get tripTo => 'To';

  @override
  String get searchHint => 'Search a place or address';

  @override
  String get searchPillHint => 'Search destination';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchPrompt =>
      'Type a place, street or address. You can also long-press the map.';

  @override
  String get searchHistory => 'Recent places';

  @override
  String get searchClearHistory => 'Clear history';

  @override
  String get sharedLocationStopNavigation =>
      'End the current navigation before opening a shared destination.';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”.';
  }

  @override
  String searchNoNearby(String category) {
    return 'No “$category” found nearby in OpenStreetMap. Try a larger area or search by name.';
  }

  @override
  String searchNearbySaved(String when) {
    return 'Can’t reach the map data servers. Showing saved results from $when.';
  }

  @override
  String get searchErrorNetwork =>
      'No internet connection. Search needs internet; you can still long-press the map to pick a destination.';

  @override
  String get searchErrorRateLimited =>
      'Too many searches. Please wait a moment.';

  @override
  String get searchErrorUnavailable => 'Search is unavailable right now.';

  @override
  String routeFromTo(String from, String to) {
    return '$from → $to';
  }

  @override
  String get navStart => 'Start';

  @override
  String get navSimulate => 'Simulate';

  @override
  String get navEnd => 'End';

  @override
  String get navEndTitle => 'End navigation?';

  @override
  String get navEndKeep => 'Keep going';

  @override
  String get navDone => 'Done';

  @override
  String get navArrived => 'You have arrived';

  @override
  String get navArrivalSub => 'Arrived at your destination';

  @override
  String get navRerouting => 'Recalculating…';

  @override
  String get navRerouteRetry => 'No connection. Retrying…';

  @override
  String get navGpsWeak => 'Weak GPS signal';

  @override
  String get navLocationLost =>
      'Location unavailable. Check location permission.';

  @override
  String get navRecenter => 'Recenter';

  @override
  String get navMute => 'Mute voice';

  @override
  String get navUnmute => 'Unmute voice';

  @override
  String get navOverview => 'Show whole route';

  @override
  String get navCameraAuto => 'Auto 3D/2D camera';

  @override
  String get navCameraFlat => '2D camera';

  @override
  String get navCameraTilted => '3D camera';

  @override
  String get navThen => 'Then';

  @override
  String get navSimulatedBadge => 'Simulation';

  @override
  String get navSpeedUnit => 'km/h';

  @override
  String get navSpeedLabel => 'Speed';

  @override
  String get navSettingsTitle => 'Navigation settings';

  @override
  String get navVoiceTitle => 'Voice guidance';

  @override
  String get navVoiceLanguage => 'Voice language';

  @override
  String get navVoiceFollowApp => 'Follow app';

  @override
  String get navVoiceMalay => 'Malay';

  @override
  String get navVoiceEnglish => 'English';

  @override
  String get navCameraTitle => 'Camera view';

  @override
  String get navCameraAutoHint =>
      '3D on straights, 2D approaching turns and roundabouts';

  @override
  String get navSettingsOpen => 'Navigation settings';

  @override
  String get navContinue => 'Continue';

  @override
  String navEta(String time) {
    return 'Arrive $time';
  }

  @override
  String get navAcquiring => 'Finding GPS signal…';

  @override
  String get routeFastest => 'Fastest';

  @override
  String get routeShortest => 'Shortest';

  @override
  String get routeNoHighways => 'No highways';

  @override
  String get routeAlternative => 'Alternative';

  @override
  String routeVia(String road) {
    return 'via $road';
  }

  @override
  String routeFindingTo(String place) {
    return 'Finding routes to $place…';
  }

  @override
  String get routeVehicleCar => 'Car';

  @override
  String get routeVehicleMotorcycle => 'Motorcycle';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsMaps => 'Maps';

  @override
  String get settingsOfflineHint =>
      'Download maps to navigate without internet';

  @override
  String get settingsAboutHint => 'Version, developer and copyright';

  @override
  String get themeSystemShort => 'System';

  @override
  String get searchCatFuel => 'Fuel';

  @override
  String get searchCatFood => 'Food';

  @override
  String get searchCatMosque => 'Mosque';

  @override
  String get searchCatToilet => 'Toilets';

  @override
  String get searchCatParking => 'Parking';

  @override
  String get searchCatHospital => 'Hospital';

  @override
  String get placeKindShopping => 'Shopping';

  @override
  String get placeKindFuel => 'Petrol station';

  @override
  String get placeKindFood => 'Food';

  @override
  String get placeKindWorship => 'Place of worship';

  @override
  String get placeKindHealth => 'Health';

  @override
  String get placeKindParking => 'Parking';

  @override
  String get placeKindToilets => 'Toilets';

  @override
  String get placeKindTransit => 'Bus stop or station';

  @override
  String get placeKindRoad => 'Road';

  @override
  String get placeKindArea => 'Area';

  @override
  String get placeKindAddress => 'Address';

  @override
  String get placeKindPlace => 'Place';

  @override
  String get placeOppositeSide => 'opposite side of the road';

  @override
  String get themeSun => 'Sun';

  @override
  String get themeSunHint =>
      'Dark between sunset and sunrise at your location. Calculated on your device, no internet needed.';

  @override
  String get savedHome => 'Home';

  @override
  String get savedWork => 'Work';

  @override
  String get savedFavorite => 'Favourite';

  @override
  String get savedSetHome => 'Set home';

  @override
  String get savedSetWork => 'Set work';

  @override
  String get savedSection => 'Saved places';

  @override
  String get savedSaveTooltip => 'Save place';

  @override
  String get savedSheetTitle => 'Save as';

  @override
  String get savedChange => 'Change';

  @override
  String get savedRemove => 'Remove';

  @override
  String get savedTapToSet => 'Tap to set';

  @override
  String get savedFavoriteAdd => 'Add to favourites';

  @override
  String get savedFavoriteRemove => 'Remove from favourites';

  @override
  String savedAssigning(String kind) {
    return 'Search for your $kind address';
  }

  @override
  String savedDone(String label) {
    return 'Saved as $label';
  }

  @override
  String savedRemoved(String label) {
    return '$label removed';
  }

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbStart => 'Get started';

  @override
  String get onbWelcomeTitle => 'Navigation for Malaysia';

  @override
  String get onbWelcomeBody =>
      'Turn-by-turn guidance for car and motorcycle, with voice in Malay or English.';

  @override
  String get onbFeatureRoutes => 'Fastest, no-toll and alternative routes';

  @override
  String get onbFeatureNearby => 'Find petrol, food, surau and toilets nearby';

  @override
  String get onbFeatureReports => 'Report hazards and police on the road';

  @override
  String get onbFeatureOffline => 'Offline maps for when you have no signal';

  @override
  String get onbPrivacyTitle => 'Your privacy';

  @override
  String get onbPrivacyLocal =>
      'No account and no tracking. Your places, history and reports stay on this phone.';

  @override
  String get onbPrivacyServers =>
      'To search and plan routes, the app sends your search text and trip coordinates to public OpenStreetMap services. Nothing else is sent.';

  @override
  String get onbPrivacyLocation =>
      'Location is used only while the app is open, to show where you are and to guide you.';

  @override
  String get onbSetupTitle => 'Set up in 10 seconds';

  @override
  String get onbVehicleQuestion => 'How do you travel?';

  @override
  String get onbVoiceQuestion => 'Voice language';

  @override
  String get onbAllowLocation => 'Allow location';

  @override
  String get onbLocationGranted => 'Location allowed';

  @override
  String get onbLocationHint =>
      'You can also do this later when you start your first trip.';

  @override
  String onbPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeHint =>
      'Applied on top of your phone’s text size.';

  @override
  String get settingsReduceMotion => 'Reduce animations';

  @override
  String get settingsReduceMotionHint =>
      'Fewer moving effects. Also follows your phone’s setting.';

  @override
  String get settingsHaptics => 'Vibration feedback';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsLanguageSystem => 'Device';

  @override
  String get settingsLanguageMalay => 'Bahasa Melayu';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsVoice => 'Voice';

  @override
  String get settingsVoiceVolume => 'Voice volume';

  @override
  String get settingsVolumeLow => 'Low';

  @override
  String get settingsVolumeMedium => 'Medium';

  @override
  String get settingsVolumeHigh => 'High';

  @override
  String get settingsSpeechRate => 'Speaking speed';

  @override
  String get settingsRateSlow => 'Slow';

  @override
  String get settingsRateNormal => 'Normal';

  @override
  String get settingsRateFast => 'Fast';

  @override
  String get settingsReports => 'Reports';

  @override
  String get settingsReportAlerts => 'Report alerts while driving';

  @override
  String get settingsReportAlertsHint =>
      'Announces reports ahead and asks if they are still there.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsLocationAllowed => 'Location access: allowed';

  @override
  String get settingsLocationNotAllowed => 'Location access: not allowed';

  @override
  String get settingsLocationOff => 'Location services are off';

  @override
  String get settingsLocationOpen => 'Open phone settings';

  @override
  String get settingsClearHistory => 'Clear search history';

  @override
  String get settingsClearSaved => 'Delete saved places';

  @override
  String get settingsClearReports => 'Delete my reports';

  @override
  String get settingsConfirmTitle => 'Delete this data?';

  @override
  String get settingsConfirmBody =>
      'This only affects this phone and cannot be undone.';

  @override
  String get settingsConfirmDelete => 'Delete';

  @override
  String get settingsConfirmCancel => 'Cancel';

  @override
  String get settingsDeleted => 'Deleted';

  @override
  String get settingsHelp => 'Help & about';

  @override
  String get settingsWelcomeAgain => 'Show the welcome tour again';

  @override
  String get settingsLicences => 'Open-source licences';

  @override
  String get searchCategories => 'Search nearby';

  @override
  String get reportTitle => 'Report here';

  @override
  String get reportButtonTooltip => 'Report';

  @override
  String get reportTypePolice => 'Police';

  @override
  String get reportTypeAccident => 'Accident';

  @override
  String get reportTypeHazard => 'Hazard';

  @override
  String get reportTypeJam => 'Traffic jam';

  @override
  String get reportTypeClosed => 'Road closed';

  @override
  String get reportTypeBrokenDown => 'Broken-down vehicle';

  @override
  String get reportTypeFlood => 'Flood';

  @override
  String get reportCreated => 'Report sent. Thank you!';

  @override
  String get reportConfirmedExisting =>
      'A similar report is already nearby; it has been confirmed.';

  @override
  String get reportNoLocation =>
      'Your location isn\'t available. Reports must be made from your real location.';

  @override
  String get reportLocalOnlyNote =>
      'Reports are stored on this device only and aren\'t shared with other drivers yet.';

  @override
  String reportStillThereTitle(String type) {
    return 'Is the $type still there?';
  }

  @override
  String get reportStillThereYes => 'Yes, still there';

  @override
  String get reportStillThereNo => 'It\'s gone';

  @override
  String reportAhead(String type, String distance) {
    return '$type $distance ahead';
  }

  @override
  String get navSpeedLimit => 'Speed limit';

  @override
  String get navOverspeedTitle => 'Speeding alert';

  @override
  String get navOverspeedOff => 'Off';

  @override
  String get navOverspeedHint =>
      'Chime and red sign when over the speed limit. Limits are not available on every road.';
}
