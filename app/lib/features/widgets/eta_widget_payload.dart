import 'package:flutter/foundation.dart';

/// Kunci storan widget (home_widget). Mesti sama dengan `EtaWidgetProvider.kt` dan stub iOS.
abstract final class EtaWidgetKeys {
  static const homeLabel = 'eta_home_label';
  static const homeValue = 'eta_home_value';
  static const homeSet = 'eta_home_set';
  static const workLabel = 'eta_work_label';
  static const workValue = 'eta_work_value';
  static const workSet = 'eta_work_set';
  static const updatedAt = 'eta_updated_at';

  static const all = [
    homeLabel,
    homeValue,
    homeSet,
    workLabel,
    workValue,
    workSet,
    updatedAt,
  ];
}

/// Satu baris widget: Rumah atau Kerja.
@immutable
class EtaWidgetRow {
  const EtaWidgetRow({
    required this.label,
    required this.value,
    this.isSet = false,
  });

  /// Tempat belum ditetapkan: [value] ialah ajakan (CTA) untuk membuka app.
  const EtaWidgetRow.unset({required this.label, required String cta})
    : value = cta,
      isSet = false;

  final String label;

  /// ETA (cth. `12 min`, `~1 j 5 min`) atau CTA jika [isSet] palsu.
  final String value;
  final bool isSet;

  @override
  bool operator ==(Object other) =>
      other is EtaWidgetRow &&
      other.label == label &&
      other.value == value &&
      other.isSet == isSet;

  @override
  int get hashCode => Object.hash(label, value, isSet);
}

/// Muatan widget skrin utama: ETA ke Rumah dan Kerja. Hanya rentetan/bool ringkas supaya Kotlin dan
/// Swift membacanya tanpa JSON.
@immutable
class EtaWidgetPayload {
  const EtaWidgetPayload({
    required this.home,
    required this.work,
    required this.updatedAt,
  });

  final EtaWidgetRow home;
  final EtaWidgetRow work;
  final DateTime updatedAt;

  /// Kedua-duanya belum ditetapkan.
  bool get isEmpty => !home.isSet && !work.isSet;

  Map<String, Object> toMap() => {
    EtaWidgetKeys.homeLabel: home.label,
    EtaWidgetKeys.homeValue: home.value,
    EtaWidgetKeys.homeSet: home.isSet,
    EtaWidgetKeys.workLabel: work.label,
    EtaWidgetKeys.workValue: work.value,
    EtaWidgetKeys.workSet: work.isSet,
    EtaWidgetKeys.updatedAt: updatedAt.millisecondsSinceEpoch,
  };

  /// Pulihkan daripada [toMap]; null jika tidak lengkap.
  static EtaWidgetPayload? fromMap(Map<String, Object?> map) {
    final homeLabel = map[EtaWidgetKeys.homeLabel];
    final homeValue = map[EtaWidgetKeys.homeValue];
    final workLabel = map[EtaWidgetKeys.workLabel];
    final workValue = map[EtaWidgetKeys.workValue];
    final updated = map[EtaWidgetKeys.updatedAt];
    if (homeLabel is! String ||
        homeValue is! String ||
        workLabel is! String ||
        workValue is! String ||
        updated is! int) {
      return null;
    }
    return EtaWidgetPayload(
      home: EtaWidgetRow(
        label: homeLabel,
        value: homeValue,
        isSet: map[EtaWidgetKeys.homeSet] == true,
      ),
      work: EtaWidgetRow(
        label: workLabel,
        value: workValue,
        isSet: map[EtaWidgetKeys.workSet] == true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EtaWidgetPayload &&
      other.home == home &&
      other.work == work &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(home, work, updatedAt);
}

/// Teks widget mengikut bahasa peranti (BM jika `ms`, selainnya Inggeris).
@immutable
class EtaWidgetText {
  const EtaWidgetText({required this.malay});

  factory EtaWidgetText.forLanguage(String languageCode) =>
      EtaWidgetText(malay: languageCode == 'ms');

  final bool malay;

  String get homeLabel => malay ? 'Rumah' : 'Home';
  String get workLabel => malay ? 'Kerja' : 'Work';
  String get here => malay ? 'Sudah sampai' : 'You\'re here';
  String get cta => malay ? 'Tetapkan dalam FGMaps' : 'Set in FGMaps';

  /// Format tempoh. `approximate` untuk anggaran jarak (awalan `~`).
  String duration(int seconds, {bool approximate = false}) {
    final minutes = (seconds / 60).round().clamp(1, 99 * 60).toInt();
    final prefix = approximate ? '~' : '';
    if (minutes < 60) return '$prefix$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hour = malay ? 'j' : 'h';
    return m == 0 ? '$prefix$h $hour' : '$prefix$h $hour $m min';
  }
}
