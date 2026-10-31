import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../data/adhan_prayer_calculator.dart';
import '../data/azan_location.dart';
import '../data/azan_player.dart';
import '../data/azan_scheduler.dart';
import '../data/azan_settings.dart';
import '../domain/azan_plan.dart';
import '../domain/prayer.dart';
import '../domain/prayer_times.dart';

/// Jam untuk waktu azan; diganti dalam ujian.
final azanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

@immutable
class AzanState {
  const AzanState({
    this.today,
    this.next,
    this.nextAt,
    this.nowPlaying,
    this.exactAllowed = true,
    this.permissionDenied = false,
    this.location,
  });

  final DailyPrayerTimes? today;

  /// Waktu fardu seterusnya hari ini; null selepas Isyak.
  final Prayer? next;
  final DateTime? nextAt;

  /// Azan yang sedang dimainkan dalam app (sepanduk/cip ditunjukkan); null jika tiada.
  final Prayer? nowPlaying;

  /// Android 12+: penggera tepat dibenarkan. Palsu = notifikasi mungkin lewat beberapa minit.
  final bool exactAllowed;
  final bool permissionDenied;

  /// Lokasi yang digunakan untuk pengiraan semasa.
  final GeoPoint? location;

  AzanState copyWith({
    DailyPrayerTimes? today,
    Prayer? next,
    DateTime? nextAt,
    bool clearNext = false,
    Prayer? nowPlaying,
    bool clearNowPlaying = false,
    bool? exactAllowed,
    bool? permissionDenied,
    GeoPoint? location,
  }) => AzanState(
    today: today ?? this.today,
    next: clearNext ? null : (next ?? this.next),
    nextAt: clearNext ? null : (nextAt ?? this.nextAt),
    nowPlaying: clearNowPlaying ? null : (nowPlaying ?? this.nowPlaying),
    exactAllowed: exactAllowed ?? this.exactAllowed,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    location: location ?? this.location,
  );
}

const _scheduledAtKey = 'azan.scheduledAt';
const _scheduledLatKey = 'azan.scheduledLat';
const _scheduledLngKey = 'azan.scheduledLng';

/// Kunci kedudukan jadual terakhir; dipadam bersama [azanLocationKeys].
const azanScheduleKeys = [_scheduledAtKey, _scheduledLatKey, _scheduledLngKey];

/// Mengira waktu hari ini, menjadualkan notifikasi OS, dan membunyikan azan dalam app apabila
/// waktu masuk semasa app terbuka.
///
/// Peraturan semasa navigasi aktif: hanya nada pendek + cip HUD (arahan suara tidak boleh
/// ditenggelamkan oleh azan 90 saat), melainkan pengguna menghidupkan "Main azan penuh semasa
/// navigasi". Notifikasi OS tetap dihantar dalam semua kes: itulah laluan yang boleh dipercayai
/// apabila app ditutup.
class AzanController extends Notifier<AzanState> {
  Timer? _nextTimer;
  Timer? _midnightTimer;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<String>? _tapSub;
  Future<void>? _rescheduling;

  /// Dipanggil apabila pengguna mengetik notifikasi (muatan `azan:...`).
  final tapped = StreamController<String>.broadcast();

  /// Teks notifikasi semasa (ditetapkan oleh UI mengikut bahasa). Tanpa ini, jadual OS dilangkau
  /// (waktu dalam app tetap dikira).
  AzanNotificationTexts? _texts;

  @override
  AzanState build() {
    final settings = ref.watch(azanSettingsProvider);
    final location = ref.watch(effectiveAzanLocationProvider);
    final now = ref.watch(azanClockProvider)();
    final today = ref
        .read(prayerCalculatorProvider)
        .compute(
          at: location,
          day: now,
          method: settings.method,
          madhab: settings.madhab,
        );
    ref.onDispose(() {
      _nextTimer?.cancel();
      _midnightTimer?.cancel();
      unawaited(_completedSub?.cancel());
      unawaited(_tapSub?.cancel());
      unawaited(tapped.close());
    });
    _completedSub ??= ref.read(azanPlayerProvider).completed.listen((_) {
      if (ref.mounted) state = state.copyWith(clearNowPlaying: true);
    });
    _tapSub ??= ref.read(azanSchedulerProvider).taps.listen(tapped.add);

    final next = today.nextAfter(now);
    final initial = AzanState(
      today: today,
      next: next,
      nextAt: next == null ? null : today.timeOf(next),
      location: location,
      exactAllowed: state.exactAllowed,
      permissionDenied: state.permissionDenied,
      nowPlaying: state.nowPlaying,
    );
    _armTimers(initial, settings, now);
    // Tetapan/lokasi berubah: jadual OS perlu dikemas kini (dinyahlantun oleh _rescheduling).
    if (settings.enabled) unawaited(reschedule());
    return initial;
  }

  // Pembinaan semula pertama: `state` belum wujud. Riverpod melontar jika dibaca sebelum ditetapkan.
  @override
  AzanState get state {
    try {
      return super.state;
    } on StateError {
      return const AzanState();
    }
  }

