import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../azan/domain/prayer.dart';
import '../../azan/presentation/azan_l10n.dart';
import '../../navigation/domain/instruction_text.dart';
import '../../navigation/domain/nav_route.dart';
import '../../route_preview/domain/route_preference.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../search/domain/nearby_category.dart';
import '../../weather/domain/weather_codes.dart';
import '../domain/assistant_message.dart';
import '../domain/intent_router.dart' show ChatKind, TripInfoKind;

/// Jawapan bertemplat untuk arahan peta: tepat (dari data alat), ringkas, tidak pernah mengulang
/// jawapan sebelumnya, dan dalam bahasa mesej pengguna.
class AiReplyBuilder {
  AiReplyBuilder(this.l10n);

  final AppLocalizations l10n;

  bool get _malay => l10n.localeName.startsWith('ms');

  String _rm(num v) => NumberFormat.currency(
    locale: l10n.localeName,
    symbol: 'RM',
    decimalDigits: 2,
  ).format(v);

  String _optionLine(Map<String, Object?> o) {
    final km = (o['distance_km'] as num?)?.toDouble() ?? 0;
    final min = (o['duration_min'] as num?)?.toInt() ?? 0;
    final parts = [
      formatDuration(l10n, min * 60),
      formatDistance(l10n, (km * 1000).round()),
      _toll(o),
    ];
    return parts.join(' · ');
  }

  String _toll(Map<String, Object?> o) {
    if (o['has_tolls'] != true) return l10n.aiTollNone;
    final rm = o['toll_rm'] as num?;
    if (rm == null || rm <= 0) return l10n.aiTollUnknown;
    return o['toll_partial'] == true
        ? l10n.aiTollAmountPlus(_rm(rm))
        : l10n.aiTollAmount(_rm(rm));
  }

  String _reason(String? name) => switch (RouteChoiceReason.values
      .where((r) => r.name == name)
      .firstOrNull) {
    RouteChoiceReason.fastest => l10n.aiReasonFastest,
    RouteChoiceReason.shortest => l10n.aiReasonShortest,
    RouteChoiceReason.tollFree => l10n.aiReasonTollFree,
    RouteChoiceReason.fewestTolls => l10n.aiReasonFewestTolls,
    RouteChoiceReason.noHighways => l10n.aiReasonNoHighways,
    RouteChoiceReason.cheapest => l10n.aiReasonCheapest,
    RouteChoiceReason.safest => l10n.aiReasonSafest,
    _ => l10n.aiReasonRecommended,
  };

  /// Kegagalan alat dalam ayat biasa. Setiap kod ada mesej tersendiri supaya pengguna tahu SEBAB sebenar
  /// (luar talian / pelayan sibuk / lambat / tempat tak jumpa / tiada laluan), bukan satu "semak sambungan".
  String failure(Map<String, Object?> r, {String? query}) {
    final place = (r['destination'] ?? r['query'] ?? query)?.toString();
    return switch (r['error']) {
      'not_found' when place != null => l10n.aiPlaceNotFound(place),
      'not_found' => l10n.aiNothingFound,
      'offline_not_found' when place != null => l10n.aiOfflineNotFound(place),
      'offline_not_found' => l10n.aiOfflineTool,
      'no_location' => l10n.aiNoLocation,
      'offline' || 'network' => l10n.aiOfflineTool,
      'busy' => l10n.aiBusy,
      'service_down' => l10n.aiServiceDown,
      'slow' || 'route_timeout' => l10n.aiSlow,
      'offline_pack_needed' => l10n.aiOfflinePackNeeded,
      'offline_engine' => l10n.aiOfflineEngine,
      'no_drivable_route' when place != null => l10n.aiNoDrivableRoute(place),
      'no_drivable_route' || 'route_failed' => l10n.aiRouteFailed,
      'search_failed' => l10n.aiSearchFailed,
      'no_route' => l10n.aiNeedRoute,
      'no_trip' => l10n.aiNoTrip,
      'no_nav' => l10n.aiTripNoNav,
      'no_speed_limit' => l10n.aiTripSpeedUnknown,
      'no_fuel_price' => l10n.aiTripFuelNoPrice,
      _ => l10n.aiUnavailable,
    };
  }

  AssistantMessage route(Map<String, Object?> r, {String? query}) {
    if (r['ok'] != true) return _reply(failure(r, query: query));
    final place = (r['destination'] as String?) ?? query ?? '';
    final b = StringBuffer()
      ..write(l10n.aiRouteReady('**$place**', _optionLine(r)))
      ..write(' ')
      ..write(_reason(r['reason'] as String?));
    final alts = (r['alternatives'] as List?)
        ?.whereType<Map<String, Object?>>();
    if (alts != null && alts.isNotEmpty) {
      b.write('\n\n${l10n.aiOtherOptions}');
      for (final a in alts) {
        b.write('\n- ${_optionLine(a)}');
      }
    }
    final started = r['navigation_started'] == true;
    if (started) b.write('\n\n${l10n.aiNavStarting}');
    return _reply(
      b.toString(),
      actions: started
          ? const []
          : const [
              AssistantAction(AssistantActionKind.startNavigation),
              AssistantAction(AssistantActionKind.showRoute),
            ],
    );
  }

