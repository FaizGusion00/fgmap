/// Berat penalti (pecahan masa tambahan) bagi setiap kelas jalan OSM Valhalla: seberapa buruk sejauh
/// satu kilometer jalan itu berbanding jalan utama, untuk pemandu di Malaysia. Jalan utama (lebuh
/// raya, trunk, primary, susur) = 0. Jalan kampung biasanya tertiari/tidak dikelaskan/kediaman;
/// nombor Laluan Negeri sempit dikelaskan secondary dan diberi penalti kecil.
const roadClassPenalty = <String, double>{
  'secondary': 0.06,
  'tertiary': 0.30,
  'unclassified': 0.40,
  'residential': 0.50,
  'service_other': 0.80,
};

/// Penalti ([RouteOption.roadPenalty]) daripada jarak (meter) setiap kelas jalan. Pecahan jarak dengan
/// kelas yang dikenali sahaja dinilai; jumlah 0 menghasilkan 0. Nilai dihadkan 0.6 supaya satu kelas
/// buruk tidak membatalkan semua pertimbangan lain.
double roadPenaltyFromClasses(Map<String, double> metersByClass) {
  final total = metersByClass.values.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return 0;
  var penalty = 0.0;
  for (final e in metersByClass.entries) {
    penalty += (e.value / total) * (roadClassPenalty[e.key] ?? 0);
  }
  return penalty.clamp(0.0, 0.6);
}
