import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/saved_places/domain/saved_place.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/widgets/eta_widget_payload.dart';
import 'package:fgmap/features/widgets/eta_widget_updater.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements EtaWidgetSink {
  final published = <EtaWidgetPayload>[];
  @override
  Future<void> publish(EtaWidgetPayload payload) async =>
      published.add(payload);
}

class _Planner implements RoutePlanner {
  _Planner(this.durationS, {this.fail = false});
  final int durationS;
  final bool fail;
  int calls = 0;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async {
    calls++;
    if (fail) throw StateError('tiada rangkaian');
    return [
      RouteOption(
        distanceM: 5000,
        durationS: durationS,
        hasTolls: false,
        points: [query.origin, query.destination],
        maneuvers: const [],
        source: RouteSource.online,
      ),
    ];
  }
}

SavedPlace _place(String id, SavedKind kind, double lat, double lng) =>
    SavedPlace(
      id: id,
      kind: kind,
      place: Place(name: id, subtitle: '', point: GeoPoint(lat, lng)),
    );

void main() {
  const here = GeoPoint(3.139, 101.687);
  var now = DateTime(2026, 10, 31, 9);

  EtaWidgetUpdater make({
    required List<SavedPlace> places,
    required _Sink sink,
    required _Planner planner,
    GeoPoint? origin = here,
    bool navigating = false,
  }) => EtaWidgetUpdater(
    savedPlaces: () => places,
    lastKnownPoint: () async => origin,
    planner: () => planner,
    sink: sink,
    vehicle: () => RouteVehicle.car,
    navigating: () => navigating,
    languageCode: () => 'ms',
    clock: () => now,
  );

  setUp(() => now = DateTime(2026, 10, 31, 9));

  test('tiada Rumah/Kerja -> CTA kosong, tiada permintaan laluan', () async {
    final sink = _Sink();
    final planner = _Planner(600);
    await make(places: const [], sink: sink, planner: planner).refresh();
    expect(planner.calls, 0);
    expect(sink.published.single.isEmpty, isTrue);
    expect(sink.published.single.home.value, 'Tetapkan dalam FGMaps');
  });

  test('guna ETA laluan jika ada', () async {
    final sink = _Sink();
    final planner = _Planner(12 * 60);
    await make(
      places: [_place('home', SavedKind.home, 3.2, 101.7)],
      sink: sink,
      planner: planner,
    ).refresh();
    final p = sink.published.single;
    expect(p.home.value, '12 min');
    expect(p.home.isSet, isTrue);
    expect(p.work.isSet, isFalse);
  });

  test('laluan gagal -> anggaran jarak berawalan ~', () async {
    final sink = _Sink();
    await make(
      places: [_place('work', SavedKind.work, 3.2, 101.7)],
      sink: sink,
      planner: _Planner(0, fail: true),
    ).refresh();
    expect(sink.published.single.work.value, startsWith('~'));
  });

  test('tiada lokasi -> tanda sempang, tidak ranap', () async {
    final sink = _Sink();
    await make(
      places: [_place('home', SavedKind.home, 3.2, 101.7)],
      sink: sink,
      planner: _Planner(600),
      origin: null,
    ).refresh();
    expect(sink.published.single.home.value, '—');
  });

  test('had masa: panggilan kedua dalam 15 minit diabaikan', () async {
    final sink = _Sink();
    final planner = _Planner(600);
    final updater = make(
      places: [_place('home', SavedKind.home, 3.2, 101.7)],
      sink: sink,
      planner: planner,
    );
    await updater.refresh();
    await updater.refresh();
    expect(planner.calls, 1);
    now = now.add(const Duration(minutes: 16));
    await updater.refresh();
    expect(planner.calls, 2);
    // Kandungan sama -> widget tidak dilukis semula.
    expect(sink.published, hasLength(1));
  });

  test('semasa navigasi tiada kerja', () async {
    final sink = _Sink();
    await make(
      places: [_place('home', SavedKind.home, 3.2, 101.7)],
      sink: sink,
      planner: _Planner(600),
      navigating: true,
    ).refresh();
    expect(sink.published, isEmpty);
  });
}
