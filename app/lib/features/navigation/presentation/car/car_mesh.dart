import 'dart:math' as math;
import 'dart:typed_data';

/// Bahan permukaan kereta; warna sebenar diberi oleh [CarPalette] semasa melukis.
enum CarMaterial {
  /// Badan (sisi dan bonet/bonet belakang).
  body,

  /// Permukaan atas yang menerima cahaya langit (bumbung, bonet): sedikit lebih cerah.
  bodyTop,
  glass,
  tire,
  headlight,
  taillight,
}

/// Satu muka (poligon cembung) pada mesh kereta.
class CarFace {
  const CarFace({
    required this.vertices,
    required this.nx,
    required this.ny,
    required this.nz,
    required this.material,
    required this.order,
  });

  /// Indeks verteks dalam [CarMesh.positions] (satu verteks = tiga nombor), tertib lawan jam
  /// apabila dilihat dari luar.
  final List<int> vertices;

  /// Normal unit menghala ke luar, dalam ruang kereta.
  final double nx, ny, nz;
  final CarMaterial material;

  /// Kumpulan lukisan: kumpulan lebih rendah dilukis dahulu. Cukup untuk kereta kerana setiap kumpulan
  /// cembung atau terletak di atas kumpulan sebelumnya.
  final int order;
}

/// Model 3D kereta berpoligon rendah. Ruang kereta, dalam meter: x ke kanan, y ke hadapan (hidung),
/// z ke atas; asalan di tengah tapak. Dibina sekali dan dikongsi.
class CarMesh {
  CarMesh._(this.positions, this.faces, this.footprint);

  /// x, y, z bagi setiap verteks, berselang-seli.
  final Float64List positions;
  final List<CarFace> faces;

  /// Garisan tapak (x, y) berselang-seli, tertib lawan jam, untuk bayang di atas jalan.
  final Float64List footprint;

  int get vertexCount => positions.length ~/ 3;

  static const length = 4.5;
  static const width = 1.86;
  static const height = 1.52;

  static final CarMesh standard = _build();

