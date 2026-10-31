import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../data/adhan_prayer_calculator.dart';
import '../data/azan_location.dart';
import '../data/azan_player.dart';
import '../data/azan_scheduler.dart';
import '../data/azan_settings.dart';
import '../data/official_prayer_times.dart';
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
    this.notificationsBlocked = false,
    this.location,
    this.locationKnown = true,
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

  /// Azan dihidupkan tetapi notifikasi telah dimatikan dalam tetapan telefon: tiada azan akan
  /// berbunyi apabila app ditutup sehingga pengguna membenarkannya semula.
  final bool notificationsBlocked;

  /// Lokasi yang digunakan untuk pengiraan semasa.
  final GeoPoint? location;

  /// Lokasi sebenar (GPS atau bandar pilihan) diketahui. Palsu = waktu dikira untuk Kuala Lumpur
  /// sebagai andaian sehingga lokasi tersedia.
  final bool locationKnown;

  /// Waktu hari ini ialah data rasmi JAKIM (bukan pengiraan pada telefon).
  bool get isOfficial => today?.isOfficial ?? false;

  /// Kod zon JAKIM jika [isOfficial].
  String? get zone => today?.zone;

  AzanState copyWith({
    DailyPrayerTimes? today,
    Prayer? next,
    DateTime? nextAt,
    bool clearNext = false,
    Prayer? nowPlaying,
    bool clearNowPlaying = false,
    bool? exactAllowed,
    bool? permissionDenied,
    bool? notificationsBlocked,
    GeoPoint? location,
    bool? locationKnown,
  }) => AzanState(
    today: today ?? this.today,
    next: clearNext ? null : (next ?? this.next),
    nextAt: clearNext ? null : (nextAt ?? this.nextAt),
    nowPlaying: clearNowPlaying ? null : (nowPlaying ?? this.nowPlaying),
    exactAllowed: exactAllowed ?? this.exactAllowed,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    notificationsBlocked: notificationsBlocked ?? this.notificationsBlocked,
    location: location ?? this.location,
    locationKnown: locationKnown ?? this.locationKnown,
  );
}

/// Hasil menghidupkan azan; UI menerangkan setiap keadaan kepada pengguna.
enum AzanEnableResult {
  /// Hidup dan penggera tepat dibenarkan.
  enabled,

  /// Hidup tetapi Android 12+ belum membenarkan penggera tepat: notifikasi mungkin lewat.
  needsExactAlarm,

  /// Kebenaran notifikasi ditolak (atau disekat): azan kekal mati.
  permissionDenied,
}

const _scheduledAtKey = 'azan.scheduledAt';
const _scheduledLatKey = 'azan.scheduledLat';
const _scheduledLngKey = 'azan.scheduledLng';
const _scheduledSigKey = 'azan.scheduledSig';

/// Kunci kedudukan jadual terakhir; dipadam bersama [azanLocationKeys].
const azanScheduleKeys = [
  _scheduledAtKey,
  _scheduledLatKey,
  _scheduledLngKey,
  _scheduledSigKey,
];

/// Berapa awal (sebelum waktu) app yang terbuka mengambil alih daripada notifikasi OS.
const _preemptLead = Duration(seconds: 2);

/// Mengira waktu hari ini, menjadualkan notifikasi OS, dan membunyikan azan dalam app apabila
/// waktu masuk semasa app terbuka.
///
/// Laluan yang boleh dipercayai ialah notifikasi OS (berbunyi walaupun app ditutup). Apabila app
/// terbuka (atau navigasi aktif) pengawal ini mengambil alih beberapa saat sebelum waktu: ia
/// membatalkan notifikasi OS yang sepadan supaya azan tidak berbunyi dua kali, kemudian memainkan
/// azan sendiri. Semasa navigasi aktif hanya nada pendek + cip HUD (arahan suara tidak boleh
/// ditenggelamkan oleh azan 90 saat), melainkan pengguna menghidupkan "Main azan penuh semasa
/// navigasi".
class AzanController extends Notifier<AzanState> {
  Timer? _preemptTimer;
  Timer? _nextTimer;
  Timer? _midnightTimer;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<String>? _tapSub;
  Future<void>? _rescheduling;
  bool _foreground = true;

