import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/domain/route_options_merge.dart';
import '../../route_preview/domain/routing_failure.dart';
import 'navigation_controller.dart';

enum NavAlternativesStatus { idle, loading, ready, failed }

/// Pilihan laluan dari kedudukan semasa semasa dalam perjalanan.
@immutable
class NavAlternativesState {
  const NavAlternativesState({
    this.status = NavAlternativesStatus.idle,
    this.options = const [],
    this.currentIndex,
  });

  final NavAlternativesStatus status;
  final List<RouteOption> options;

  /// Indeks pilihan yang sama dengan laluan yang sedang diikuti; null jika tiada yang menyerupainya.
  final int? currentIndex;

  /// Geometri pilihan selain laluan semasa (yang sudah dilukis sebagai laluan utama), untuk peta.
  List<List<GeoPoint>> get otherRoutes => [
    for (var i = 0; i < options.length; i++)
      if (i != currentIndex) options[i].points,
  ];
}

class NavAlternativesController extends Notifier<NavAlternativesState> {
  int _seq = 0;

  @override
  NavAlternativesState build() => const NavAlternativesState();

  Future<void> load() async {
    final seq = ++_seq;
    state = const NavAlternativesState(status: NavAlternativesStatus.loading);
    final nav = ref.read(navigationControllerProvider.notifier);
    try {
      final options = await nav.planAlternatives();
      if (seq != _seq || !ref.mounted) return;
      final remaining = _remainingOption(
        ref.read(navigationControllerProvider),
      );
      final current = remaining == null
          ? null
          : _indexOfSame(options, remaining);
      state = NavAlternativesState(
        status: options.isEmpty
            ? NavAlternativesStatus.failed
            : NavAlternativesStatus.ready,
        options: options,
        currentIndex: current,
      );
    } on RoutingFailure {
      if (seq != _seq || !ref.mounted) return;
      state = const NavAlternativesState(status: NavAlternativesStatus.failed);
    } on Object catch (e) {
      debugPrint('Mencari laluan alternatif gagal: $e');
      if (seq != _seq || !ref.mounted) return;
      state = const NavAlternativesState(status: NavAlternativesStatus.failed);
    }
  }

  void clear() {
    _seq++;
    state = const NavAlternativesState();
  }

  /// Laluan baki (dari kedudukan semasa) sebagai pilihan, untuk dibandingkan dengan calon.
  static RouteOption? _remainingOption(NavigationState nav) {
    final route = nav.route;
    final progress = nav.progress;
    if (route == null || progress == null) return null;
    return RouteOption(
      distanceM: progress.remainingM.round(),
      durationS: progress.remainingS.round(),
      hasTolls: false,
      points: route.remainingShape(progress.alongM, aheadM: route.totalM),
    );
  }

  static int? _indexOfSame(List<RouteOption> options, RouteOption remaining) {
    int? best;
    var bestScore = 0.0;
    for (var i = 0; i < options.length; i++) {
      final a = routeCoverage(options[i].points, remaining.points);
      final b = routeCoverage(remaining.points, options[i].points);
      final score = a < b ? a : b;
      if (score >= 0.85 && score > bestScore) {
        best = i;
        bestScore = score;
      }
    }
    return best;
  }
}

final navAlternativesProvider =
    NotifierProvider<NavAlternativesController, NavAlternativesState>(
      NavAlternativesController.new,
    );
