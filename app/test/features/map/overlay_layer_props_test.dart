import 'package:fgmap/features/map/domain/poi_category.dart';
import 'package:fgmap/features/map/presentation/overlay_layer_props.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pin tempat', () {
    final json = poiPinLayerProps(dark: true, iconScale: 1).toJson();

    test(
      'imej dipilih mengikut kelas: setiap kelas memetakan ke imej kategorinya',
      () {
        final expr = json['icon-image'] as List;
        expect(expr.first, 'match');
        expect(expr[1], ['get', 'class']);
        // Selepas ['match', input]: pasangan (kelas[], imej) kemudian nilai lalai.
        final pairs = expr.sublist(2, expr.length - 1);
        expect(pairs.length.isEven, isTrue);
        for (var i = 0; i < pairs.length; i += 2) {
          final classes = (pairs[i] as List).cast<String>();
          final image = pairs[i + 1] as String;
          for (final c in classes) {
            expect(poiImageName(poiCategoryOf(c)!), image, reason: c);
          }
        }
        final all = [
          for (var i = 0; i < pairs.length; i += 2) ...(pairs[i] as List),
        ];
        expect(all.toSet(), {
          for (final v in poiClassesByCategory.values) ...v,
        });
      },
    );

    test('penapis: bernama sahaja dan hanya kelas yang dilukis', () {
      final filter = poiPinFilter();
      expect(filter.first, 'all');
      expect(filter[1], ['has', 'name']);
      final match = filter[2] as List;
      expect(match[0], 'match');
      expect((match[2] as List).toSet(), {
        for (final v in poiClassesByCategory.values) ...v,
      });
    });

    test(
      'tersembunyi pada mulanya (hanya semasa navigasi), fon tersedia, tema',
      () {
        expect(json['visibility'], 'none');
        expect(json['text-font'], ['Noto Sans Bold']);
        expect(json['icon-anchor'], 'bottom');
        expect(json['text-color'], '#FFFFFF');
        final light = poiPinLayerProps(dark: false, iconScale: 1).toJson();
        expect(light['text-color'], '#1B2330');
        expect(light['text-halo-color'], '#FFFFFF');
      },
    );

    test('saiz ikon ikut nisbah piksel Android', () {
      final a = poiPinLayerProps(dark: true, iconScale: 1).toJson();
      final b = poiPinLayerProps(dark: true, iconScale: 3).toJson();
      expect(
        (b['icon-size'] as num) / (a['icon-size'] as num),
        closeTo(3, 1e-9),
      );
    });
  });

  group('anak panah arah', () {
    test(
      'rata pada peta, diputar mengikut arah jalan, tidak dilanggar tindih',
      () {
        final j = chevronLayerProps(
          image: 'x',
          iconScale: 1,
          stale: false,
        ).toJson();
        expect(j['icon-rotation-alignment'], 'map');
        expect(j['icon-pitch-alignment'], 'map');
        expect(j['icon-rotate'], ['get', 'bearing']);
        expect(j['icon-allow-overlap'], isTrue);
        expect(j['icon-opacity'], greaterThan(0.9));
      },
    );

    test('laluan lapuk (menyimpang): anak panah disembunyikan', () {
      final j = chevronLayerProps(
        image: 'x',
        iconScale: 1,
        stale: true,
      ).toJson();
      expect(j['icon-opacity'], 0);
    });
  });

  group('label belokan', () {
    test(
      'teks daripada sifat, halo warna laluan, tidak tersorok oleh label lain',
      () {
        final j = turnLabelLayerProps(routeHex: '#1B9E5A').toJson();
        expect(j['text-field'], ['get', 'text']);
        expect(j['text-halo-color'], '#1B9E5A');
        expect(j['text-color'], '#FFFFFF');
        expect(j['text-anchor'], 'bottom');
        expect(j['text-allow-overlap'], isTrue);
        expect(j['text-ignore-placement'], isTrue);
      },
    );
  });
}
