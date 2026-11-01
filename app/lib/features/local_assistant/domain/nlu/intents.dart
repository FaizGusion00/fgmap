import 'package:flutter/foundation.dart';

import '../../../route_preview/domain/route_preference.dart';
import '../../../search/domain/nearby_category.dart';

/// Arahan peta yang difahami terus oleh kod (tanpa model): pantas, tepat dan tidak berulang.
/// Teks lain (soalan umum) pergi ke model pada telefon.
@immutable
sealed class AssistantIntent {
  const AssistantIntent();
}

/// "Route to KLCC", "bawa saya ke Kuala Terengganu tanpa tol", "navigate to Ipoh".
class RouteIntent extends AssistantIntent {
  const RouteIntent(
    this.destination, {
    this.preference = RoutePreference.recommended,
    this.autoStart = false,
    this.soft = false,
  });

  final String destination;

  /// Dipadankan daripada soalan ("how do i go to sleep", "how far is the moon"): jika tempat itu tidak wujud,
  /// pengawal menyerahkannya kepada model dan bukan melapor "tempat tidak dijumpai".
  final bool soft;
  final RoutePreference preference;

  /// Pengguna mahu terus bergerak ("navigate to", "bawa saya ke", "... start now").
  final bool autoStart;
}

/// "Start now", "mula", "jom" — mula navigasi pada laluan yang sedang dipratonton.
class StartNavigationIntent extends AssistantIntent {
  const StartNavigationIntent();
}

/// "Tanpa tol", "paling selamat" tanpa destinasi baharu: tukar pilihan pada laluan semasa.
class RoutePreferenceIntent extends AssistantIntent {
  const RoutePreferenceIntent(this.preference, {this.autoStart = false});

  final RoutePreference preference;
  final bool autoStart;
}

class CancelRouteIntent extends AssistantIntent {
  const CancelRouteIntent();
}

/// "How do I get there?", "how do i do that", "tell me how", "bawa saya ke sana": susulan tanpa destinasi baharu.
/// Pengawal memakai destinasi terakhir dalam sembang (atau bertanya "ke mana?" jika tiada).
class RouteFollowUpIntent extends AssistantIntent {
  const RouteFollowUpIntent({this.autoStart = false});

  /// "take me there", "navigate there": terus mula, bukan sekadar pratonton.
  final bool autoStart;
}

/// "Stesen minyak terdekat", "nearest mosque".
class NearbyIntent extends AssistantIntent {
  const NearbyIntent(
    this.category, {
    this.navigate = false,
    this.autoStart = false,
  });

  final NearbyCategory category;

  /// "Bawa saya ke stesen minyak terdekat": bukan sekadar senarai, rancang laluan ke yang terdekat.
  final bool navigate;
  final bool autoStart;
}

/// "Cari Pavilion", "where is Masjid Putra".
class SearchIntent extends AssistantIntent {
  const SearchIntent(this.query, {this.speculative = false});

  final String query;

  /// Teks pendek tanpa kata kerja ("klcc", "masjid negara") yang DIANGGAP nama tempat. Jika carian tiada hasil,
  /// pengawal boleh menyerahkannya kepada model (mungkin soalan umum).
  final bool speculative;
}

/// "Search my current location", "where am I", "lokasi saya" — GPS peranti, bukan carian nama tempat.
class CurrentLocationIntent extends AssistantIntent {
  const CurrentLocationIntent();
}

/// Perbualan ringkas yang dijawab dengan templat, bukan model: model kecil 0.6B tidak tahu siapa
/// dirinya dan cenderung memanggil alat (cth. merancang semula laluan terakhir) untuk "hai".
enum ChatKind {
  /// "Who are you?", "siapa awak", "who made you".
  identity,

  /// "Hi", "hai", "assalamualaikum" (seluruh mesej).
  greeting,

  /// "Thanks", "terima kasih".
  thanks,

  /// "Can you answer me?", "ada tak?", "kenapa tak jawab".
  ping,

  /// "ok", "baik", "tak jadi" tanpa apa-apa untuk dilakukan: pengesahan ringkas, bukan jawapan model.
  ack,
}

class ChatIntent extends AssistantIntent {
  const ChatIntent(this.kind);

  final ChatKind kind;
}

