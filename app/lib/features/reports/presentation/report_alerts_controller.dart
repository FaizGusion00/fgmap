import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/domain/announcement_planner.dart';
import '../../navigation/domain/instruction_text.dart';
import '../domain/report.dart';
import '../domain/report_alerts.dart';
import 'reports_controller.dart';

@immutable
class ReportAlertsState {
  const ReportAlertsState({this.ask});

  /// Laporan yang sedang dilepasi dan menunggu jawapan "Masih ada?"; null jika tiada soalan.
  final Report? ask;
}

/// Amaran laporan semasa memandu: mengumumkan laporan di hadapan (sekali setiap satu bagi satu
/// perjalanan) dan menanya "Masih ada?" apabila dilepasi. Disuap fix navigasi oleh `NavigationController`.
class ReportAlertsController extends Notifier<ReportAlertsState> {
  /// Soalan dilepaskan sendiri selepas ini jika pemandu tidak menjawab (jangan sekat skrin).
  static const askTimeout = Duration(seconds: 12);

  ReportAlertTracker _tracker = ReportAlertTracker();
  Timer? _askTimer;

  @override
  ReportAlertsState build() {
    ref.onDispose(() => _askTimer?.cancel());
    return const ReportAlertsState();
  }

  /// Memproses satu fix; memulangkan ayat suara untuk laporan baharu di hadapan. Kosong jika amaran
  /// dimatikan dalam tetapan.
  List<Announcement> onFix(LocationFix fix, VoiceLanguage language) {
    if (!ref.read(navigationSettingsProvider).reportAlerts) return const [];
    final events = _tracker.update(
      ref.read(reportsControllerProvider),
      fix.point,
      headingDegrees: fix.headingDegrees?.toDouble(),
      now: ref.read(reportsClockProvider)(),
    );
    if (events.isEmpty) return const [];

    if (events.ask.isNotEmpty && state.ask == null) {
      state = ReportAlertsState(ask: events.ask.first.report);
      _askTimer?.cancel();
      _askTimer = Timer(askTimeout, () {
        if (ref.mounted) state = const ReportAlertsState();
      });
    }

    final text = InstructionText(language);
    return [
      for (final a in events.announce)
        Announcement(
          kind: AnnouncementKind.report,
          text: text.reportAhead(a.report.type, a.distanceM),
          chime: ChimeKind.early,
        ),
    ];
  }

  /// Jawapan pemandu. [confirm] null = ditutup tanpa menjawab (tiada undi).
  Future<void> answer({required bool? confirm}) async {
    final report = state.ask;
    _askTimer?.cancel();
    state = const ReportAlertsState();
    if (report == null || confirm == null) return;
    await ref
        .read(reportsControllerProvider.notifier)
        .vote(report.id, confirm: confirm);
  }

  /// Perjalanan baharu atau tamat: lupakan laporan yang telah diumumkan/ditanya.
  void reset() {
    _tracker = ReportAlertTracker();
    _askTimer?.cancel();
    if (state.ask != null) state = const ReportAlertsState();
  }
}

final reportAlertsProvider =
    NotifierProvider<ReportAlertsController, ReportAlertsState>(
      ReportAlertsController.new,
    );