  static CarMesh _build() {
    final b = _Builder();

    final plan = _squircle(
      halfW: 0.93,
      yBack: -2.25,
      yFront: 2.25,
      p: 4.2,
      frontTaper: 0.16,
      backTaper: 0.08,
      n: 40,
    );
    // Garis luar pada ketinggian lampu (badan sudah sedikit menyempit ke atas).
    final lampPlan = _scale(plan, 0.955);

    // Roda dahulu: badan menutup bahagian dalamnya.
    for (final sx in const [-1.0, 1.0]) {
      for (final y in const [1.38, -1.38]) {
        b.prism(
          _squircle(
            halfW: 0.13,
            yBack: y - 0.34,
            yFront: y + 0.34,
            p: 4,
            n: 16,
          ),
          dx: sx * 0.86,
          z0: 0,
          z1: 0.6,
          side: CarMaterial.tire,
          top: CarMaterial.tire,
          order: 0,
        );
      }
    }

    // Badan bawah: sisi sedikit condong ke dalam (bahu).
    b.loft(
      _scale(plan, 0.97),
      0.22,
      _scale(plan, 0.95),
      0.84,
      side: CarMaterial.body,
      top: CarMaterial.body,
      order: 1,
    );
    // Bahu / bonet: bibir atas yang membulat, permukaan atas lebih cerah.
    b.loft(
      _scale(plan, 0.95),
      0.84,
      _scale(plan, 0.9),
      0.98,
      side: CarMaterial.body,
      top: CarMaterial.bodyTop,
      order: 2,
    );

    // Kabin: sisi hampir menegak, cermin depan dan belakang curam. Dari atas hanya cermin depan/belakang
    // kelihatan sebagai jalur gelap pada bumbung, seperti kereta sebenar.
    b.loft(
      _squircle(
        halfW: 0.78,
        yBack: -1.32,
        yFront: 0.86,
        p: 3.6,
        frontTaper: 0.1,
        backTaper: 0.1,
        n: 40,
      ),
      0.98,
      _squircle(
        halfW: 0.73,
        yBack: -0.86,
        yFront: 0.24,
        p: 3.6,
        frontTaper: 0.1,
        backTaper: 0.1,
        n: 40,
      ),
      CarMesh.height,
      side: CarMaterial.glass,
      top: CarMaterial.bodyTop,
      order: 3,
    );

    // Cermin sisi.
    for (final sx in const [-1.0, 1.0]) {
      b.prism(
        _rect(halfW: 0.09, yBack: 0.52, yFront: 0.74),
        dx: sx * 0.9,
        z0: 0.96,
        z1: 1.08,
        side: CarMaterial.body,
        top: CarMaterial.bodyTop,
        order: 4,
      );
    }

    // Lampu depan dan belakang: dilekatkan pada tepi badan di ketinggian lampu, bukan terapung.
    for (final sx in const [-1.0, 1.0]) {
      final hx = sx * 0.56;
      final front = _edgeY(lampPlan, hx.abs(), front: true);
      b.prism(
        _rect(halfW: 0.2, yBack: front - 0.13, yFront: front + 0.01),
        dx: hx,
        z0: 0.56,
        z1: 0.72,
        side: CarMaterial.headlight,
        top: CarMaterial.headlight,
        order: 5,
      );
      final tx = sx * 0.5;
      final back = _edgeY(lampPlan, tx.abs() + 0.05, front: false);
      b.prism(
        _rect(halfW: 0.27, yBack: back - 0.01, yFront: back + 0.12),
        dx: tx,
        z0: 0.62,
        z1: 0.78,
        side: CarMaterial.taillight,
        top: CarMaterial.taillight,
        order: 5,
      );
    }

    final foot = Float64List(plan.length * 2);
    for (var i = 0; i < plan.length; i++) {
      foot[i * 2] = plan[i].$1 * 1.02;
      foot[i * 2 + 1] = plan[i].$2 * 1.02;
    }
    return CarMesh._(b.positions(), b.faces, foot);
  }
}

/// y terjauh (hadapan atau belakang) garis luar [outline] pada x tertentu.
double _edgeY(List<(double, double)> outline, double x, {required bool front}) {
  var best = front ? -double.infinity : double.infinity;
  for (var i = 0; i < outline.length; i++) {
    final a = outline[i];
    final c = outline[(i + 1) % outline.length];
    final lo = math.min(a.$1, c.$1), hi = math.max(a.$1, c.$1);
    if (x < lo || x > hi || hi - lo < 1e-9) continue;
    final t = (x - a.$1) / (c.$1 - a.$1);
    final y = a.$2 + (c.$2 - a.$2) * t;
    best = front ? math.max(best, y) : math.min(best, y);
  }
  return best.isFinite ? best : 0;
}

typedef _P2 = (double, double);

List<_P2> _scale(List<_P2> pts, double s) => [
  for (final p in pts) (p.$1 * s, p.$2 * s),
];

List<_P2> _rect({
  required double halfW,
  required double yBack,
  required double yFront,
}) => [(halfW, yBack), (halfW, yFront), (-halfW, yFront), (-halfW, yBack)];

double _signedPow(double v, double e) =>
    v == 0 ? 0 : v.sign * math.pow(v.abs(), e).toDouble();

/// Segi empat bulat (superelips) lawan jam; [n] gandaan 4. Hidung ([frontTaper]) dan ekor
/// ([backTaper]) boleh disempitkan.
List<_P2> _squircle({
  required double halfW,
  required double yBack,
  required double yFront,
  required double p,
  int n = 32,
  double frontTaper = 0,
  double backTaper = 0,
}) {
  assert(n % 4 == 0);
  final mid = (yFront + yBack) / 2;
  final half = (yFront - yBack) / 2;
  final e = 2 / p;
  final out = <_P2>[];
  for (var i = 0; i < n; i++) {
    final t = 2 * math.pi * i / n;
    final c = math.cos(t);
    final s = math.sin(t);
    final u = _signedPow(s, e);
    var x = halfW * _signedPow(c, e);
    x *= u > 0 ? 1 - frontTaper * u * u : 1 - backTaper * u * u;
    out.add((x, mid + half * u));
  }
  return out;
}

