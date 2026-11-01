import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:fgmap/features/local_assistant/presentation/ai_reply_builder.dart';
import 'package:fgmap/features/search/data/offline_geocoder.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/l10n/generated/app_localizations.dart';
import 'package:fgmap/l10n/generated/app_localizations_en.dart';
import 'package:fgmap/l10n/generated/app_localizations_ms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'ms': AppLocalizationsMs(),
  };

  group('tarikh dan masa', () {
    test('tarikh penuh dalam BM dan Inggeris', () {
      final d = DateTime(2026, 11, 1, 21, 1); // Ahad
      expect(formatLongDate(d, malay: true), 'Ahad, 1 November 2026');
      expect(formatLongDate(d, malay: false), 'Sunday, 1 November 2026');
      expect(
        formatLongDate(DateTime(2026, 3, 2), malay: true),
        'Isnin, 2 Mac 2026',
      );
    });

    test('jam 12 jam dengan pagi/tengah hari/petang/malam', () {
      expect(
        formatClock12(DateTime(2026, 1, 1, 0, 5), malay: true),
        '12:05 pagi',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 9, 30), malay: true),
        '9:30 pagi',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 12, 0), malay: true),
        '12:00 tengah hari',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 16, 45), malay: true),
        '4:45 petang',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 21, 1), malay: true),
        '9:01 malam',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 21, 1), malay: false),
        '9:01 PM',
      );
      expect(
        formatClock12(DateTime(2026, 1, 1, 0, 5), malay: false),
        '12:05 AM',
      );
    });

    test('jawapan menggunakan jam yang diberi, bukan tarikh tetap', () {
      final b = AiReplyBuilder(
        locales['en']!,
        clock: () => DateTime(2026, 11, 1, 21, 1),
      );
      expect(
        b.chat(ChatKind.date).text,
        'Today is **Sunday, 1 November 2026**.',
      );
      expect(b.chat(ChatKind.time).text, "It's **9:01 PM** right now.");
      final ms = AiReplyBuilder(
        locales['ms']!,
        clock: () => DateTime(2026, 11, 1, 21, 1),
      );
      expect(
        ms.chat(ChatKind.date).text,
        'Hari ini **Ahad, 1 November 2026**.',
      );
      expect(ms.chat(ChatKind.time).text, 'Sekarang pukul **9:01 malam**.');
    });
  });

  group('cip cadangan', () {
    test(
      'setiap kategori: teks cip BM dan Inggeris kembali kepada kategori yang sama',
      () {
        for (final entry in locales.entries) {
          final l10n = entry.value;
          for (final c in NearbyCategory.values) {
            final text = l10n.aiAskNearest(nearbyCategoryLabel(l10n, c));
            final intent = parseIntent(text);
            expect(
              intent,
              isA<NearbyIntent>(),
              reason: '[${entry.key}] "$text" mesti dikenali',
            );
            expect(
              (intent! as NearbyIntent).category,
              c,
              reason: '[${entry.key}] "$text"',
            );
          }
        }
      },
    );

    test('cadangan lalai (cuaca, waktu solat) juga dikenali penghala', () {
      for (final l10n in locales.values) {
        expect(parseIntent(l10n.aiAskWeather), isA<WeatherIntent>());
        expect(parseIntent(l10n.aiAskPrayer), isA<PrayerTimesIntent>());
      }
    });

    test('jawapan tidak pasti memberi cip, bukan jalan buntu', () {
      final m = AiReplyBuilder(locales['ms']!).noAnswer();
      expect(m.text, contains('belum pasti'));
      expect(m.actions.map((a) => a.kind).toSet(), {AssistantActionKind.ask});
      expect(m.actions.map((a) => a.label), contains('Stesen minyak terdekat'));
    });

    test('mengantuk: nasihat keselamatan dan tempat berhenti', () {
      final m = AiReplyBuilder(locales['en']!).chat(ChatKind.drowsy);
      expect(m.text, contains('Drowsy driving is dangerous'));
      expect(m.actions.map((a) => a.label), contains('Nearest Fuel'));
    });
  });

  group('kad tempat', () {
    test('hasil dijadikan kad dengan kawasan dan jarak; teks hanya tajuk', () {
      final b = AiReplyBuilder(locales['en']!);
      final m = b.places(
        {
          'ok': true,
          'places': [
            {
              'name': 'Caltex',
              'subtitle': 'Sungai Buloh, Selangor',
              'lat': 3.14,
              'lng': 101.68,
              'distance_m': 470,
            },
            {'name': 'Caltex', 'subtitle': 'Caltex', 'lat': 3.2, 'lng': 101.7},
          ],
        },
        title: 'Nearest Fuel:',
        category: NearbyCategory.fuel,
      );
      expect(m.text, 'Nearest Fuel:');
      expect(m.actions, isEmpty);
      expect(m.places, hasLength(2));
      expect(m.places.first.area, 'Sungai Buloh');
      expect(m.places.first.distanceM, 470);
      expect(m.places.first.category, NearbyCategory.fuel);
      // Kawasan yang sama dengan nama tidak diulang.
      expect(m.places.last.area, isNull);
      expect(m.places.last.distanceM, isNull);
    });

    test('kad disimpan dan dibaca semula (sejarah sembang)', () {
      const original = AssistantMessage(
        role: AssistantRole.assistant,
        text: 'Kedai gunting terdekat:',
        places: [
          ChatPlace(
            name: 'Barber Ali',
            lat: 3.14,
            lng: 101.68,
            area: 'Seksyen 7',
            distanceM: 400,
            category: NearbyCategory.barber,
          ),
        ],
        actions: [AssistantAction(AssistantActionKind.ask, label: 'Cuaca')],
      );
      final back = AssistantMessage.fromJson(original.toJson())!;
      expect(back.places.single.name, 'Barber Ali');
      expect(back.places.single.category, NearbyCategory.barber);
      expect(back.places.single.distanceM, 400);
      expect(back.actions.single.kind, AssistantActionKind.ask);
      expect(back.actions.single.label, 'Cuaca');
    });

    test('kad rosak (tiada koordinat) dibuang semasa dibaca, bukan ranap', () {
      final back = AssistantMessage.fromJson({
        'role': 'assistant',
        'text': 'x',
        'places': [
          {'name': 'Tiada koordinat'},
          'bukan peta',
        ],
      })!;
      expect(back.places, isEmpty);
    });
  });

  group('data kategori', () {
    test(
      'setiap kategori ada penapis OSM, radius berperingkat dan frasa sandaran',
      () {
        for (final c in NearbyCategory.values) {
          expect(c.selectors, isNotEmpty, reason: c.name);
          expect(c.radiiM, isNotEmpty, reason: c.name);
          expect(
            c.radiiM,
            orderedEquals([...c.radiiM]..sort()),
            reason: c.name,
          );
          expect(c.nominatimPhrases, isNotEmpty, reason: c.name);
          expect(c.nominatimTypes, isNotEmpty, reason: c.name);
          expect(
            c.overpassQuery(3.1, 101.6, c.radiiM.first),
            contains('around:'),
          );
        }
      },
    );

    test('Overpass: gunting rambut mencari shop=hairdresser dan barber', () {
      final q = NearbyCategory.barber.overpassQuery(3.1, 101.6, 1500);
      expect(q, contains('hairdresser|barber'));
    });

    test(
      'indeks offline hanya menyimpan kategori yang dibina; lain berpindah sumber',
      () {
        expect(OfflineNearbySearch.catsFor(NearbyCategory.fuel), isNotEmpty);
        expect(
          OfflineNearbySearch.catsFor(NearbyCategory.evCharging),
          isNotEmpty,
        );
        expect(OfflineNearbySearch.catsFor(NearbyCategory.barber), isEmpty);
        expect(OfflineNearbySearch.catsFor(NearbyCategory.atm), isEmpty);
      },
    );
  });
}