  void _armTimers(AzanState s, AzanSettings settings, DateTime now) {
    _nextTimer?.cancel();
    _midnightTimer?.cancel();
    final nextAt = s.nextAt;
    if (settings.enabled && nextAt != null && s.next != null) {
      final wait = nextAt.difference(now);
      if (wait > Duration.zero && settings.prayers.contains(s.next)) {
        _nextTimer = Timer(wait, () => _onPrayerTime(s.next!));
      }
    }
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (ref.mounted) ref.invalidateSelf();
    });
  }

  /// Waktu masuk semasa app terbuka.
  void _onPrayerTime(Prayer prayer) {
    if (!ref.mounted) return;
    final settings = ref.read(azanSettingsProvider);
    if (!settings.enabled || !settings.prayers.contains(prayer)) return;
    final navigating = ref.read(navigationControllerProvider).isActive;
    final sound = navigating && !settings.playDuringNavigation
        ? AzanSound.short
        : settings.sound;
    state = state.copyWith(nowPlaying: prayer);
    unawaited(ref.read(azanPlayerProvider).play(sound));
    // Kira waktu seterusnya tanpa menunggu tengah malam. Pemasa boleh menyala beberapa milisaat
    // sebelum waktu sebenar: cari selepas waktu ini (bukan `now`) supaya tidak berbunyi dua kali.
    final now = ref.read(azanClockProvider)();
    final today = state.today;
    if (today != null) {
      final fired = today.timeOf(prayer) ?? now;
      final after = fired.isAfter(now) ? fired : now;
      final next = today.nextAfter(after);
      state = next == null
          ? state.copyWith(clearNext: true)
          : state.copyWith(next: next, nextAt: today.timeOf(next));
      _armTimers(state, settings, now);
    }
  }

  /// Hentikan azan yang sedang dimainkan dan sembunyikan sepanduk.
  Future<void> dismiss() async {
    await ref.read(azanPlayerProvider).stop();
    if (ref.mounted) state = state.copyWith(clearNowPlaying: true);
  }

  /// Pratonton azan daripada tetapan.
  Future<void> preview() async {
    state = state.copyWith(nowPlaying: state.next ?? Prayer.dhuhr);
    await ref.read(azanPlayerProvider).play(AzanSound.full);
  }

  /// Teks notifikasi mengikut bahasa UI semasa. Dipanggil oleh skrin yang memaparkan azan.
  void setTexts(AzanNotificationTexts texts) {
    final changed = _texts?.locale != texts.locale;
    _texts = texts;
    if (changed && ref.read(azanSettingsProvider).enabled) {
      unawaited(reschedule(force: true));
    }
  }

  /// Hidupkan: minta kebenaran dahulu; gagal = kekal mati dan tandakan [AzanState.permissionDenied].
  Future<bool> enable() async {
    final scheduler = ref.read(azanSchedulerProvider);
    final ok = await scheduler.requestPermissions();
    if (!ref.mounted) return false;
    if (!ok) {
      state = state.copyWith(permissionDenied: true);
      return false;
    }
    state = state.copyWith(permissionDenied: false);
    await ref.read(azanSettingsProvider.notifier).setEnabled(true);
    await reschedule(force: true);
    return true;
  }

  Future<void> disable() async {
    await ref.read(azanSettingsProvider.notifier).setEnabled(false);
    await ref.read(azanSchedulerProvider).cancelAll();
    final prefs = ref.read(sharedPreferencesProvider);
    for (final k in azanScheduleKeys) {
      await prefs.remove(k);
    }
  }

  Future<void> openExactAlarmSettings() =>
      ref.read(azanSchedulerProvider).openExactAlarmSettings();

  /// Semak semula kebenaran penggera tepat (cth. selepas kembali dari tetapan).
  Future<void> refreshExactAllowed() async {
    final exact = await ref.read(azanSchedulerProvider).canScheduleExact();
    if (ref.mounted) state = state.copyWith(exactAllowed: exact);
  }

  /// App kembali ke hadapan: waktu seterusnya dikira semula dan jadual disemak jika basi.
  Future<void> onAppResumed() async {
    ref.invalidateSelf();
    await refreshExactAllowed();
  }

  /// Fix lokasi baharu daripada peta.
  void onLocation(GeoPoint point) =>
      ref.read(azanLocationProvider.notifier).update(point);

  /// Jadualkan 2 hari notifikasi. Tanpa [force], dilangkau jika jadual semasa dibuat hari ini
  /// untuk lokasi dalam 20 km (jimat kerja apabila app dibuka berulang kali).
  Future<void> reschedule({bool force = false}) {
    final pending = _rescheduling;
    if (pending != null && !force) return pending;
    return _rescheduling = _reschedule(force).whenComplete(() {
      _rescheduling = null;
    });
  }

  Future<void> _reschedule(bool force) async {
    final settings = ref.read(azanSettingsProvider);
    final texts = _texts;
    if (!settings.enabled || texts == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final now = ref.read(azanClockProvider)();
    final at = ref.read(effectiveAzanLocationProvider);
    if (!force) {
      final lastMs = prefs.getInt(_scheduledAtKey);
      final lat = prefs.getDouble(_scheduledLatKey);
      final lng = prefs.getDouble(_scheduledLngKey);
      if (lastMs != null && lat != null && lng != null) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final sameDay =
            last.year == now.year &&
            last.month == now.month &&
            last.day == now.day;
        if (sameDay && distanceMeters(GeoPoint(lat, lng), at) < 20000) return;
      }
    }
    final items = planAzanSchedule(
      now: now,
      at: at,
      settings: settings,
      calculator: ref.read(prayerCalculatorProvider),
    );
    try {
      await ref.read(azanSchedulerProvider).replaceAll(items, texts);
      await prefs.setInt(_scheduledAtKey, now.millisecondsSinceEpoch);
      await prefs.setDouble(_scheduledLatKey, at.lat);
      await prefs.setDouble(_scheduledLngKey, at.lng);
      await refreshExactAllowed();
    } on Object catch (e) {
      logDiag('Jadual azan gagal: $e');
    }
  }
}

final azanControllerProvider = NotifierProvider<AzanController, AzanState>(
  AzanController.new,
);
