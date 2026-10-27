import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import '../../../core/utils/log.dart';

/// Pembekal masa; di-override dalam ujian supaya luput boleh diuji tanpa menunggu.
final reportsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Lokasi fail simpanan, disediakan oleh bootstrap (main.dart) dan di-override dalam ujian.
final reportsRepositoryProvider = Provider<ReportsRepository>(
  // Lalai: ingatan sahaja. main.dart menggantikannya dengan simpanan fail pada peranti.
  (ref) => LocalReportsRepository(null),
);

enum CreateReportResult {
  /// Laporan baharu dicipta.
  created,

  /// Laporan jenis sama sudah ada berdekatan; ia disahkan.
  confirmedExisting,

  /// Tiada kedudukan GPS yang boleh digunakan: laporan mesti dibuat dari lokasi sebenar (Bahagian 9).
  noLocation,
}

/// Laporan aktif. Memuatkan daripada simpanan dan membuang yang luput secara berkala.
class ReportsController extends Notifier<List<Report>> {
  Timer? _purgeTimer;

  @override
  List<Report> build() {
    ref.onDispose(() => _purgeTimer?.cancel());
    // Luput berjalan walaupun tiada interaksi: laporan yang luput hilang dari peta tanpa menunggu tindakan pengguna.
    _purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    Future.microtask(refresh);
    return const [];
  }

  DateTime get _now => ref.read(reportsClockProvider)();

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final repo = ref.read(reportsRepositoryProvider);
    try {
      await repo.purgeExpired(_now);
      final active = await repo.active(_now);
      if (ref.mounted) state = active;
    } on Object catch (e) {
      logDiag('Laporan: gagal memuatkan ($e)');
    }
  }

  /// Mencipta laporan di kedudukan semasa pengguna. Tidak pernah menerima lokasi yang ditaip.
  Future<CreateReportResult> report(ReportType type) async {
    final fix = await ref.read(locationServiceProvider).currentFix();
    if (fix == null) return CreateReportResult.noLocation;
    final repo = ref.read(reportsRepositoryProvider);
    final outcome = await repo.create(type, fix.point, _now);
    await refresh();
    return outcome.isNew
        ? CreateReportResult.created
        : CreateReportResult.confirmedExisting;
  }

  /// Memadam semua laporan pada peranti ini.
  Future<void> clear() async {
    await ref.read(reportsRepositoryProvider).clear();
    await refresh();
  }

  /// "Masih ada?" Ya/Tiada.
  Future<void> vote(String id, {required bool confirm}) async {
    await ref
        .read(reportsRepositoryProvider)
        .vote(id, confirm: confirm, now: _now);
    await refresh();
  }
}

final reportsControllerProvider =
    NotifierProvider<ReportsController, List<Report>>(ReportsController.new);
