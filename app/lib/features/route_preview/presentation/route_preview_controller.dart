import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../data/route_planner.dart';
import '../data/toll_finder.dart';
import '../domain/route_option.dart';
import '../domain/toll.dart';
import '../domain/route_options_merge.dart' show isSameRoute;
import '../domain/routing_failure.dart';
import '../../../core/utils/log.dart';

@immutable
sealed class RoutePreviewState {
  const RoutePreviewState();
}

class RouteIdle extends RoutePreviewState {
  const RouteIdle();
}

class RouteLoading extends RoutePreviewState {
  /// [query] masih null selagi asal (lokasi pengguna) sedang dicari.
  const RouteLoading({
    required this.destination,
    this.query,
    this.destinationLabel,
  });

  final GeoPoint destination;
  final RouteQuery? query;
  final String? destinationLabel;
}

class RouteReady extends RoutePreviewState {
  const RouteReady({
    required this.query,
    required this.options,
    this.selectedIndex = 0,
    this.loadingMore = false,
    this.expanded = false,
    this.tolls = const {},
    this.tollFilter = RouteTollFilter.any,
    this.tollFilterUnmet = false,
    this.hasTollChoice = false,
    this.tollFilterUnverified = false,
  });

  final RouteQuery query;
  final List<RouteOption> options;
  final int selectedIndex;

  /// Laluan lain masih dicari; [options] boleh bertambah.
  final bool loadingMore;

  /// Pengguna menekan "Lagi": semua pilihan (sehingga 10) dipaparkan, bukan [collapsedCount] sahaja.
  final bool expanded;

  /// Anggaran tol mengikut [routeKey]; diisi di latar selepas laluan dipaparkan. Kosong = belum/
  /// tidak diketahui (kegagalan carian plaza tidak menghalang laluan).
  final Map<String, TollEstimate> tolls;

  /// Pilihan tol yang sedang digunakan pada [options].
  final RouteTollFilter tollFilter;

  /// Carian tamat dan tiada laluan memenuhi [tollFilter]: [options] menunjukkan semua laluan yang ada,
  /// dan lembaran mesti menyatakannya (bukan berpura-pura penapis berjaya).
  final bool tollFilterUnmet;

  /// Sekurang-kurangnya satu laluan ditemui melalui tol (sebelum penapis): pilihan tol bermakna.
  final bool hasTollChoice;

  /// "Tanpa tol" tidak terpenuhi tetapi semakan terakhir gagal (rangkaian/pelayan): tidak boleh
  /// mendakwa tiada laluan tanpa tol, hanya bahawa ia belum dapat dipastikan.
  final bool tollFilterUnverified;

  TollEstimate? tollOf(RouteOption option) => tolls[routeKey(option)];

  /// Bilangan kad yang dipaparkan sebelum pengguna menekan "Lagi".
  static const collapsedCount = 6;

  RouteOption get selected => options[selectedIndex];

  /// Pilihan yang dipaparkan (kad dan garisan peta).
  List<RouteOption> get visibleOptions =>
      expanded || options.length <= collapsedCount
      ? options
      : options.sublist(0, collapsedCount);

  /// Bilangan pilihan tersembunyi di sebalik "Lagi".
  int get hiddenCount => options.length - visibleOptions.length;

  /// Permintaan yang menghasilkan laluan terpilih. Navigasi menggunakannya untuk mengira semula
  /// bila menyimpang, jadi pilihan pengguna (cth. laluan tanpa tol) dikekalkan sepanjang perjalanan.
  /// Jika permintaan asal sendiri sudah "tanpa tol" (cth. diminta melalui FG AI), pilihan itu kekal.
  RouteQuery get selectedQuery => query.copyWith(
    avoidTolls:
        query.avoidTolls ||
        selected.label == RouteLabel.noTolls ||
        tollFilter == RouteTollFilter.noTolls,
    avoidHighways:
        query.avoidHighways || selected.label == RouteLabel.noHighways,
    shortest: query.shortest || selected.label == RouteLabel.shortest,
  );

  RouteReady copyWith({
    List<RouteOption>? options,
    int? selectedIndex,
    bool? loadingMore,
    bool? expanded,
    Map<String, TollEstimate>? tolls,
    RouteTollFilter? tollFilter,
    bool? tollFilterUnmet,
    bool? hasTollChoice,
    bool? tollFilterUnverified,
  }) => RouteReady(
    query: query,
    options: options ?? this.options,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    loadingMore: loadingMore ?? this.loadingMore,
    expanded: expanded ?? this.expanded,
    tolls: tolls ?? this.tolls,
    tollFilter: tollFilter ?? this.tollFilter,
    tollFilterUnmet: tollFilterUnmet ?? this.tollFilterUnmet,
    hasTollChoice: hasTollChoice ?? this.hasTollChoice,
    tollFilterUnverified: tollFilterUnverified ?? this.tollFilterUnverified,
  );