  AssistantMessage currentLocation(Map<String, Object?> r) {
    if (r['ok'] != true) return _reply(failure(r));
    final lat = (r['lat'] as num?)?.toStringAsFixed(5) ?? '';
    final lng = (r['lng'] as num?)?.toStringAsFixed(5) ?? '';
    final place = r['place']?.toString().trim();
    final text = place == null || place.isEmpty
        ? l10n.aiCurrentLocationCoords(lat, lng)
        : l10n.aiCurrentLocation('**$place**', lat, lng);
    return _reply(text);
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Jawapan soalan perjalanan daripada data setempat (lihat `tripInfo`).
  AssistantMessage trip(TripInfoKind kind, Map<String, Object?> r) {
    if (r['ok'] != true) return _reply(failure(r));
    final meters = (r['meters'] as num?)?.round() ?? 0;
    final seconds = (r['seconds'] as num?)?.round() ?? 0;
    final remaining = r['remaining'] == true;
    return _reply(switch (kind) {
      TripInfoKind.distance =>
        remaining
            ? l10n.aiTripDistanceLeft(formatDistance(l10n, meters))
            : l10n.aiTripDistanceTotal(formatDistance(l10n, meters)),
      TripInfoKind.timeLeft =>
        remaining
            ? l10n.aiTripTimeLeft(formatDuration(l10n, seconds))
            : l10n.aiTripTimeTotal(formatDuration(l10n, seconds)),
      TripInfoKind.arrival => l10n.aiTripArrival(
        _clock(r['arrival']! as DateTime),
        formatDuration(l10n, seconds),
      ),
      TripInfoKind.toll => _tripToll(r),
      TripInfoKind.fuelCost => l10n.aiTripFuel(
        _rm(r['fuel_rm']! as num),
        formatDistance(l10n, meters),
        (r['price']! as num).toStringAsFixed(2),
        (r['liters_per_100km']! as num).toStringAsFixed(1),
      ),
      TripInfoKind.nextTurn => _tripNextTurn(r),
      TripInfoKind.speedLimit => l10n.aiTripSpeedLimit('${r['kmh']}'),
    });
  }

  String _tripToll(Map<String, Object?> r) {
    if (r['has_tolls'] != true) return l10n.aiTripTollNone;
    if (r['motorcycle'] == true) return l10n.aiTripTollMotorcycle;
    if (r['pending'] == true) return l10n.aiTripTollPending;
    if (r['unknown'] == true) return l10n.aiTripTollUnknown;
    final amount = _rm((r['toll_rm'] as num?) ?? 0);
    return r['toll_partial'] == true
        ? l10n.aiTripTollPartial(amount)
        : l10n.aiTripToll(amount);
  }

  String _tripNextTurn(Map<String, Object?> r) {
    final m = r['maneuver']! as NavManeuver;
    final text = InstructionText(
      VoiceLanguage.fromCode(_malay ? 'ms' : 'en'),
    ).action(m);
    final d = (r['distance_m'] as num?)?.round();
    return d == null || d <= 0
        ? l10n.aiTripNextTurnNow(text)
        : l10n.aiTripNextTurn(text, formatDistance(l10n, d));
  }

  AssistantMessage chat(ChatKind kind) => _reply(switch (kind) {
    ChatKind.identity => l10n.aiIdentity,
    ChatKind.greeting => l10n.aiGreeting,
    ChatKind.thanks => l10n.aiThanks,
    ChatKind.ping => l10n.aiPing,
    ChatKind.ack => l10n.aiAck,
  });

  AssistantMessage capabilities({bool offlineFocused = false}) =>
      _reply(offlineFocused ? l10n.aiCapabilitiesOffline : l10n.aiCapabilities);

  AssistantMessage places(
    Map<String, Object?> r, {
    required String title,
    String? query,
  }) {
    if (r['ok'] != true) return _reply(failure(r, query: query));
    final list = (r['places'] as List).whereType<Map<String, Object?>>();
    final b = StringBuffer(title);
    final actions = <AssistantAction>[];
    for (final p in list.take(5)) {
      final name = p['name']?.toString() ?? '';
      final meters =
          (p['distance_m'] as num?)?.round() ??
          (((p['distance_km'] as num?) ?? -1) * 1000).round();
      final area = (p['subtitle']?.toString() ?? '').split(',').first.trim();
      b.write('\n- **$name**');
      if (area.isNotEmpty && area != name) b.write(', $area');
      if (meters >= 0) b.write(' · ${formatDistance(l10n, meters)}');
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && actions.length < 3) {
        actions.add(
          AssistantAction(
            AssistantActionKind.routeTo,
            label: name,
            lat: lat,
            lng: lng,
          ),
        );
      }
    }
    return _reply(b.toString(), actions: actions);
  }

