import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../route_preview/domain/route_option.dart';
import '../data/along_route_search.dart';
import '../domain/along_route_category.dart';
import '../domain/along_route_poi.dart';

class AlongRouteState {
  const AlongRouteState({
    this.category = AlongRouteCategory.restArea,
    this.pois = const [],
    this.loading = false,
    this.error,
  });

  final AlongRouteCategory category;
  final List<AlongRoutePoi> pois;
  final bool loading;
  final String? error;

  AlongRouteState copyWith({
    AlongRouteCategory? category,
    List<AlongRoutePoi>? pois,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => AlongRouteState(
    category: category ?? this.category,
    pois: pois ?? this.pois,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class AlongRouteController extends Notifier<AlongRouteState> {
  CancelToken? _cancel;
  List<GeoPoint>? _points;
  int _seq = 0;

  @override
  AlongRouteState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      _seq++;
    });
    return const AlongRouteState();
  }

  Future<void> loadForRoute(
    RouteOption route, {
    AlongRouteCategory? category,
  }) async {
    _points = route.points;
    await _search(route.points, category ?? state.category);
  }

  Future<void> selectCategory(AlongRouteCategory cat) async {
    final points = _points;
    if (points == null || points.length < 2) {
      state = state.copyWith(category: cat, pois: const []);
      return;
    }
    await _search(points, cat);
  }

  Future<void> _search(List<GeoPoint> points, AlongRouteCategory cat) async {
    final seq = ++_seq;
    _cancel?.cancel();
    _cancel = CancelToken();
    state = state.copyWith(category: cat, loading: true, clearError: true);
    try {
      final pois = await ref
          .read(alongRouteSearchProvider)
          .search(
            routePoints: points,
            category: cat,
            fallbackName: _fallback(cat),
            cancel: _cancel,
          );
      if (seq != _seq) return;
      state = state.copyWith(pois: pois, loading: false, clearError: true);
    } on DioException catch (e) {
      if (seq != _seq) return;
      if (e.type == DioExceptionType.cancel) return;
      state = state.copyWith(
        loading: false,
        error: 'unavailable',
        pois: const [],
      );
    } catch (_) {
      if (seq != _seq) return;
      state = state.copyWith(
        loading: false,
        error: 'unavailable',
        pois: const [],
      );
    }
  }

  void clear() {
    _cancel?.cancel();
    _seq++;
    _points = null;
    state = const AlongRouteState();
  }

  String _fallback(AlongRouteCategory c) => switch (c) {
    AlongRouteCategory.restArea => 'R&R',
    AlongRouteCategory.fuel => 'Stesen minyak',
    AlongRouteCategory.evCharging => 'Pengecas EV',
    AlongRouteCategory.mosque => 'Surau',
    AlongRouteCategory.toilets => 'Tandas',
  };
}

final alongRouteControllerProvider =
    NotifierProvider<AlongRouteController, AlongRouteState>(
      AlongRouteController.new,
    );
