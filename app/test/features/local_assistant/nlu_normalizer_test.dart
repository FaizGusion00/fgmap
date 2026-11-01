import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:fgmap/features/local_assistant/domain/nlu/fuzzy.dart';
import 'package:fgmap/features/local_assistant/domain/nlu/normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slang', () {
    test('SMS/rojak -> bentuk piawai', () {
      expect(canonicalizeSlang('nk g klcc'), 'nak pergi klcc');
      expect(canonicalizeSlang('cmne nk gi klcc'), 'macam mana nak pergi klcc');
      expect(canonicalizeSlang('bawak sy ke ipoh'), 'bawa saya ke ipoh');
      expect(canonicalizeSlang('x nak tol'), 'tak nak tol');
      expect(canonicalizeSlang('xnak tol'), 'tak nak tol');
      expect(canonicalizeSlang('brape lama lg'), 'berapa lama lagi');
    });

    test('"x" dan "g" hanya slang pada kedudukan arahan, bukan dalam nama', () {
      expect(canonicalizeSlang('route to x'), 'route to x');
      expect(canonicalizeSlang('route to g hotel'), 'route to g hotel');
      expect(canonicalizeSlang('nak g klcc'), 'nak pergi klcc');
    });
  });

  group('salah taip', () {
    test('editDistance (transposisi = 1)', () {
      expect(editDistance('navigate', 'navigate'), 0);
      expect(editDistance('naviagte', 'navigate'), 1);
      expect(editDistance('petrl', 'petrol'), 1);
      expect(editDistance('abc', 'xyz'), 3);
    });

    test('hanya kata arahan dibetulkan; nama tempat tidak', () {
      expect(nearestCommandWord('naviagte'), 'navigate');
      expect(nearestCommandWord('wheather'), 'weather');
      expect(nearestCommandWord('masjd'), 'masjid');
      // Nama tempat sebenar jauh daripada perbendaharaan -> tidak disentuh.
      for (final place in [
        'pavilion',
        'kajang',
        'cheras',
        'sunway',
        'ampang',
      ]) {
        expect(nearestCommandWord(place), isNull, reason: place);
      }
      // Kata pendek tidak pernah dibetulkan.
      expect(nearestCommandWord('ipoh'), isNull);
    });

    test('fuzzyCorrect hanya mengembalikan ayat jika ada token berubah', () {
      expect(fuzzyCorrect('naviagte to klcc'), 'navigate to klcc');
      expect(fuzzyCorrect('navigate to klcc'), isNull);
    });
  });

  test('gandaan "dekat2" difahami; kod tempat "ss2" tidak disentuh', () {
    expect(canonicalizeSlang('minyak dekat2 sini'), 'minyak dekat sini');
    expect(
      canonicalizeSlang('jalan ss2 petaling jaya'),
      'jalan ss2 petaling jaya',
    );
    for (final t in [
      'minyak dekat2 sini',
      'masjid dekat2 sini',
      'stesen minyak dekat2',
    ]) {
      expect(parseIntent(t), isA<NearbyIntent>(), reason: t);
    }
  });
}