  RouteReady withSelected(int index) => copyWith(selectedIndex: index);
}

class RouteFailed extends RoutePreviewState {
  const RouteFailed({required this.query, required this.kind});

  final RouteQuery query;
  final RoutingFailureKind kind;
}

class RouteLocationUnavailable extends RoutePreviewState {
  const RouteLocationUnavailable({
    required this.destination,
    this.destinationLabel,
  });

  final GeoPoint destination;
  final String? destinationLabel;
}

class RoutePreviewController extends Notifier<RoutePreviewState> {
  /// Nombor permintaan terkini. Keputusan permintaan lama dibuang supaya tidak menimpa yang baharu
  /// (cth. pengguna menukar destinasi atau memadam laluan semasa menunggu).
  int _seq = 0;
  double? _radiusM;

  /// Titik mula pilihan pengguna untuk meneliti perjalanan; null = GPS. Kekal apabila destinasi atau
  /// pintu masuk ditukar, dan dilupakan apabila laluan dipadam.
  ({GeoPoint point, String label})? _origin;

  /// Perhentian permintaan terkini: keadaan "GPS tiada" belum ada query untuk menyimpannya.
  List<GeoPoint> _pendingVia = const [];

  /// Semakan "Tanpa tol" terakhir gagal, jadi ketiadaan laluan tanpa tol belum disahkan.
  bool _tollCheckIncomplete = false;

  /// Titik mula sedekat ini dengan destinasi dianggap tempat yang sama.
  static const _samePointM = 30.0;

  /// Semua laluan kelompok terkini sebelum penapis tol, supaya penapis ditukar tanpa rangkaian.
  List<RouteOption> _allOptions = const [];

  bool get hasCustomOrigin => _origin != null;

  /// Titik mula pilihan semasa (null = GPS), untuk dipaparkan semula dalam perancang.
  ({GeoPoint point, String label})? get customOrigin => _origin;

  /// Tetapkan titik mula untuk permintaan seterusnya tanpa mengira laluan.
  void setStart(GeoPoint? point, {String? label}) {
    _origin = point == null ? null : (point: point, label: label ?? '');
  }

  @override
  RoutePreviewState build() => const RouteIdle();

  /// Kira laluan ke [destination].
  ///
  /// Asal ialah titik mula pilihan pengguna jika ada; jika tidak GPS semasa, dan laluan tidak dikira
  /// jika GPS tiada fix yang boleh digunakan.
  Future<void> planTo(
    GeoPoint destination, {
    String? destinationLabel,
    double? radiusM,
    List<GeoPoint> via = const [],
  }) async {
    final seq = ++_seq;
    _radiusM = radiusM;
    _pendingVia = via;
    state = RouteLoading(
      destination: destination,
      destinationLabel: destinationLabel,
    );

    final avoidTolls =
        ref.read(routeTollFilterProvider) == RouteTollFilter.noTolls;
    final start = _origin;
    if (start != null) {
      final query = RouteQuery(
        origin: start.point,
        originLabel: start.label,
        destination: destination,
        vehicle: ref.read(routeVehicleProvider),
        avoidTolls: avoidTolls,
        destinationLabel: destinationLabel,
        destinationRadiusM: radiusM,
        via: via.take(5).toList(),
      );
      if (via.isEmpty &&
          distanceMeters(start.point, destination) < _samePointM) {
        state = RouteFailed(query: query, kind: RoutingFailureKind.samePoint);
        return;
      }
      await _fetch(query, seq);
      return;
    }

    final fix = await ref
        .read(locationServiceProvider)
        .currentFix(timeout: const Duration(seconds: 6));
    if (seq != _seq) return;
    if (fix == null) {
      state = RouteLocationUnavailable(
        destination: destination,
        destinationLabel: destinationLabel,
      );
      return;
    }

    final query = RouteQuery(
      origin: fix.point,
      destination: destination,
      headingDegrees: fix.headingDegrees,
      vehicle: ref.read(routeVehicleProvider),
      avoidTolls: avoidTolls,
      destinationLabel: destinationLabel,
      destinationRadiusM: radiusM,
      via: via.take(5).toList(),
    );
    await _fetch(query, seq);
  }

