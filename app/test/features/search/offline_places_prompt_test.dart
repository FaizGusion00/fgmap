import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_map_controller.dart';
import 'package:fgmap/features/search/presentation/offline_places_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

OfflineManifest _manifest({
  String version = '20261101',
  OfflinePlacesInfo? places,
}) => OfflineManifest(
  region: 'malaysia',
  version: version,
  valhalla: expectedValhallaVersion,
  file: 'malaysia-$version.tar.gz',
  sizeBytes: 253855993,
  sha256: 'a' * 64,
  extractedSizeBytes: 682844160,
  extractedSha256: 'b' * 64,
  places: places ??
      OfflinePlacesInfo(
        file: 'places-$version.sqlite.gz',
        sizeBytes: 18_500_000,
        sha256: 'c' * 64,
        extractedSizeBytes: 47_800_000,
        extractedSha256: 'd' * 64,
      ),
);

InstalledMap _installed(
  String version, {
  String? placesVersion,
  String? placesPath,
}) => InstalledMap(
  version: version,
  sizeBytes: 682844160,
  tarPath: '/x/valhalla_tiles.tar',
  placesVersion: placesVersion,
  placesPath: placesPath,
);

class _FakeController extends OfflineMapController {
  _FakeController(this.initial);

  final OfflineMapState initial;

  @override
  OfflineMapState build() => initial;

  @override
  Future<void> refresh({bool checkRemote = true}) async {}
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpBanner(WidgetTester tester, OfflineMapState state) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: OfflinePlacesPromptBanner()),
      overrides: [
        offlineMapControllerProvider.overrideWith(() => _FakeController(state)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pump();
  }

  testWidgets('tiada petunjuk bila pek lengkap dan terkini', (tester) async {
    await pumpBanner(
      tester,
      OfflineMapState(
        configured: true,
        installed: _installed(
          '20261101',
          placesVersion: '20261101',
          placesPath: '/x/places.sqlite',
        ),
        latest: _manifest(),
      ),
    );
    expect(find.byKey(const ValueKey('offline-places-prompt')), findsNothing);
  });

  testWidgets('petunjuk muat turun bila tiada pek', (tester) async {
    await pumpBanner(
      tester,
      OfflineMapState(configured: true, latest: _manifest()),
    );
    expect(find.byKey(const ValueKey('offline-places-prompt')), findsOneWidget);
    expect(find.textContaining('indeks tempat offline'), findsOneWidget);
  });

  testWidgets('petunjuk kemas kini bila indeks ketinggalan', (tester) async {
    await pumpBanner(
      tester,
      OfflineMapState(
        configured: true,
        installed: _installed(
          '20261001',
          placesVersion: '20261001',
          placesPath: '/x/places.sqlite',
        ),
        latest: _manifest(version: '20261101'),
      ),
    );
    expect(find.byKey(const ValueKey('offline-places-prompt')), findsOneWidget);
    expect(find.textContaining('Kemas kini pek'), findsOneWidget);
  });

  testWidgets('petunjuk bila pek laluan ada tetapi indeks tiada', (tester) async {
    await pumpBanner(
      tester,
      OfflineMapState(
        configured: true,
        installed: _installed('20261101'),
        latest: _manifest(),
      ),
    );
    expect(find.byKey(const ValueKey('offline-places-prompt')), findsOneWidget);
  });
}