  /// Dipanggil apabila pengguna mengetik notifikasi (muatan `azan:...`). Tidak ditutup apabila
  /// pengawal dibina semula: pendengar di skrin peta mesti terus menerima ketikan.
  final tapped = StreamController<String>.broadcast();

  /// Teks notifikasi semasa (ditetapkan oleh UI mengikut bahasa). Tanpa ini, jadual OS dilangkau
  /// (waktu dalam app tetap dikira).
  AzanNotificationTexts? _texts;

  @override
  AzanState build() {
    final settings = ref.watch(azanSettingsProvider);
    final location = ref.watch(effectiveAzanLocationProvider);
    final now = ref.watch(azanClockProvider)();
    // Memerhati penyedia pengira: apabila waktu rasmi JAKIM tiba, waktu dikira semula serta-merta.
    final calculator = ref.watch(prayerCalculatorProvider);
    final today = calculator.compute(
      at: location,
      day: now,
      method: settings.method,
      madhab: settings.madhab,
    );
    // Dibina semula berkali-kali (tetapan, lokasi, hari baharu): pendengar dibuat semula setiap kali.
    ref.onDispose(() {
      _preemptTimer?.cancel();
      _nextTimer?.cancel();
      _midnightTimer?.cancel();
      unawaited(_completedSub?.cancel());
      unawaited(_tapSub?.cancel());
    });
    _completedSub = ref.read(azanPlayerProvider).completed.listen((_) {
      if (ref.mounted) state = state.copyWith(clearNowPlaying: true);
    });
    _tapSub = ref.read(azanSchedulerProvider).taps.listen(tapped.add);

    final next = today.nextAfter(now);
    final hasRealLocation =
        settings.useCity || ref.watch(azanLocationProvider) != null;
    final initial = AzanState(
      today: today,
      next: next,
      nextAt: next == null ? null : today.timeOf(next),
      location: location,
      locationKnown: hasRealLocation,
      exactAllowed: state.exactAllowed,
      permissionDenied: state.permissionDenied,
      notificationsBlocked: state.notificationsBlocked,
      nowPlaying: state.nowPlaying,
    );
    _armTimers(initial, settings, now);
    // Tetapan/lokasi berubah: jadual OS perlu dikemas kini (tandatangan jadual mengelak kerja sia-sia).
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
    _preemptTimer?.cancel();
    _nextTimer?.cancel();
    _midnightTimer?.cancel();
    final nextAt = s.nextAt;
    final next = s.next;
    if (settings.enabled &&
        nextAt != null &&
        next != null &&
        settings.prayers.contains(next)) {
      final wait = nextAt.difference(now);
      if (wait > Duration.zero) {
        _nextTimer = Timer(wait, () => _onPrayerTime(next));
        if (wait > _preemptLead) {
          _preemptTimer = Timer(wait - _preemptLead, () => _preempt(next));
        }
      }
    }
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (ref.mounted) ref.invalidateSelf();
    });
  }

  bool get _takesOver =>
      _foreground || ref.read(navigationControllerProvider).isActive;

  int? _notificationIdOf(Prayer prayer) {
    final today = state.today;
    return today == null ? null : azanNotificationId(today.day, prayer);
  }

  /// Beberapa saat sebelum waktu: jika app terbuka (atau navigasi aktif), batalkan notifikasi OS
  /// yang sepadan supaya hanya satu azan berbunyi. Jika app di latar, biarkan OS melakukannya.
  void _preempt(Prayer prayer) {
    if (!ref.mounted || !_takesOver) return;
    final id = _notificationIdOf(prayer);
    if (id != null) unawaited(ref.read(azanSchedulerProvider).cancel(id));
  }

  /// Waktu masuk.
  void _onPrayerTime(Prayer prayer) {
    if (!ref.mounted) return;
    final settings = ref.read(azanSettingsProvider);
    if (!settings.enabled || !settings.prayers.contains(prayer)) return;
    final navigating = ref.read(navigationControllerProvider).isActive;
    final takesOver = _foreground || navigating;
    if (takesOver) {
      final id = _notificationIdOf(prayer);
      if (id != null) unawaited(ref.read(azanSchedulerProvider).cancel(id));
      final sound = navigating && !settings.playDuringNavigation
          ? AzanSound.short
          : settings.sound;
      state = state.copyWith(nowPlaying: prayer);
      unawaited(ref.read(azanPlayerProvider).play(sound));
    }
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

  /// App ke latar: notifikasi OS menjadi satu-satunya laluan azan (kecuali navigasi aktif).
  void onAppBackgrounded() => _foreground = false;

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

  /// Hidupkan: minta kebenaran notifikasi dahulu; jika ditolak azan kekal mati. Jika dibenarkan:
  /// ambil lokasi segar, ambil waktu rasmi JAKIM, jadualkan seminggu, dan semak penggera tepat.
  Future<AzanEnableResult> enable() async {
    final scheduler = ref.read(azanSchedulerProvider);
    final ok = await scheduler.requestPermissions();
    if (!ref.mounted) return AzanEnableResult.permissionDenied;
    if (!ok) {
      state = state.copyWith(
        permissionDenied: true,
        notificationsBlocked: true,
      );
      return AzanEnableResult.permissionDenied;
    }
    state = state.copyWith(
      permissionDenied: false,
      notificationsBlocked: false,
    );
    await ref.read(azanSettingsProvider.notifier).setEnabled(true);
    await refreshLocation();
    await reschedule(force: true);
    await refreshPermissionState();
    return state.exactAllowed
        ? AzanEnableResult.enabled
        : AzanEnableResult.needsExactAlarm;
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

  /// Semak semula kebenaran penggera tepat dan notifikasi (pengguna boleh mengubahnya dalam tetapan
  /// telefon pada bila-bila masa, cth. selepas kembali dari tetapan).
  Future<void> refreshPermissionState({bool rescheduleOnChange = true}) async {
    final scheduler = ref.read(azanSchedulerProvider);
    final exact = await scheduler.canScheduleExact();
    final notifications = await scheduler.notificationsEnabled();
    if (!ref.mounted) return;
    final exactChanged = exact != state.exactAllowed;
    state = state.copyWith(
      exactAllowed: exact,
      notificationsBlocked: !notifications,
    );
    // Pengguna baru membenarkan (atau menarik balik) penggera tepat: notifikasi yang sudah dijadualkan
    // masih menggunakan mod lama (tetingkap sehingga 1 jam), jadi jadualkan semula dengan mod baharu.
    if (rescheduleOnChange &&
        exactChanged &&
        ref.read(azanSettingsProvider).enabled) {
      unawaited(reschedule());
    }
  }

  /// Fix lokasi segar (tanpa dialog kebenaran) untuk waktu yang tepat. Senyap jika lokasi tidak
  /// dibenarkan; waktu kemudian dikira untuk lokasi terakhir yang diketahui atau Kuala Lumpur.
  Future<void> refreshLocation() async {
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .currentFix(
            timeout: const Duration(seconds: 6),
            maxAccuracyMeters: 3000,
            fallbackAccuracyMeters: 20000,
          );
      if (fix != null && ref.mounted) {
        ref.read(azanLocationProvider.notifier).update(fix.point, force: true);
      }
    } on Object catch (e) {
      logDiag('Lokasi azan tidak dapat dikemas kini: $e');
    }
  }

  /// Ambil waktu rasmi JAKIM untuk lokasi semasa (untuk paparan, walaupun notifikasi mati).
  Future<void> refreshOfficial() async {
    final settings = ref.read(azanSettingsProvider);
    if (!_officialApplies(settings)) return;
    await ref
        .read(officialTimesProvider.notifier)
        .ensure(
          at: ref.read(effectiveAzanLocationProvider),
          now: ref.read(azanClockProvider)(),
          days: 2,
        );
  }

  bool _officialApplies(AzanSettings s) =>
      s.useOfficial &&
      s.method == AzanMethod.jakim &&
      s.madhab == AzanMadhab.shafi;

  /// App kembali ke hadapan: waktu seterusnya dikira semula, kebenaran disemak (pengguna mungkin
  /// mematikan notifikasi) dan lokasi disegarkan; jadual dikemas kini jika perlu.
  Future<void> onAppResumed() async {
    _foreground = true;
    ref.invalidateSelf();
    await refreshPermissionState();
    if (ref.mounted && ref.read(azanSettingsProvider).enabled) {
      unawaited(refreshLocation());
    }
  }

  /// Fix lokasi baharu daripada peta.
  void onLocation(GeoPoint point) =>
      ref.read(azanLocationProvider.notifier).update(point);

  /// Jadualkan seminggu notifikasi. Tanpa [force], dilangkau jika jadual semasa dibuat hari ini
  /// untuk lokasi dalam 20 km dengan tetapan yang sama (jimat kerja apabila app dibuka berulang kali).
  /// Permintaan berturutan disiri supaya dua jadual tidak berlumba menggantikan satu sama lain.
  Future<void> reschedule({bool force = false}) {
    final pending = _rescheduling;
    if (pending != null && !force) return pending;
    final run = (pending ?? Future<void>.value()).then(
      (_) => _reschedule(force),
    );
    late final Future<void> chained;
    chained = run.whenComplete(() {
      if (identical(_rescheduling, chained)) _rescheduling = null;
    });
    return _rescheduling = chained;
  }

  Future<void> _reschedule(bool force) async {
    final settings = ref.read(azanSettingsProvider);
    final texts = _texts;
    if (!ref.mounted || !settings.enabled || texts == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final now = ref.read(azanClockProvider)();
    final at = ref.read(effectiveAzanLocationProvider);
    // Keadaan penggera tepat sebenar mesti diketahui SEBELUM tandatangan dikira; jika tidak,
    // jadual pertama direkod sebagai "tepat" walaupun dijadualkan secara tidak tepat.
    await refreshPermissionState(rescheduleOnChange: false);
    if (!ref.mounted) return;
    // Waktu rasmi JAKIM dahulu (jika dibenarkan dan ada talian); kegagalan = pengiraan pada telefon.
    var refreshed = false;
    if (_officialApplies(settings)) {
      refreshed = await ref
          .read(officialTimesProvider.notifier)
          .ensure(at: at, now: now);
      if (!ref.mounted) return;
    }
    final calculator = ref.read(prayerCalculatorProvider);
    final today = calculator.compute(
      at: at,
      day: now,
      method: settings.method,
      madhab: settings.madhab,
    );
    final signature = azanScheduleSignature(
      settings,
      source: today.zone ?? 'calc',
      locale: texts.locale.languageCode,
      exact: state.exactAllowed,
    );
    if (!force && !refreshed) {
      final lastMs = prefs.getInt(_scheduledAtKey);
      final lat = prefs.getDouble(_scheduledLatKey);
      final lng = prefs.getDouble(_scheduledLngKey);
      if (lastMs != null &&
          lat != null &&
          lng != null &&
          prefs.getString(_scheduledSigKey) == signature) {
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
      calculator: calculator,
    );
    try {
      await ref.read(azanSchedulerProvider).replaceAll(items, texts);
      await prefs.setInt(_scheduledAtKey, now.millisecondsSinceEpoch);
      await prefs.setDouble(_scheduledLatKey, at.lat);
      await prefs.setDouble(_scheduledLngKey, at.lng);
      await prefs.setString(_scheduledSigKey, signature);
    } on Object catch (e) {
      logDiag('Jadual azan gagal: $e');
    }
  }
}

final azanControllerProvider = NotifierProvider<AzanController, AzanState>(
  AzanController.new,
);
