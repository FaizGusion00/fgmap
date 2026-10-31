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
      'Your location is used to show where you are on the map and as the starting point of a route. It is sent directly to the public routing service only to calculate the route, and is not stored on any server of ours.';

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
  String get searchHint => 'Place, address, coordinates or Maps link';

  @override
  String get searchPillHint => 'Where to?';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchPrompt =>
      'Type a place name, or pick Home / Work below. You can also paste coordinates (3.14, 101.68) or a Google Maps / Waze link.';

  @override
  String get searchHistory => 'Recent places';

  @override
  String get searchClearHistory => 'Clear history';

  @override
  String get sharedLocationStopNavigation =>
      'End the current navigation before opening a shared destination.';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”. Paste coordinates or a Google Maps / Waze link — we only need lat/lng.';
  }

  @override
  String searchNoNearby(String category) {
    return 'No “$category” found nearby in OpenStreetMap. Try a larger area or search by name.';
  }

  @override
  String get searchNearbyRefining => 'Searching farther…';

  @override
  String get searchNeedLocation =>
      'Your location isn’t known yet. Turn on location to find places nearby.';

  @override
  String searchNearbySaved(String when) {
    return 'Can’t reach the map data servers. Showing saved results from $when.';
  }

  @override
  String get searchErrorNetwork =>
      'No internet connection. Search needs internet; you can still paste coordinates or a Maps link.';

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
  String get navSimSpeedTitle => 'Simulation speed';

  @override
  String get navSimSpeedHint =>
      'Pick a cruise speed. Auto follows the route estimate (can be ~18 km/h in town). During simulation, use 1×–4× to go faster.';

  @override
  String get navSimSpeedAuto => 'Auto';

  @override
  String navSimSpeedKmh(int kmh) {
    return '$kmh km/h';
  }

  @override
  String navSimSpeedMult(int n) {
    return '$n×';
  }

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
  String get navGpsEstimating => 'No GPS signal. Position is estimated.';

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
  String get navChangeRoute => 'Change route';

  @override
  String get navRoutesTitle => 'Choose a route from here';

  @override
  String get navRoutesCurrent => 'Current route';

  @override
  String get navRoutesLoading => 'Finding routes from your location…';

  @override
  String get navRoutesError => 'Couldn\'t find other routes right now.';

  @override
  String get navRoutesNone => 'No other routes from here.';

  @override
  String get navRoutesSame => 'Same time';

  @override
  String navRoutesFaster(String time) {
    return '$time faster';
  }

  @override
  String navRoutesSlower(String time) {
    return '$time slower';
  }

  @override
  String get navRoutesSwitched => 'Route changed';

  @override
  String get navCameraAuto => 'Auto 3D/2D camera';

  @override
  String get navCameraFlat => '2D camera';

  @override
  String get navCameraTilted => '3D camera';

  @override
  String get navThen => 'Then';

  @override
  String navRoundaboutExitSemantics(int n) {
    return 'Roundabout, take exit $n';
  }

  @override
  String get navLaneLeft => 'Use the left lane';

  @override
  String get navLaneRight => 'Use the right lane';

  @override
  String navLaneStripSemantics(String lanes) {
    return 'Lanes: $lanes';
  }

  @override
  String get navLaneUse => 'Use the marked lane';

  @override
  String get navGetReady => 'Get ready';

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
  String get settingsEasyMode => 'Easy mode';

  @override
  String get settingsEasyModeHint =>
      'Bigger text and buttons, high-contrast instruction card, fewer controls while driving. Good for older drivers.';

  @override
  String get onbEasyMode => 'Large & simple display';

  @override
  String get onbEasyModeHint =>
      'Bigger text, clearer instructions, fewer buttons. Change it any time in Settings.';

  @override
  String get navGpsWeakHint => 'Keep driving. We are looking for a signal.';

  @override
  String get routeMoreOptions => 'More';

  @override
  String get settingsAzan => 'Prayer times (Azan)';

  @override
  String get azanTitle => 'Prayer times';

  @override
  String get azanEnable => 'Always remind me of prayer times';

  @override
  String get azanEnableHint =>
      'A notification with the azan at every prayer time, even when the app is closed.';

  @override
  String get azanPrayerFajr => 'Fajr';

  @override
  String get azanPrayerSunrise => 'Sunrise';

  @override
  String get azanPrayerDhuhr => 'Dhuhr';

  @override
  String get azanPrayerAsr => 'Asr';

  @override
  String get azanPrayerMaghrib => 'Maghrib';

  @override
  String get azanPrayerIsha => 'Isha';

  @override
  String get azanPrayersLabel => 'Prayers to notify';

  @override
  String get azanSoundLabel => 'Sound';

  @override
  String get azanSoundFull => 'Full azan';

  @override
  String get azanSoundShort => 'Short tone';

  @override
  String get azanSoundSilent => 'Silent';

  @override
  String get azanSoundHint =>
      'Full azan is the default. Choose a short tone or silent for a quieter reminder.';

  @override
  String get azanMethodLabel => 'Calculation method';

  @override
  String get azanMethodJakim => 'JAKIM (Malaysia)';

  @override
  String get azanMethodMwl => 'Muslim World League';

  @override
  String get azanMethodEgyptian => 'Egyptian';

  @override
  String get azanMethodKarachi => 'Karachi';

  @override
  String get azanMethodUmmAlQura => 'Umm al-Qura (Makkah)';

  @override
  String get azanMadhabLabel => 'Madhab (Asr time)';

  @override
  String get azanMadhabShafi => 'Shafi\'i';

  @override
  String get azanMadhabHanafi => 'Hanafi';

  @override
  String get azanReminderLabel => 'Early reminder';

  @override
  String get azanReminderNone => 'None';

  @override
  String azanReminderMinutes(int n) {
    return '$n min before';
  }

  @override
  String get azanPlayDuringNav => 'Play full azan while navigating';

  @override
  String get azanPlayDuringNavHint =>
      'If off: only a short tone and a chip on the HUD so voice guidance stays clear. The notification is still sent.';

  @override
  String get azanLocationLabel => 'Location';

  @override
  String get azanLocationAuto => 'Follow device location';

  @override
  String get azanLocationCity => 'Choose a city';

  @override
  String get azanLocationAutoHint =>
      'Calculated on this phone from your location (rounded to ~1 km). Nothing is sent.';

  @override
  String azanNextIn(String prayer, String time, String remaining) {
    return '$prayer $time · in $remaining';
  }

  @override
  String azanNextPrayer(String prayer, String time) {
    return 'Next: $prayer at $time';
  }

  @override
  String get azanAllDone => 'All of today\'s prayer times have passed';

  @override
  String azanNowTitle(String prayer) {
    return '$prayer time';
  }

  @override
  String get azanNowBody => 'It is now time to pray.';

  @override
  String get azanStop => 'Stop azan';

  @override
  String get azanListen => 'Listen to azan';

  @override
  String get azanStopListening => 'Stop';

  @override
  String azanEstimateNote(String method) {
    return 'Estimated by astronomical calculation ($method). The official JAKIM e-Solat timetable may differ by a few minutes; follow it for fasting times.';
  }

  @override
  String get azanExactAlarmTitle => 'Allow exact alarms';

  @override
  String get azanExactAlarmBody =>
      'Without this permission Android may delay the notification by a few minutes.';

  @override
  String get azanExactAlarmAction => 'Open settings';

  @override
  String get azanPermissionDenied =>
      'Notifications are not allowed. Allow them in your phone settings to receive the azan.';

  @override
  String azanReminderTitle(String prayer, int n) {
    return '$prayer in $n minutes';
  }

  @override
  String get azanReminderBody => 'Get ready to pray.';

  @override
  String get azanChannelFull => 'Azan (full)';

  @override
  String get azanChannelShort => 'Azan (short tone)';

  @override
  String get azanChannelSilent => 'Azan (silent)';

  @override
  String get azanChannelReminder => 'Prayer reminders';

  @override
  String get azanOpenSettings => 'Azan settings';

  @override
  String azanRemainingHours(int h, int m) {
    return '$h h $m min';
  }

  @override
  String azanRemainingMinutes(int m) {
    return '$m min';
  }

  @override
  String azanForCity(String city) {
    return 'For $city';
  }

  @override
  String get azanForCurrentLocation => 'For current location';

  @override
  String get azanNotNow => 'Not now';

  @override
  String get settingsMusic => 'Music';

  @override
  String get musicTitle => 'Music';

  @override
  String get musicOpen => 'Music';

  @override
  String get musicSearchHint => 'Search songs, artists or radio…';

  @override
  String get musicTabSongs => 'Songs';

  @override
  String get musicTabRadio => 'Radio';

  @override
  String get musicTabLocal => 'My files';

  @override
  String get musicEmptySongs =>
      'Type a song or artist, or tap a suggestion above. The free Audius catalogue is independent music; major-label songs are not here. For those, tap Spotify or YouTube Music above to search in your own app, or try the Radio tab.';

  @override
  String get musicEmptyRadio =>
      'Pick a region above, or type a station name (e.g. Hitz, Prambors, KBS). Tap to listen live.';

  @override
  String get musicEmptyLocal =>
      'Import songs from your phone. They are stored in the app and always play without internet.';

  @override
  String musicNoResults(String query) {
    return 'No results for “$query”.';
  }

  @override
  String get musicOffline => 'No internet. Only your files can be played.';

  @override
  String musicErrorSource(String source) {
    return '$source cannot be reached right now.';
  }

  @override
  String get musicImport => 'Import from phone';

  @override
  String musicImported(int n) {
    return '$n songs added';
  }

  @override
  String get musicRemove => 'Remove';

  @override
  String get musicLive => 'LIVE';

  @override
  String get musicViaAudius => 'via Audius';

  @override
  String get musicAttribution =>
      'Songs from Audius · Radio from Radio Browser · Your files stay on your phone';

  @override
  String get musicNowPlaying => 'Now playing';

  @override
  String get musicPlay => 'Play';

  @override
  String get musicPause => 'Pause';

  @override
  String get musicNext => 'Next';

  @override
  String get musicPrevious => 'Previous';

  @override
  String get musicStop => 'Close player';

  @override
  String get musicVolume => 'Volume';

  @override
  String get musicQueue => 'Queue';

  @override
  String get musicEqualizer => 'Equalizer';

  @override
  String get musicEqPresetNormal => 'Normal';

  @override
  String get musicEqPresetBass => 'Bass';

  @override
  String get musicEqPresetTreble => 'Treble';

  @override
  String get musicEqPresetVocal => 'Voice';

  @override
  String get musicEqPresetCustom => 'Custom';

  @override
  String get musicEqUnsupported =>
      'The equalizer is only available on Android.';

  @override
  String get musicEqEnable => 'Enable equalizer';

  @override
  String get musicDuckTitle => 'While navigation voice speaks';

  @override
  String get musicDuckLower => 'Lower the music';

  @override
  String get musicDuckLowerHint =>
      'Default. Music gets quieter during an instruction, then recovers.';

  @override
  String get musicDuckPause => 'Pause the music';

  @override
  String get musicDuckPauseHint =>
      'Music stops completely during an instruction, then resumes.';

  @override
  String get musicOpenPlayer => 'Open Music';

  @override
  String get musicClearLocal => 'Delete all my files';

  @override
  String get musicSourceAudius => 'Audius';

  @override
  String get musicSourceAppleMusic => 'Apple Music';

  @override
  String get musicViaAppleMusic => 'via Apple Music';

  @override
  String get musicAppleConnectTitle => 'Full songs with Apple Music';

  @override
  String get musicAppleConnectBody =>
      'Connect your Apple Music subscription to search and play full Malay, Indonesian, Japanese and K-pop songs. Search and playback go straight through Apple; FGMaps never sees your account.';

  @override
  String get musicAppleConnect => 'Connect Apple Music';

  @override
  String get musicAppleDenied =>
      'Apple Music access was declined. Turn it on in iPhone Settings > FGMaps > Media & Apple Music.';

  @override
  String get musicAppleNeedsSubscription =>
      'Full songs need an active Apple Music subscription. Subscribe in the Apple Music app, then reopen this tab.';

  @override
  String get musicAppleUnavailable =>
      'Apple Music can\'t play on this account.';

  @override
  String get musicOpenSpotify => 'Spotify';

  @override
  String get musicOpenYoutubeMusic => 'YouTube Music';

  @override
  String get musicExternalHint =>
      'Search full songs in your own app (FGMaps only opens the search):';

  @override
  String get musicExternalFailed => 'Couldn\'t open that app or a browser.';

  @override
  String get musicSourceDevice => 'Phone music';

  @override
  String get musicViaDevice => 'on this phone';

  @override
  String get musicDeviceTitle => 'Music on your phone';

  @override
  String get musicDeviceBody =>
      'Play the songs already on your phone. FGMaps only reads titles and artists on the device; nothing is sent anywhere.';

  @override
  String get musicDeviceAllow => 'Allow music access';

  @override
  String get musicDeviceDenied =>
      'Music access was declined. Turn it on for FGMaps in your phone\'s Settings.';

  @override
  String get musicSourceRadio => 'Radio Browser';

  @override
  String get musicSourceLocal => 'My files';

  @override
  String get musicLoading => 'Loading…';

  @override
  String get musicError => 'Cannot play this. Try another song.';

  @override
  String get musicDucked => 'Navigation voice';

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
  String get splashTagline => 'Community navigation for Malaysia';

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

  @override
  String get savedBySearch => 'Search for an address';

  @override
  String get savedBySearchHint => 'Type a place name or address';

  @override
  String get savedByCurrent => 'Use current location';

  @override
  String get savedByCurrentHint => 'Save where you are right now';

  @override
  String get savedCurrentLocation => 'Current location';

  @override
  String get savedLocating => 'Finding your location…';

  @override
  String get savedGoHint => 'Tap to start navigating · long-press to change';

  @override
  String get autoStartCancel => 'Cancel';

  @override
  String get navThemeTitle => 'Map appearance';

  @override
  String get settingsSavedPlaces => 'Home and Work';

  @override
  String get savedNotSet => 'Not set';

  @override
  String autoStartCountdown(String name, int seconds) {
    return 'Starting navigation to $name in $seconds…';
  }

  @override
  String get routeRecommended => 'Recommended';

  @override
  String get routeSimplest => 'Simplest';

  @override
  String get routeSearchingMore => 'Finding other routes…';

  @override
  String get routeHasHighway => 'Highway';

  @override
  String get routeHasFerry => 'Ferry';

  @override
  String routeTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns',
      one: '1 turn',
      zero: 'No turns',
    );
    return '$_temp0';
  }

  @override
  String routeCount(int count) {
    return '$count routes';
  }

  @override
  String routeMore(int count) {
    return '$count more';
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
    return '$count plazas';
  }

  @override
  String routeTollEstimateExact(String amount) {
    return 'Toll RM $amount';
  }

  @override
  String routeTollEstimatePartial(String amount) {
    return 'Toll RM $amount+ (partial)';
  }

  @override
  String routeTollPlazasUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count toll plazas',
      one: '1 toll plaza',
    );
    return '$_temp0, price unknown';
  }

  @override
  String routeTollOn(String roads) {
    return 'Toll: $roads';
  }

  @override
  String get routeTollDisclaimer =>
      'Estimate for cars (class 1) from Malaysian Highway Authority rates; check the price at the plaza.';

  @override
  String get settingsClearAll => 'Delete all my data';

  @override
  String get settingsClearAllHint =>
      'Search history, saved places, reports and cached location data on this device.';

  @override
  String get legalPrivacyTitle => 'Privacy Policy';

  @override
  String get legalTermsTitle => 'Terms of Use';

  @override
  String get legalLoadFailed => 'The document could not be loaded.';

  @override
  String get legalDraftNotice =>
      'Draft: this document has not been reviewed by a lawyer and is not legal advice.';

  @override
  String get legalConsent =>
      'By continuing you agree to the Terms of Use and the Privacy Policy.';

  @override
  String get legalAttribution =>
      'Map data © OpenStreetMap contributors (ODbL). Style and tiles: OpenFreeMap, OpenMapTiles. Routing: Valhalla. Search: Photon (komoot) and Nominatim. Fuel prices: data.gov.my. Prayer times: JAKIM e-Solat via the WaktuSolat API (api.waktusolat.app), and Adhan calculation. Music: Audius (Open Music License), Radio Browser, and Apple Music on iPhone (subscribers, via Apple\'s MusicKit); radio streams come from the stations themselves. Azan recording: Aaqib Azeez / Atcovi, Wikimedia Commons, CC BY-SA 4.0.';

  @override
  String get aboutAttributionTitle => 'Data sources';

  @override
  String get settingsFuel => 'Fuel cost';

  @override
  String get fuelTypeRon95 => 'RON95';

  @override
  String get fuelTypeRon97 => 'RON97';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelConsumptionCar => 'Car consumption (L/100 km)';

  @override
  String get fuelConsumptionMoto => 'Motorcycle consumption (L/100 km)';

  @override
  String get fuelManualPrice => 'My price per litre (RM)';

  @override
  String get fuelManualPriceHint =>
      'Leave empty to use the data.gov.my price. Fill it in if you pay a different price (e.g. subsidised RON95).';

  @override
  String get fuelPriceUnavailable =>
      'The latest price could not be fetched. Enter your own price to see a fuel cost estimate.';

  @override
  String get fuelEstimateNote =>
      'Fuel cost estimate based on distance, consumption and the price above.';

  @override
  String get shareDestinationTooltip => 'Share destination';

  @override
  String get shareEtaAction => 'Share arrival time';

  @override
  String get shareFailed => 'Couldn\'t open the share sheet.';

  @override
  String get emergencyTooltip => 'Emergency';

  @override
  String get emergencyTitle => 'Emergency';

  @override
  String get emergencyBody =>
      'In an emergency, call directly. This button is only a shortcut and does not guarantee a call, an accurate location or that help arrives.';

  @override
  String get emergencyCall999 => 'Call 999';

  @override
  String get emergencyCall999Hint => 'Police, fire, ambulance';

  @override
  String get emergencyCall112 => 'Call 112';

  @override
  String get emergencyCall112Hint =>
      'International emergency number for mobile phones';

  @override
  String get emergencyConfirmCall => 'Call';

  @override
  String get emergencyConfirmBody =>
      'The dialler will open. Press the call button to connect.';

  @override
  String get emergencyShareLocation => 'Share my exact location';

  @override
  String get emergencyNoLocation =>
      'Your location isn\'t known yet. Try somewhere open or turn on location.';

  @override
  String routeFuelCost(String amount) {
    return '≈ RM $amount fuel';
  }

  @override
  String fuelPriceSource(String price, String date) {
    return 'data.gov.my price: RM $price/L ($date)';
  }

  @override
  String emergencyConfirmTitle(String number) {
    return 'Call $number now?';
  }

  @override
  String shareDestinationText(
    String name,
    String eta,
    String duration,
    String distance,
    String link,
  ) {
    return 'I\'m heading to $name. Estimated arrival $eta ($duration, $distance).\n$link';
  }

  @override
  String shareEtaText(String name, String eta, String distance, String link) {
    return 'I\'m on my way to $name. Estimated arrival $eta, $distance to go.\n$link';
  }

  @override
  String emergencyShareText(String coords, String link) {
    return 'I need help. My location: $coords\n$link';
  }

  @override
  String emergencyDialFailed(String number) {
    return 'Couldn\'t open the dialler. Dial $number manually.';
  }

  @override
  String get errorWidgetMessage => 'This part couldn\'t be displayed.';

  @override
  String get settingsCopyErrorReport => 'Copy error report';

  @override
  String get settingsCopyErrorReportHint =>
      'The error log is kept on this phone only and is never sent. Copy and send it yourself if needed.';

  @override
  String get settingsErrorReportCopied => 'Error report copied';

  @override
  String get settingsErrorReportEmpty => 'No errors recorded';

  @override
  String azanEnabledSnack(String source) {
    return 'Azan turned on. $source';
  }

  @override
  String azanSourceOfficial(String zone) {
    return 'Official JAKIM e-Solat times, zone $zone';
  }

  @override
  String azanSourceCalculated(String method) {
    return 'Calculated on this phone ($method)';
  }

  @override
  String get azanDeniedTitle => 'Notifications are off';

  @override
  String get azanDeniedBody =>
      'Without notification permission the azan cannot play while the app is closed. Open settings and allow notifications for FGMaps.';

  @override
  String get azanOpenAppSettings => 'Open settings';

  @override
  String get azanExactDialogTitle => 'Allow exact alarms';

  @override
  String get azanExactDialogBody =>
      'So the azan plays exactly on time and not minutes late, allow “Alarms & reminders” for FGMaps on the next screen.';

  @override
  String get azanNotificationsOffTitle => 'Azan notifications are off';

  @override
  String get azanNotificationsOffBody =>
      'The azan will not play while the app is closed until you allow notifications again.';

  @override
  String get azanBatteryTitle =>
      'Make sure the azan plays when the app is closed';

  @override
  String get azanBatteryBody =>
      'Some phones stop apps in the background. If the azan does not play, allow FGMaps to run without battery restrictions.';

  @override
  String get azanBatteryAction => 'Open battery settings';

  @override
  String get azanLocationUnknown =>
      'Location not known yet. Times are for Kuala Lumpur. Allow location or choose a city below.';

  @override
  String get azanUseOfficial => 'Official JAKIM times';

  @override
  String get azanUseOfficialHint =>
      'Fetch the official e-Solat timetable over the internet (only a ~1 km location is sent). Offline, times are calculated on the phone.';

  @override
  String get onbAzan => 'Remind me of prayer times';

  @override
  String get onbAzanHint =>
      'A notification and the azan at every prayer time, even when the app is closed. We will ask for notification permission.';

  @override
  String get musicRegionMalaysia => 'Malaysia';

  @override
  String get musicRegionIndonesia => 'Indonesia';

  @override
  String get musicRegionFavorites => 'Favourites';

  @override
  String get musicEmptyFavorites =>
      'No favourite stations yet. Tap the star on any station to keep it here.';

  @override
  String get musicFavoriteAdd => 'Add to favourites';

  @override
  String get musicFavoriteRemove => 'Remove from favourites';

  @override
  String get musicRadioUnreachable => 'Couldn\'t connect earlier';

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
      'The free Audius catalogue is independent music; major-label songs are not here. Tap Spotify or YouTube Music above to search in your own app, or try Radio.';

  @override
  String get musicTryRadio => 'Search in Radio';

  @override
  String aboutWhatsNewTitle(String version) {
    return 'New in version $version';
  }

  @override
  String get aboutNew1 =>
      'Official JAKIM prayer times with notifications even when the app is closed';

  @override
  String get aboutNew2 =>
      'Music and radio in the app: Malaysia, Indonesia, Korea and K-pop';

  @override
  String get aboutNew3 => 'Easy mode: large display for older drivers';

  @override
  String get aboutNew4 => 'Lane guidance and a Waze-style navy night map';

  @override
  String get aboutNew5 => 'Clear roundabout icon with the exit number';

  @override
  String get alongRouteTitle => 'Along the route';

  @override
  String get alongRouteDisclaimer => 'OpenStreetMap data; may be incomplete.';

  @override
  String get alongRouteUnavailable =>
      'Couldn’t load places along the route. Try again later.';

  @override
  String get alongRouteEmpty =>
      'No places found along the route for this category.';

  @override
  String alongRouteIn(String distance) {
    return 'In $distance';
  }

  @override
  String get alongRouteRr => 'R&R';

  @override
  String get alongRouteFuel => 'Fuel';

  @override
  String get alongRouteMosque => 'Mosque';

  @override
  String get alongRouteToilets => 'Toilets';

  @override
  String get alongRouteAddStop => 'Add as stop';

  @override
  String get alongRouteAddedStop => 'Added as a stop — recalculating route';

  @override
  String get tripHistoryExport => 'Export JSON';

  @override
  String get tripHistoryExported => 'Trip history copied';

  @override
  String tripHistoryRetentionDays(int days) {
    return '$days days';
  }

  @override
  String get tripHistoryRetentionForever => 'Forever';

  @override
  String get tripHistoryRetentionOff => 'Off';

  @override
  String get pickingStopHint => 'Choose a stop, then pick your destination';

  @override
  String get cameraAwasAhead => 'AwAS camera ahead — observe the speed limit';

  @override
  String get cameraOsmAhead => 'Camera (OSM) ahead — observe the speed limit';

  @override
  String get settingsCameras => 'Camera alerts';

  @override
  String get settingsCamerasHint =>
      'Official AwAS (JPJ) alerts. Not every camera in Malaysia.';

  @override
  String get settingsCamerasOsm => 'Include OSM cameras';

  @override
  String get settingsCamerasOsmHint =>
      'Community data; may be incomplete or outdated.';

  @override
  String get settingsCamerasDistance => 'Alert distance';

  @override
  String get addStop => 'Add stop';

  @override
  String get stopsTitle => 'Stops';

  @override
  String get removeStop => 'Remove stop';

  @override
  String get nextStop => 'Next stop';

  @override
  String get skipStop => 'Skip stop';

  @override
  String get tripHistoryTitle => 'Trips';

  @override
  String get tripHistoryEmpty => 'No saved trips yet.';

  @override
  String get tripHistoryMonth => 'This month';

  @override
  String tripHistoryKm(String km) {
    return '$km km';
  }

  @override
  String tripHistoryDuration(int hours, int mins) {
    return '$hours h $mins min';
  }

  @override
  String tripHistoryToll(String amount) {
    return 'Toll ~RM $amount';
  }

  @override
  String tripHistoryTrips(int count) {
    return '$count trips';
  }

  @override
  String get tripHistoryRetention => 'Keep history';

  @override
  String get tripHistoryDeleteAll => 'Delete all trips';

  @override
  String get weatherTitle => 'Weather';

  @override
  String get weatherAttribution => 'Weather: Open-Meteo · GPS location';

  @override
  String get weatherUnavailable => 'Weather unavailable';

  @override
  String get weatherRainAlong => 'Rain expected along the route';

  @override
  String get weatherSevere => 'Severe weather expected — drive carefully';

  @override
  String get weatherHere => 'Here';

  @override
  String get weatherAtDestination => 'Destination';

  @override
  String get weatherFeelsLike => 'Feels';

  @override
  String get weatherCached => 'Cached';

  @override
  String get settingsWeather => 'Weather alerts';

  @override
  String get settingsWeatherHint => 'Heavy-rain banner while navigating';

  @override
  String get settingsAlongRouteAnnounce => 'Announce R&R / fuel';

  @override
  String get settingsAlongRouteAnnounceHint =>
      'Voice when a rest area or fuel stop is ahead (chip always shows)';

  @override
  String get airQualityTitle => 'Air quality (IPU)';

  @override
  String get airQualityOpen => 'Air quality';

  @override
  String get airQualityDisclaimer =>
      'Official Air Pollutant Index from the nearest DOE (JAS) monitoring station.';

  @override
  String get airQualityHere => 'Here';

  @override
  String get airQualitySearchHint => 'Search another place';

  @override
  String get airQualityUnavailable =>
      'IPU unavailable. Check connection, then try again.';

  @override
  String get airQualityCached => 'Cached';

  @override
  String get airQualityAttribution =>
      'Source: Jabatan Alam Sekitar (APIMS/EQMS)';

  @override
  String airQualityStation(String name, String distance) {
    return 'Station: $name · $distance';
  }

  @override
  String airQualityRouteAlert(String name, int ipu) {
    return 'Elevated IPU along the route — $name · $ipu';
  }

  @override
  String get airBandGood => 'Good';

  @override
  String get airBandModerate => 'Moderate';

  @override
  String get airBandUnhealthy => 'Unhealthy';

  @override
  String get airBandVeryUnhealthy => 'Very unhealthy';

  @override
  String get airBandHazardous => 'Hazardous';

  @override
  String get alongRouteEv => 'EV charging';

  @override
  String get qiblaTitle => 'Qibla';

  @override
  String get qiblaOpen => 'Qibla';

  @override
  String qiblaDegrees(String degrees) {
    return '$degrees° from north';
  }

  @override
  String get qiblaHint =>
      'Point the top of the phone toward the arrow for Makkah.';

  @override
  String get qiblaUnavailable => 'Need a GPS fix for qibla direction.';
}