  /// Laluan baharu yang pasti bermula dari lokasi pengguna (permintaan AI), bukan pratonton terdahulu.
  Future<void> replanFromGps(GeoPoint destination, {String? label}) {
    setStart(null);
    return planTo(destination, destinationLabel: label);
  }

  /// Tukar titik mula laluan semasa ([point] null = kembali ke lokasi GPS) dan kira semula.
  Future<void> setOrigin(GeoPoint? point, {String? label}) async {
    final current = state;
    final query = _currentQuery;
    final destination =
        query?.destination ??
        switch (current) {
          RouteLoading() => current.destination,
          RouteLocationUnavailable() => current.destination,
          _ => null,
        };
    if (destination == null) return;
    setStart(point, label: label);
    await planTo(
      destination,
      destinationLabel:
          query?.destinationLabel ??
          switch (current) {
            RouteLoading() => current.destinationLabel,
            RouteLocationUnavailable() => current.destinationLabel,
            _ => null,
          },
      radiusM: query?.destinationRadiusM ?? _radiusM,
      via: query?.via ?? _pendingVia,
    );
  }

  /// Tukar pilihan tol. Disaring terus daripada laluan sedia ada apabila boleh; rangkaian hanya bila
  /// laluan yang diperlukan belum pernah diminta.
  Future<void> setTollFilter(RouteTollFilter filter) async {
    await ref.read(routeTollFilterProvider.notifier).set(filter);
    final current = state;
    final query = _currentQuery;
    if (query == null) return;
    final avoiding = query.avoidTolls || query.excludeTolls;
    if (current is! RouteReady ||
        (filter == RouteTollFilter.noTolls
            ? !avoiding && applyTollFilter(_allOptions, filter).isEmpty
            : avoiding)) {
      await _fetch(
        query.copyWith(
          avoidTolls: filter == RouteTollFilter.noTolls,
          excludeTolls: filter == RouteTollFilter.noTolls ? null : false,
        ),
        ++_seq,
      );
      return;
    }
    _pinned = null;
    _applyBatch(query, RouteBatch(_allOptions, done: !current.loadingMore));
  }

