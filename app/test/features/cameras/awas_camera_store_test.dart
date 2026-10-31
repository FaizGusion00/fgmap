import 'package:fgmap/features/cameras/data/awas_camera_store.dart';
import 'package:fgmap/features/cameras/domain/speed_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aset awas_my.json dimuat dan dihuraikan', () async {
    final store = AwasCameraStore();
    final cams = await store.load();
    expect(cams, isNotEmpty);
    expect(cams.every((c) => c.source == SpeedCameraSource.jpjAwas), isTrue);
    expect(cams.every((c) => c.id.isNotEmpty && c.name.isNotEmpty), isTrue);
  });

  test('id unik dan koordinat berada dalam Malaysia', () async {
    final cams = await AwasCameraStore().load();
    expect(cams.map((c) => c.id).toSet().length, cams.length);
    for (final c in cams) {
      expect(c.point.lat, inInclusiveRange(0.8, 7.5), reason: c.id);
      expect(c.point.lng, inInclusiveRange(99.0, 119.5), reason: c.id);
    }
  });

  test('load kali kedua memulangkan cache yang sama', () async {
    final store = AwasCameraStore();
    final a = await store.load();
    final b = await store.load();
    expect(identical(a, b), isTrue);
  });
}
