import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../domain/report.dart';
import '../../../core/utils/log.dart';

/// Simpanan laporan. Antara muka supaya backend kongsi (Firebase/Supabase) boleh menggantikan simpanan
/// tempatan tanpa mengubah UI atau peraturan.
abstract interface class ReportsRepository {
  /// Semua laporan yang masih aktif pada [now].
  Future<List<Report>> active(DateTime now);

  /// Mencipta laporan. Jika laporan jenis sama yang masih aktif sudah ada dalam
  /// [ReportRules.duplicateRadiusM], ia disahkan (hayat dilanjutkan) dan dipulangkan dengan `isNew: false`,
  /// bukan diduakan.
  Future<({Report report, bool isNew})> create(
    ReportType type,
    GeoPoint point,
    DateTime now,
  );

  /// Mengundi. Memulangkan laporan terkini, atau null jika ia telah dibuang (dinafikan) atau tidak wujud.
  Future<Report?> vote(
    String id, {
    required bool confirm,
    required DateTime now,
  });

  /// Membuang laporan yang telah luput; memulangkan bilangan yang dibuang.
  Future<int> purgeExpired(DateTime now);

  /// Memadam semua laporan (Tetapan > Privasi).
  Future<void> clear();
}

/// Simpanan fail JSON pada peranti. Laporan hanya kelihatan kepada pengguna ini. Tanpa fail ([_file]
/// null) laporan hanya disimpan dalam ingatan (lalai untuk ujian dan sebelum bootstrap menyediakan fail).
class LocalReportsRepository implements ReportsRepository {
  LocalReportsRepository(
    this._file, {
    this.denyThreshold = ReportRules.localDenyThreshold,
  });

  final File? _file;
  final int denyThreshold;

  List<Report>? _cache;
  Future<void> _tail = Future.value();
  final math.Random _rnd = math.Random();

  /// Operasi disiri: dua tulis serentak ke fail yang sama akan merosakkannya.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<Report>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final reports = <Report>[];
    final file = _file;
    if (file == null) return _cache = reports;
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final item in decoded) {
            final r = Report.tryFromJson(item);
            if (r != null) reports.add(r);
          }
        }
      }
    } on Object catch (e) {
      // Fail rosak (cth. penulisan terganggu): mulakan kosong, bukan menghalang app.
      logDiag('Laporan: fail rosak diabaikan ($e)');
    }
    return _cache = reports;
  }

  Future<void> _save(List<Report> reports) async {
    _cache = reports;
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    // Tulis ke fail sementara kemudian tukar nama: tidak meninggalkan fail separuh ditulis jika proses mati.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final r in reports) r.toJson()]),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  @override
  Future<List<Report>> active(DateTime now) => _serial(() async {
    return [
      for (final r in await _load())
        if (r.isActive(now)) r,
    ];
  });

  @override
  Future<({Report report, bool isNew})> create(
    ReportType type,
    GeoPoint point,
    DateTime now,
  ) => _serial(() async {
    final all = List<Report>.of(await _load());
    for (var i = 0; i < all.length; i++) {
      final r = all[i];
      if (r.type == type &&
          r.isActive(now) &&
          distanceMeters(r.point, point) <= ReportRules.duplicateRadiusM) {
        final confirmed = _confirmed(r, now);
        all[i] = confirmed;
        await _save(all);
        return (report: confirmed, isNew: false);
      }
    }
    final report = Report(
      id: _newId(now),
      type: type,
      point: point,
      createdAt: now,
      expiresAt: now.add(type.baseLifetime),
    );
    all.add(report);
    await _save(all);
    return (report: report, isNew: true);
  });

  @override
  Future<Report?> vote(
    String id, {
    required bool confirm,
    required DateTime now,
  }) => _serial(() async {
    final all = List<Report>.of(await _load());
    final i = all.indexWhere((r) => r.id == id);
    if (i < 0 || !all[i].isActive(now)) return null;

    if (confirm) {
      all[i] = _confirmed(all[i], now);
      await _save(all);
      return all[i];
    }
    final denied = all[i].copyWith(denies: all[i].denies + 1);
    if (denied.denies >= denyThreshold) {
      all.removeAt(i);
      await _save(all);
      return null;
    }
    all[i] = denied;
    await _save(all);
    return denied;
  });

  @override
  Future<void> clear() => _serial(() async {
    await _save(const []);
  });

  @override
  Future<int> purgeExpired(DateTime now) => _serial(() async {
    final all = await _load();
    final kept = [
      for (final r in all)
        if (r.isActive(now)) r,
    ];
    final removed = all.length - kept.length;
    if (removed > 0) await _save(kept);
    return removed;
  });

  /// Pengesahan melanjutkan hayat sebanyak separuh hayat asas, dihadkan kepada [ReportRules.maxLifetimeFactor]
  /// kali hayat asas dari masa laporan dicipta.
  Report _confirmed(Report r, DateTime now) {
    final extension = Duration(
      milliseconds:
          (r.type.baseLifetime.inMilliseconds *
                  ReportRules.confirmExtensionFraction)
              .round(),
    );
    final cap = r.createdAt.add(
      Duration(
        milliseconds:
            (r.type.baseLifetime.inMilliseconds * ReportRules.maxLifetimeFactor)
                .round(),
      ),
    );
    var next = r.expiresAt.isAfter(now)
        ? r.expiresAt.add(extension)
        : now.add(extension);
    if (next.isAfter(cap)) next = cap;
    return r.copyWith(expiresAt: next, confirms: r.confirms + 1);
  }

  String _newId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}-${_rnd.nextInt(1 << 32).toRadixString(36)}';
}
