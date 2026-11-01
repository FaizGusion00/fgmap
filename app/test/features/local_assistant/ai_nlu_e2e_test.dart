// Faham-arahan hujung ke hujung (ADR 0017): slang/rojak, konteks ("yang kedua", "ok"), soalan perjalanan,
// kawalan app. Model palsu TIDAK boleh dipanggil untuk semua ini.

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/network/connectivity_probe.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/local_assistant/data/chat_history_store.dart'
    show AiMode;
import 'package:fgmap/features/local_assistant/presentation/ai_chat_page.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_llm.dart';

const _here = GeoPoint(3.1390, 101.6869);
const _klcc = Place(
  name: 'Kuala Lumpur City Centre',
  subtitle: 'Kuala Lumpur',
  point: GeoPoint(3.1579, 101.7116),
);
const _pav1 = Place(
  name: 'Pavilion Kuala Lumpur',
  subtitle: 'Bukit Bintang',
  point: GeoPoint(3.1488, 101.7134),
);
const _pav2 = Place(
  name: 'Pavilion Bukit Jalil',
  subtitle: 'Bukit Jalil',
  point: GeoPoint(3.0562, 101.6955),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester,
    FakeLlm llm, {
    Geocoder? geocoder,
    bool online = true,
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester, size: const Size(390, 860));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const AiChatPage(mode: AiMode.fg),
      locale: locale,
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(llm),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            accessValue: LocationAccess.granted,
            fix: const LocationFix(point: _here),
          ),
        ),
        reverseGeocoderProvider.overrideWithValue(
          _Reverse(
            const Place(
              name: 'Jalan Pinang',
              subtitle: 'Kuala Lumpur',
              point: _here,
            ),
          ),
        ),
        onlineProbeProvider.overrideWithValue(() async => online),
        if (geocoder != null) geocoderProvider.overrideWithValue(geocoder),
        routePreviewControllerProvider.overrideWith(_Preview.new),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('ai-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai-send')));
    await tester.pumpAndSettle();
  }

  testWidgets('slang SMS "nk g klcc" (UI BM) -> laluan, tanpa model', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
    final geo = _Geocoder({
      'klcc': [_klcc],
    });
    await pump(tester, llm, geocoder: geo);
    await send(tester, 'nk g klcc');
    expect(llm.lastUserText, isNull);
    expect(geo.queries, ['klcc']);
    expect(find.textContaining('Kuala Lumpur City Centre'), findsWidgets);
  });

  testWidgets(
    'soalan perjalanan selepas laluan: jarak, tol (masih dikira), kos minyak jujur',
    (tester) async {
      final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
      await pump(
        tester,
        llm,
        geocoder: _Geocoder({
          'klcc': [_klcc],
        }),
        locale: const Locale('en'),
      );
      await send(tester, 'route to klcc');
      await send(tester, 'how far is it');
      expect(
        find.textContaining('Distance to your destination'),
        findsOneWidget,
      );
      await send(tester, 'how much is the toll');
      expect(find.textContaining('still being calculated'), findsOneWidget);
      await send(tester, 'how much petrol will i need');
      expect(find.textContaining('fuel price is not known'), findsOneWidget);
      await send(tester, 'what time will i arrive');
      expect(find.textContaining('You should arrive at'), findsOneWidget);
      expect(llm.lastUserText, isNull);
    },
  );

  testWidgets(
    'tiada laluan: soalan perjalanan dijawab "belum ada laluan", bukan model',
    (tester) async {
      final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
      await pump(
        tester,
        llm,
        geocoder: _Geocoder({}),
        locale: const Locale('en'),
      );
      await send(tester, 'how long left');
      expect(find.textContaining('no route or navigation yet'), findsOneWidget);
      expect(llm.lastUserText, isNull);
    },
  );

  testWidgets(
    'carian -> "yang kedua" memakai tempat ke-2 tanpa carian semula',
    (tester) async {
      final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
      final geo = _Geocoder({
        'pavilion': [_pav1, _pav2],
      });
      await pump(tester, llm, geocoder: geo, locale: const Locale('en'));
      await send(tester, 'cari pavilion');
      expect(find.textContaining('Pavilion Bukit Jalil'), findsWidgets);
      await send(tester, 'the second one');
      expect(geo.queries, ['pavilion'], reason: 'tidak mencari semula');
      expect(find.textContaining('is ready'), findsOneWidget);
      expect(llm.lastUserText, isNull);
    },
  );

  testWidgets(
    'nama tempat sahaja -> carian; tiada hasil -> serah kepada model',
    (tester) async {
      final llm = FakeLlm(reply: 'Jawapan model.');
      final geo = _Geocoder({
        'klcc': [_klcc],
      });
      await pump(tester, llm, geocoder: geo, locale: const Locale('en'));
      await send(tester, 'klcc');
      expect(llm.lastUserText, isNull);
      expect(find.textContaining('as a place'), findsOneWidget);
      await send(tester, 'xyzzy');
      expect(
        llm.lastUserText,
        isNotNull,
        reason: 'bukan tempat dikenali -> model',
      );
    },
  );

  testWidgets('"go home" tanpa Rumah disimpan: terangkan cara menetapkan', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
    await pump(
      tester,
      llm,
      geocoder: _Geocoder({}),
      locale: const Locale('en'),
    );
    await send(tester, 'go home');
    expect(find.textContaining('not set Home'), findsOneWidget);
    expect(llm.lastUserText, isNull);
  });

  testWidgets('kawalan app: kenderaan, suara, tema', (tester) async {
    final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
    await pump(
      tester,
      llm,
      geocoder: _Geocoder({}),
      locale: const Locale('en'),
    );
    await send(tester, 'switch to motorcycle');
    expect(find.textContaining('changed to'), findsOneWidget);
    await send(tester, 'mute');
    expect(find.textContaining('Voice guidance is off'), findsOneWidget);
    await send(tester, 'dark mode');
    expect(find.textContaining('dark mode is on'), findsOneWidget);
    expect(llm.lastUserText, isNull);
  });

  testWidgets(
    '"navigate" sahaja -> tanya destinasi; jawapan pendek ialah destinasi',
    (tester) async {
      final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
      final geo = _Geocoder({
        'klcc': [_klcc],
      });
      await pump(tester, llm, geocoder: geo, locale: const Locale('en'));
      await send(tester, 'navigate');
      expect(find.textContaining('Where would you like to go'), findsOneWidget);
      await send(tester, 'klcc');
      expect(geo.queries, ['klcc']);
      expect(find.textContaining('is ready'), findsOneWidget);
      expect(llm.lastUserText, isNull);
    },
  );

  testWidgets('"ok" tanpa tawaran mula -> pengesahan ringkas, bukan model', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
    await pump(
      tester,
      llm,
      geocoder: _Geocoder({}),
      locale: const Locale('en'),
    );
    await send(tester, 'ok');
    expect(
      find.textContaining('Tell me when you need map help'),
      findsOneWidget,
    );
    expect(llm.lastUserText, isNull);
  });
}

class _Reverse implements ReverseGeocoder {
  _Reverse(this.place);
  final Place place;

  @override
  Future<Place?> reverse(GeoPoint point, {cancel}) async => place;
}

class _Geocoder implements Geocoder {
  _Geocoder(this.byQuery);
  final Map<String, List<Place>> byQuery;
  final List<String> queries = [];

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async {
    queries.add(query);
    return byQuery[query.toLowerCase()] ?? const [];
  }
}

class _Preview extends RoutePreviewController {
  @override
  RoutePreviewState build() => const RouteIdle();

  @override
  Future<void> setVehicle(RouteVehicle vehicle) async {}

  @override
  Future<void> planTo(
    GeoPoint destination, {
    String? destinationLabel,
    double? radiusM,
    List<GeoPoint> via = const [],
  }) async {
    state = RouteReady(
      query: RouteQuery(
        origin: _here,
        destination: destination,
        destinationLabel: destinationLabel,
      ),
      options: [
        RouteOption(
          distanceM: 480000,
          durationS: 21600,
          hasTolls: true,
          points: [_here, destination],
          label: RouteLabel.fastest,
        ),
      ],
    );
  }
}