class _Builder {
  final List<double> _pos = [];
  final List<CarFace> faces = [];

  Float64List positions() => Float64List.fromList(_pos);

  int _vertex(double x, double y, double z) {
    _pos
      ..add(x)
      ..add(y)
      ..add(z);
    return _pos.length ~/ 3 - 1;
  }

  void prism(
    List<_P2> outline, {
    double dx = 0,
    required double z0,
    required double z1,
    required CarMaterial side,
    required CarMaterial top,
    required int order,
  }) {
    final shifted = [for (final p in outline) (p.$1 + dx, p.$2)];
    loft(shifted, z0, shifted, z1, side: side, top: top, order: order);
  }

  /// Menyambungkan dua gelung titik sepadan (bawah [lo] pada [z0], atas [hi] pada [z1]) dengan muka
  /// sisi, dan menutup atas. Bawah dibiarkan terbuka kerana tidak pernah kelihatan.
  void loft(
    List<_P2> lo,
    double z0,
    List<_P2> hi,
    double z1, {
    required CarMaterial side,
    required CarMaterial top,
    required int order,
  }) {
    assert(lo.length == hi.length);
    final n = lo.length;
    final bottom = [for (final p in lo) _vertex(p.$1, p.$2, z0)];
    final upper = [for (final p in hi) _vertex(p.$1, p.$2, z1)];

    var cx = 0.0, cy = 0.0, cz = (z0 + z1) / 2;
    for (final p in lo) {
      cx += p.$1;
      cy += p.$2;
    }
    cx /= n;
    cy /= n;

    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      _addFace(
        [bottom[i], bottom[j], upper[j], upper[i]],
        side,
        order,
        outsideFrom: (cx, cy, cz),
      );
    }
    _addFace(
      upper,
      top,
      order,
      outsideFrom: (cx, cy, z0),
      forceNormal: (0, 0, 1),
    );
  }

  void _addFace(
    List<int> idx,
    CarMaterial material,
    int order, {
    required (double, double, double) outsideFrom,
    (double, double, double)? forceNormal,
  }) {
    var vertices = idx;
    double nx, ny, nz;
    if (forceNormal != null) {
      (nx, ny, nz) = forceNormal;
    } else {
      // Normal Newell, dihalakan ke luar daripada pusat bahagian.
      (nx, ny, nz) = _newell(vertices);
      var mx = 0.0, my = 0.0, mz = 0.0;
      for (final v in vertices) {
        mx += _pos[v * 3];
        my += _pos[v * 3 + 1];
        mz += _pos[v * 3 + 2];
      }
      mx /= vertices.length;
      my /= vertices.length;
      mz /= vertices.length;
      final dot =
          nx * (mx - outsideFrom.$1) +
          ny * (my - outsideFrom.$2) +
          nz * (mz - outsideFrom.$3);
      if (dot < 0) {
        vertices = vertices.reversed.toList();
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
    }
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-9) return; // muka merosot (sisi berukuran sifar)
    faces.add(
      CarFace(
        vertices: List.unmodifiable(vertices),
        nx: nx / len,
        ny: ny / len,
        nz: nz / len,
        material: material,
        order: order,
      ),
    );
  }

  (double, double, double) _newell(List<int> v) {
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (var i = 0; i < v.length; i++) {
      final a = v[i] * 3;
      final b = v[(i + 1) % v.length] * 3;
      final ax = _pos[a], ay = _pos[a + 1], az = _pos[a + 2];
      final bx = _pos[b], by = _pos[b + 1], bz = _pos[b + 2];
      nx += (ay - by) * (az + bz);
      ny += (az - bz) * (ax + bx);
      nz += (ax - bx) * (ay + by);
    }
    return (nx, ny, nz);
  }
}