  String categoryName(NearbyCategory c) => switch (c) {
    NearbyCategory.fuel => l10n.searchCatFuel,
    NearbyCategory.food => l10n.searchCatFood,
    NearbyCategory.mosque => l10n.searchCatMosque,
    NearbyCategory.toilets => l10n.searchCatToilet,
    NearbyCategory.parking => l10n.searchCatParking,
    NearbyCategory.hospital => l10n.searchCatHospital,
  };

  String alongName(String category) => switch (category) {
    'fuel' => l10n.alongRouteFuel,
    'ev' => l10n.alongRouteEv,
    'mosque' => l10n.alongRouteMosque,
    'toilets' => l10n.alongRouteToilets,
    _ => l10n.alongRouteRr,
  };

  AssistantMessage along(Map<String, Object?> r, String category) {
    if (r['ok'] != true) return _reply(failure(r));
    final list = (r['places'] as List).whereType<Map<String, Object?>>();
    if (list.isEmpty) return _reply(l10n.aiNothingFound);
    final b = StringBuffer(l10n.aiAlongTitle(alongName(category)));
    for (final p in list.take(6)) {
      final km = double.tryParse(p['along_km']?.toString() ?? '');
      b.write('\n- **${p['name']}**');
      if (km != null) {
        b.write(
          ' · ${l10n.aiAlongIn(formatDistance(l10n, (km * 1000).round()))}',
        );
      }
    }
    return _reply(b.toString());
  }

  AssistantMessage weather(Map<String, Object?> r, {String? query}) {
    if (r['ok'] != true) return _reply(failure(r, query: query));
    final code = (r['code'] as num?)?.toInt() ?? 0;
    final place = r['place'] == 'here' ? l10n.aiHere : r['place'].toString();
    final temp = r['temp_c'];
    final b = StringBuffer(
      l10n.aiWeatherNow(
        '**$place**',
        WeatherCodes.label(code, malay: _malay),
        '$temp',
        '${r['feels_like_c'] ?? temp}',
      ),
    );
    final rain = r['precip_prob'];
    final humidity = r['humidity_pct'];
    final wind = r['wind_kmh'];
    if (rain != null && humidity != null && wind != null) {
      b.write(' ${l10n.aiWeatherDetails('$rain', '$humidity', '$wind')}');
    }
    return _reply(b.toString());
  }

  AssistantMessage air(Map<String, Object?> r, {String? query}) {
    if (r['ok'] != true) return _reply(failure(r, query: query));
    final band = switch (r['band']) {
      'good' => l10n.airBandGood,
      'moderate' => l10n.airBandModerate,
      'unhealthy' => l10n.airBandUnhealthy,
      'veryUnhealthy' => l10n.airBandVeryUnhealthy,
      _ => l10n.airBandHazardous,
    };
    return _reply(l10n.aiAirLine('${r['station']}', '${r['ipu']}', band));
  }

  AssistantMessage qibla(Map<String, Object?> r) {
    if (r['ok'] != true) return _reply(failure(r));
    return _reply(
      l10n.aiQiblaLine('${r['bearing_deg']}', '${r['distance_km']}'),
    );
  }

  AssistantMessage prayer(Map<String, Object?> r) {
    if (r['ok'] != true) return _reply(failure(r));
    final zone = r['zone']?.toString();
    final b = StringBuffer(
      zone == null || zone.isEmpty
          ? l10n.aiPrayerTitleLocal
          : l10n.aiPrayerTitle(zone),
    );
    final times = (r['times'] as Map?)?.cast<String, Object?>() ?? const {};
    for (final p in Prayer.fardu) {
      final t = times[p.name];
      if (t != null) b.write('\n- ${prayerName(l10n, p)}: **$t**');
    }
    final next = Prayer.values.where((p) => p.name == r['next']).firstOrNull;
    final at = DateTime.tryParse(r['next_at']?.toString() ?? '');
    if (next != null && at != null) {
      final hhmm =
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
      b.write('\n\n${l10n.aiPrayerNext(prayerName(l10n, next), hhmm)}');
    }
    return _reply(b.toString());
  }

  AssistantMessage playing(Map<String, Object?> r, {String? query}) {
    if (r['ok'] != true) return _reply(failure(r, query: query));
    final artist = r['artist']?.toString();
    final title = artist == null || artist.isEmpty
        ? '**${r['title']}**'
        : '**${r['title']}** · $artist';
    return _reply(l10n.aiPlaying(title));
  }

  AssistantMessage text(
    String text, {
    List<AssistantAction> actions = const [],
  }) => _reply(text, actions: actions);

  AssistantMessage _reply(
    String text, {
    List<AssistantAction> actions = const [],
  }) => AssistantMessage(
    role: AssistantRole.assistant,
    text: text,
    at: DateTime.now(),
    actions: actions,
  );
}
