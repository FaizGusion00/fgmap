// Regresi daripada ujian telefon pemilik (2026-11-01): FG AI menggema ayat pengguna, tidak faham
// "can you tell me where are my current location", dan salah menyalahkan "luar talian" / "semak sambungan"
// untuk "Im heading to masjid attaufiqiah can you tell me how?".
import 'dart:io';

import 'package:dio/dio.dart';
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
const _masjid = Place(
  name: 'Masjid At-Taufiqiah',
  subtitle: 'Kuala Terengganu',
  point: GeoPoint(5.3302, 103.1408),
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

  testWidgets(
    '"Can you tell me where are my current location?" -> lokasi GPS, bukan gema model',
    (tester) async {
      final llm = FakeLlm(
        reply:
            "Hello! I'm FG AI. Where are you heading today, or what can I help "
            'with? Can you tell me where are my current location?',
      );
      await pump(tester, llm);
      await send(tester, 'Can you tell me where are my current location?');
      expect(
        llm.lastUserText,
        isNull,
        reason: 'dijawab oleh penghala, bukan model',
      );
      expect(find.textContaining("You're here"), findsOneWidget);
      expect(find.textContaining('Jalan Pinang'), findsWidgets);
      expect(find.textContaining("Hello! I'm FG AI"), findsNothing);

      await send(tester, 'Please tell me my current location');
      expect(llm.lastUserText, isNull);
      expect(find.textContaining("You're here"), findsNWidgets(2));
    },
  );

  testWidgets(
    '"Im heading to masjid attaufiqiah can you tell me how?" -> laluan, destinasi bersih, bahasa English',
    (tester) async {
      final geocoder = _Geocoder({
        'masjid attaufiqiah': const [],
        'masjid at taufiqiah': [_masjid],
      });
      await pump(tester, FakeLlm(), geocoder: geocoder);
      await send(
        tester,
        'Im heading to masjid attaufiqiah can you tell me how?',
      );
      // Ekor soalan dibuang dan ejaan alternatif dicuba.
      expect(geocoder.queries, ['masjid attaufiqiah', 'masjid at taufiqiah']);
      expect(find.textContaining('Masjid At-Taufiqiah'), findsWidgets);
      expect(
        find.textContaining('is ready'),
        findsOneWidget,
        reason: 'balasan English untuk input English',
      );
      expect(find.textContaining('Itu perlukan internet'), findsNothing);
      expect(find.textContaining('Semak sambungan'), findsNothing);

      // Susulan tanpa destinasi: laluan sudah ada pada peta.
      await send(tester, 'how do i do that?');
      expect(find.textContaining('already on the map'), findsOneWidget);
    },
  );

  testWidgets(
    'susulan tanpa destinasi dan tanpa laluan: bertanya "ke mana?", bukan model',
    (tester) async {
      final llm = FakeLlm(reply: 'MODEL_SHOULD_NOT_ANSWER');
      await pump(tester, llm, geocoder: _Geocoder({}));
      await send(tester, 'how do i do that?');
      expect(llm.lastUserText, isNull);
      expect(find.textContaining('Where would you like to go'), findsOneWidget);
      expect(find.textContaining('MODEL_SHOULD_NOT_ANSWER'), findsNothing);
    },
  );

  testWidgets(
    'LUAR TALIAN sebenar: mesej jujur yang menyebut tempat dan pek peta',
    (tester) async {
      await pump(tester, FakeLlm(), geocoder: _Geocoder({}), online: false);
      await send(
        tester,
        'Im heading to masjid attaufiqiah can you tell me how?',
      );
      expect(find.textContaining('You\'re offline'), findsOneWidget);
      expect(find.textContaining('masjid attaufiqiah'), findsWidgets);
      expect(find.textContaining('offline map pack'), findsOneWidget);
    },
  );

  testWidgets('ONLINE tetapi pelayan 429: dikatakan sibuk, BUKAN luar talian', (
    tester,
  ) async {
    await pump(
      tester,
      FakeLlm(),
      geocoder: _Throwing(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 429,
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
    );
    await send(tester, 'navigate to klcc');
    expect(find.textContaining('busy right now'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('ONLINE tetapi sambungan lemah (tamat masa): dikatakan lambat', (
    tester,
  ) async {
    await pump(
      tester,
      FakeLlm(),
      geocoder: _Throwing(const SocketException('Failed host lookup')),
    );
    await send(tester, 'navigate to klcc');
    expect(find.textContaining('slow or unstable'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('model yang menggema salam + soalan diganti panduan ringkas', (
    tester,
  ) async {
    final llm = FakeLlm(
      reply:
          "Hello! I'm FG AI. Where are you heading today, or what can I help "
          'with? Explain how tolls work please',
    );
    await pump(tester, llm);
    await send(tester, 'Explain how tolls work please');
    expect(llm.lastUserText, isNotNull, reason: 'soalan umum memang ke model');
    expect(find.textContaining("I didn't quite get that"), findsOneWidget);
    expect(find.textContaining("Hello! I'm FG AI"), findsNothing);
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

class _Throwing implements Geocoder {
  _Throwing(this.error);
  final Object error;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async =>
      throw error;
}

class _Preview extends RoutePreviewController {
  @override
  RoutePreviewState build() => const RouteIdle();

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
