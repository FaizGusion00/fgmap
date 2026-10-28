import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pelari macOS CI menukar anti-alias fon sedikit antara imej (biasanya di bawah 0.5%).
/// Susun atur, teks, atau warna yang benar-benar berubah masih gagal.
const double _goldenTolerance = 0.005;

Future<void> testExecutable(Future<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator && !autoUpdateGoldenFiles) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('${current.basedir}golden_test.dart'),
      precisionTolerance: _goldenTolerance,
    );
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         precisionTolerance >= 0 && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