  /// Menukar kenderaan (kereta/motosikal), menyimpannya, dan mengira semula laluan aktif.
  Future<void> setVehicle(RouteVehicle vehicle) async {
    await ref.read(routeVehicleProvider.notifier).set(vehicle);
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query.copyWith(vehicle: vehicle), ++_seq);
  }

  Future<void> retry() async {
    final current = state;
    if (current is RouteLocationUnavailable) {
      await planTo(
        current.destination,
        destinationLabel: current.destinationLabel,
        radiusM: _radiusM,
        via: _pendingVia,
      );
      return;
    }
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query, ++_seq);
  }

  /// Kira semula laluan semasa dengan kehendak tegas (cth. "tanpa tol" daripada FG AI) apabila tiada
  /// pilihan sedia ada yang memenuhinya. Tiada kesan jika belum ada laluan.
  Future<void> replanWith({
    bool? avoidTolls,
    bool? excludeTolls,
    bool? avoidHighways,
    bool? shortest,
  }) async {
    final query = _currentQuery;
    if (query == null) return;
    // Permintaan tegas "tanpa tol" tidak boleh ditapis keluar oleh penapis "Dengan tol".
    if ((avoidTolls == true || excludeTolls == true) &&
        ref.read(routeTollFilterProvider) == RouteTollFilter.withTolls) {
      await ref.read(routeTollFilterProvider.notifier).set(RouteTollFilter.any);
    }
    await _fetch(
      query.copyWith(
        avoidTolls: avoidTolls,
        excludeTolls: excludeTolls,
        avoidHighways: avoidHighways,
        shortest: shortest,
      ),
      ++_seq,
    );
  }

  /// Laluan yang dipilih sendiri oleh pengguna: kekal terpilih walaupun senarai disusun semula
  /// apabila laluan lain tiba. Null = ikut laluan utama (indeks 0).
  RouteOption? _pinned;

  void select(int index) {
    final current = state;
    if (current is RouteReady && index >= 0 && index < current.options.length) {
      _pinned = index == 0 ? null : current.options[index];
      state = current.withSelected(index);
    }
  }

  /// Papar semua pilihan (sehingga 10) dan anggar tol untuk yang baru kelihatan.
  void showMore() {
    final current = state;
    if (current is RouteReady && !current.expanded) {
      state = current.copyWith(expanded: true);
      unawaited(_loadTolls(_seq));
    }
  }

  void clear() {
    _seq++;
    _origin = null;
    _pendingVia = const [];
    _allOptions = const [];
    state = const RouteIdle();
  }

  RouteQuery? get _currentQuery {
    final s = state;
    return switch (s) {
      RouteReady() => s.query,
      RouteFailed() => s.query,
      RouteLoading() => s.query,
      RouteLocationUnavailable() => null,
      RouteIdle() => null,
    };
  }

  Future<void> _fetch(RouteQuery query, int seq) async {
    _pinned = null;
    _tollCheckIncomplete = false;
    state = RouteLoading(
      destination: query.destination,
      query: query,
      destinationLabel: query.destinationLabel,
    );
    var received = false;
    try {
      await for (final batch in watchRoutes(
        ref.read(routeOptionsPlannerProvider),
        query,
      )) {
        if (seq != _seq) return;
        received = true;
        _applyBatch(query, batch);
        unawaited(_loadTolls(seq));
      }
    } on RoutingFailure catch (failure) {
      if (seq != _seq) return;
      if (received) return _settle(query, seq);
      state = RouteFailed(query: query, kind: failure.kind);
    } on Object catch (e, st) {
      // Kegagalan tidak dijangka mesti tidak meninggalkan lembaran "mengira" selama-lamanya.
      logDiag('Pengiraan laluan gagal: $e\n$st');
      if (seq != _seq) return;
      if (received) return _settle(query, seq);
      state = RouteFailed(query: query, kind: RoutingFailureKind.generic);
    }
    if (seq == _seq) await _settle(query, seq);
  }

  /// Laluan yang sedang dianggar tolnya (elak kerja berganda bila kelompok laluan baharu tiba).
  final Set<String> _tollsInFlight = {};

  /// Menganggar tol untuk semua laluan bertol yang belum ada anggaran, serentak (terpilih dahulu).
  /// Dipanggil bagi setiap kelompok laluan, jadi RM dipaparkan sebaik kad muncul. Senyap: kegagalan
  /// hanya bermakna anggaran tidak dipaparkan.
  Future<void> _loadTolls(int seq) async {
    if (!ref.read(tollLookupEnabledProvider)) return;
    final first = state;
    if (first is! RouteReady) return;
    // Semua pilihan bertol (bukan hanya yang kelihatan) supaya "Lagi" dan penukaran
    // kad terus menunjukkan RM tanpa menunggu muat semula.
    final pending =
        [
          first.selected,
          for (final o in first.options)
            if (!identical(o, first.selected)) o,
        ].where((o) {
          final key = routeKey(o);
          return o.hasTolls &&
              !first.tolls.containsKey(key) &&
              !_tollsInFlight.contains(key);
        }).toList();
    if (pending.isEmpty) return;

    final TollRates rates;
    try {
      rates = await ref.read(tollRatesProvider.future);
    } on Object {
      return;
    }
    if (!ref.mounted || seq != _seq) return;
    final finder = ref.read(tollPlazaFinderProvider);
    await Future.wait([
      for (final option in pending)
        () async {
          final key = routeKey(option);
          _tollsInFlight.add(key);
          try {
            final plazas = await finder.find(option);
            if (!ref.mounted) return;
            final current = state;
            if (current is! RouteReady) return;
            // Simpan selagi laluan ini masih dipaparkan, walaupun kelompok laluan baharu tiba semasa
            // menunggu (kelompok baharu melangkau kunci yang sedang dicari, jadi jangan buang hasil).
            if (seq != _seq &&
                !current.options.any((o) => routeKey(o) == key)) {
              return;
            }
            state = current.copyWith(
              tolls: {
                ...current.tolls,
                key: rates.estimate(
                  plazas,
                  current.query.vehicle,
                  route: option,
                ),
              },
            );
          } on TollLookupFailure {
            // Tiada anggaran untuk laluan ini: simpan "tiada plaza dikenal pasti" supaya paparan
            // berhenti "mengira" dan berkata harga tiada (bukan menunggu selama-lamanya).
            if (!ref.mounted) return;
            final current = state;
            if (current is! RouteReady ||
                !current.options.any((o) => routeKey(o) == key)) {
              return;
            }
            state = current.copyWith(
              tolls: {
                ...current.tolls,
                key: const TollEstimate(
                  plazaCount: 0,
                  unknownCount: 0,
                  knownRm: 0,
                ),
              },
            );
          } finally {
            _tollsInFlight.remove(key);
          }
        }(),
    ]);
  }

  /// Aliran tamat atau gagal selepas pilihan sedia ada: tamatkan penunjuk "mencari", dan penapis tol
  /// yang tidak terpenuhi mesti dinyatakan walaupun kelompok terakhir tidak pernah tiba.
  Future<void> _settle(RouteQuery query, int seq) async {
    final current = state;
    if (current is! RouteReady) return;
    if (current.loadingMore) {
      _applyBatch(query, RouteBatch(_allOptions, done: true));
    }
    await _confirmNoTolls(query, seq);
  }

  /// Sandaran "Tanpa tol": `use_tolls` hanya keutamaan lembut dan calon tambahan boleh gagal, jadi
  /// larangan mutlak dicuba sebelum app berkata tiada laluan tanpa tol.
  Future<void> _confirmNoTolls(RouteQuery query, int seq) async {
    final current = state;
    if (current is! RouteReady ||
        !current.tollFilterUnmet ||
        current.tollFilter != RouteTollFilter.noTolls ||
        query.excludeTolls) {
      return;
    }
    state = current.copyWith(loadingMore: true, tollFilterUnmet: false);
    try {
      // Perancang tunggal: tiada calon tambahan, satu sahaja permintaan ke pelayan awam.
      final strict = await ref
          .read(routePlannerProvider)
          .plan(query.copyWith(avoidTolls: true, excludeTolls: true));
      if (seq != _seq) return;
      final free = strict.where((o) => !o.hasTolls).toList();
      if (free.isNotEmpty) {
        _applyBatch(query, RouteBatch([...free, ..._allOptions], done: true));
        unawaited(_loadTolls(seq));
        return;
      }
    } on RoutingFailure catch (failure) {
      if (seq != _seq) return;
      _tollCheckIncomplete = failure.kind != RoutingFailureKind.noRoute;
    } on Object catch (e) {
      logDiag('Semakan laluan tanpa tol gagal: $e');
      if (seq != _seq) return;
      _tollCheckIncomplete = true;
    }
    _applyBatch(query, RouteBatch(_allOptions, done: true));
  }

  void _applyBatch(RouteQuery query, RouteBatch batch) {
    if (batch.options.isEmpty) {
      state = RouteFailed(query: query, kind: RoutingFailureKind.noRoute);
      return;
    }
    _allOptions = batch.options;
    final filter = ref.read(routeTollFilterProvider);
    final matching = applyTollFilter(batch.options, filter);
    // Tiada padanan: semua laluan kekal dipaparkan. Selagi carian berjalan padanan mungkin masih tiba.
    final options = matching.isEmpty ? batch.options : matching;
    final previous = state;
    final expanded = previous is RouteReady && previous.expanded;
    var selected = 0;
    final pinned = _pinned;
    if (pinned != null) {
      // Laluan pilihan pengguna kekal terpilih walaupun kedudukannya berubah.
      final index = options.indexWhere(
        (o) => identical(o.points, pinned.points),
      );
      final fallback = index >= 0
          ? index
          : options.indexWhere((o) => isSameRoute(o, pinned, threshold: 0.9));
      if (fallback >= 0) {
        selected = fallback;
        _pinned = options[fallback];
      } else {
        _pinned = null;
      }
    }
    state = RouteReady(
      query: query,
      options: options,
      selectedIndex: selected,
      tollFilter: filter,
      tollFilterUnmet: matching.isEmpty && batch.done,
      tollFilterUnverified:
          matching.isEmpty &&
          batch.done &&
          filter == RouteTollFilter.noTolls &&
          _tollCheckIncomplete,
      hasTollChoice: batch.options.any((o) => o.hasTolls),
      loadingMore: !batch.done,
      // Anggaran tol laluan yang masih ada dikekalkan (kunci ikut laluan, bukan indeks).
      tolls: previous is RouteReady && identical(previous.query, query)
          ? previous.tolls
          : const {},
      // Laluan terpilih di luar kad yang dipaparkan: buka semua supaya ia kelihatan.
      expanded: expanded || selected >= RouteReady.collapsedCount,
    );
  }
}

final routePreviewControllerProvider =
    NotifierProvider<RoutePreviewController, RoutePreviewState>(
      RoutePreviewController.new,
    );

/// Pencarian plaza tol dan anggaran harga di latar. Dimatikan dalam ujian yang tidak menguji tol.
final tollLookupEnabledProvider = Provider<bool>((ref) => true);
