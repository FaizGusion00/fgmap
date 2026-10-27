import 'package:flutter/scheduler.dart';

import '../utils/log.dart';

/// Statistik bingkai untuk diagnostik jank. Bingkai dianggap "jank" jika membina atau melukis lebih
/// lama daripada [budget] (lalai 16.7 ms = 60 fps); "teruk" jika lebih 2x anggaran.
class JankStats {
  JankStats({this.budget = const Duration(microseconds: 16667)});

  final Duration budget;
  int frames = 0;
  int janky = 0;
  int severe = 0;
  Duration worst = Duration.zero;

  void add(Duration build, Duration raster) {
    frames++;
    final total = build > raster ? build : raster;
    if (total > worst) worst = total;
    if (total > budget) janky++;
    if (total > budget * 2) severe++;
  }

  double get jankPercent => frames == 0 ? 0 : janky * 100 / frames;

  String summary() =>
      '$frames bingkai, jank ${jankPercent.toStringAsFixed(1)}% '
      '($janky), teruk $severe, terburuk ${worst.inMilliseconds} ms';

  void reset() {
    frames = 0;
    janky = 0;
    severe = 0;
    worst = Duration.zero;
  }
}

/// Memantau masa bingkai sebenar dan mencetak ringkasan setiap [interval] (hanya
/// `--dart-define=FG_DIAG=true`, mod debug/profile). Untuk mengukur kelancaran pada peranti sebenar;
/// tiada kesan dalam build biasa.
class FrameMonitor {
  FrameMonitor({this.interval = const Duration(seconds: 5), JankStats? stats})
    : stats = stats ?? JankStats();

  static const enabled = bool.fromEnvironment('FG_DIAG');

  final Duration interval;
  final JankStats stats;
  DateTime _since = DateTime.now();
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      stats.add(t.buildDuration, t.rasterDuration);
    }
    final now = DateTime.now();
    if (now.difference(_since) >= interval) {
      logDiag('FGDIAG frame: ${stats.summary()}');
      stats.reset();
      _since = now;
    }
  }
}