/// "What can I ask offline?", "apa boleh tanya" — FAQ ciri, tanpa skema alat.
class CapabilitiesIntent extends AssistantIntent {
  const CapabilitiesIntent({this.offlineFocused = false});

  /// Pengguna menyebut offline / model pada telefon secara khusus.
  final bool offlineFocused;
}

class WeatherIntent extends AssistantIntent {
  const WeatherIntent([this.place]);

  final String? place;
}

class AirQualityIntent extends AssistantIntent {
  const AirQualityIntent([this.place]);

  final String? place;
}

class QiblaIntent extends AssistantIntent {
  const QiblaIntent();
}

class PrayerTimesIntent extends AssistantIntent {
  const PrayerTimesIntent();
}

/// "R&R sepanjang laluan", "EV charging on the way". [category] ialah nama alat
/// `list_along_route` (rest_area, fuel, ev, mosque, toilets).
class AlongRouteIntent extends AssistantIntent {
  const AlongRouteIntent(this.category);

  final String category;
}

class PlayMusicIntent extends AssistantIntent {
  const PlayMusicIntent(this.query);

  final String query;
}

class PlayRadioIntent extends AssistantIntent {
  const PlayRadioIntent(this.query);

  final String query;
}

/// Tempat tersimpan yang boleh disebut dengan kata: "go home", "balik rumah", "pergi kerja".
enum SavedSlot { home, work }

class GoSavedPlaceIntent extends AssistantIntent {
  const GoSavedPlaceIntent(this.slot, {this.autoStart = false});

  final SavedSlot slot;
  final bool autoStart;
}

enum TripInfoKind {
  distance,
  timeLeft,
  arrival,
  toll,
  fuelCost,
  nextTurn,
  speedLimit,
}

/// "How far is it", "berapa lama lagi", "what time will I arrive", "how much toll": dijawab daripada data laluan/navigasi.
class TripInfoIntent extends AssistantIntent {
  const TripInfoIntent(this.kind);

  final TripInfoKind kind;
}

enum AssistVehicle { car, motorcycle }

class ChangeVehicleIntent extends AssistantIntent {
  const ChangeVehicleIntent(this.vehicle);

  final AssistVehicle vehicle;
}

/// "Mute", "senyap", "turn on voice".
class VoiceIntent extends AssistantIntent {
  const VoiceIntent({required this.enabled});

  final bool enabled;
}

enum AssistTheme { dark, light, system }

class ThemeIntent extends AssistantIntent {
  const ThemeIntent(this.theme);

  final AssistTheme theme;
}

/// "Stop navigation", "berhenti", "tamatkan navigasi" semasa navigasi aktif.
class StopNavigationIntent extends AssistantIntent {
  const StopNavigationIntent();
}

/// "Yang pertama", "the second one", "yang terdekat", "satu lagi": pilih daripada senarai hasil terakhir.
/// [index] berasaskan 0; [other] = "yang lain / satu lagi" (hasil seterusnya selepas yang terakhir dipilih).
class PickResultIntent extends AssistantIntent {
  const PickResultIntent(
    this.index, {
    this.other = false,
    this.autoStart = false,
  });

  final int index;
  final bool other;
  final bool autoStart;
}

enum AskSlot { destination, radioStation, musicQuery }

/// Arahan tanpa butiran ("navigate", "nak pergi", "play radio"): tanya butiran dengan templat, bukan model.
class AskSlotIntent extends AssistantIntent {
  const AskSlotIntent(this.slot);

  final AskSlot slot;
}

/// Apa yang diketahui tentang sembang semasa; menentukan maksud "ok", "yang pertama", "tak jadi".
@immutable
class ConversationContext {
  const ConversationContext({
    this.hasRoute = false,
    this.navActive = false,
    this.offeredStart = false,
    this.resultCount = 0,
    this.pendingDestination = false,
  });

  /// Pratonton laluan sedang dipaparkan.
  final bool hasRoute;

  /// Navigasi sedang berjalan.
  final bool navActive;

  /// Mesej AI terakhir menawarkan "mula navigasi" (hanya ketika itu "ok/ya" bermakna mula).
  final bool offeredStart;

  /// Bilangan tempat dalam senarai hasil terakhir (carian/dekat) yang boleh dirujuk dengan "yang pertama".
  final int resultCount;

  /// AI baru bertanya "nak ke mana?": jawapan pendek seterusnya ialah destinasi.
  final bool pendingDestination;
}
