import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';

/// Masjid atau surau.
enum MasjidType { masjid, surau }

/// Satu tempat dalam senarai rasmi JAKIM (data.gov.my, CC BY). [point] hanya ada apabila nama
/// sepadan dengan tempat yang sama dalam OpenStreetMap; selebihnya dicari melalui alamat apabila
/// dipilih (lihat `tools/jakim/build_jakim.py`).
class MasjidEntry {
  MasjidEntry({
    required this.type,
    required this.name,
    required this.state,
    this.address,
    this.postcode,
    this.district,
    this.phone,
    this.point,
  }) : searchKey = foldMasjidText(
         [
           name,
           address,
           postcode,
           district,
           state,
         ].whereType<String>().join(' '),
       ),
       compactKey = foldMasjidText(name).replaceAll(' ', '');

  final MasjidType type;
  final String name;
  final String? address;
  final String? postcode;
  final String? district;
  final String state;
  final String? phone;
  final GeoPoint? point;

  /// Kunci carian (huruf kecil, tanpa tanda baca, singkatan dikembangkan). Dikira semasa dihurai
  /// (di isolat), bukan pada ketikan pertama di benang UI.
  final String searchKey;

  /// Nama tanpa jarak: "Assyakirin" sepadan "As-Syakirin", "Alfalah" sepadan "Al-Falah".
  final String compactKey;

  /// Pertanyaan geokod apabila tiada koordinat: nama dahulu (paling tepat), kemudian kawasan.
  List<String> get geocodeQueries => [
    [name, district, state].whereType<String>().join(', '),
    if (address != null) [address, state].join(', '),
    [postcode, district, state].whereType<String>().join(' '),
  ];

  static MasjidEntry? fromRow(List<dynamic> r) {
    if (r.length < 9) return null;
    final lat = r[7], lng = r[8];
    return MasjidEntry(
      type: r[0] == 's' ? MasjidType.surau : MasjidType.masjid,
      name: r[1] as String,
      address: r[2] as String?,
      postcode: r[3] as String?,
      district: r[4] as String?,
      state: r[5] as String,
      phone: r[6] as String?,
      point: lat is num && lng is num
          ? GeoPoint(lat.toDouble(), lng.toDouble())
          : null,
    );
  }
}

const _expand = {
  'kg': 'kampung',
  'kpg': 'kampung',
  'tmn': 'taman',
  'bdr': 'bandar',
  'jln': 'jalan',
  'sg': 'sungai',
  'bt': 'batu',
  'bkt': 'bukit',
  'tg': 'tanjung',
  'lrg': 'lorong',
  'ptg': 'permatang',
  'pdg': 'padang',
  'kampong': 'kampung',
  'pt': 'parit',
  'mosque': 'masjid',
  'mosques': 'masjid',
};

/// Teks untuk dipadankan: huruf kecil, tanda baca dibuang, singkatan biasa dikembangkan.
String foldMasjidText(String s) {
  final words = s
      .toLowerCase()
      // Termasuk petikan pintar iOS ("Ma’bud").
      .replaceAll(RegExp("['’‘`´]"), '')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => _expand[w] ?? w);
  return ' ${words.join(' ')} ';
}

/// Penapis senarai.
@immutable
class MasjidQuery {
  const MasjidQuery({this.text = '', this.state, this.district, this.type});

  final String text;
  final String? state;
  final String? district;

  /// Null = semua.
  final MasjidType? type;

  MasjidQuery copyWith({
    String? text,
    String? state,
    String? district,
    MasjidType? type,
    bool clearState = false,
    bool clearDistrict = false,
    bool clearType = false,
  }) => MasjidQuery(
    text: text ?? this.text,
    state: clearState ? null : (state ?? this.state),
    district: clearState || clearDistrict ? null : (district ?? this.district),
    type: clearType ? null : (type ?? this.type),
  );

  @override
  bool operator ==(Object other) =>
      other is MasjidQuery &&
      other.text == text &&
      other.state == state &&
      other.district == district &&
      other.type == type;

  @override
  int get hashCode => Object.hash(text, state, district, type);
}

/// Semua tempat, dimuat sekali daripada aset (dinyahmampat dan dihurai di isolat lain).
class MasjidDirectory {
  MasjidDirectory(this.entries)
    : states = (entries.map((e) => e.state).toSet().toList()..sort()),
      _areaCentres = _centres(entries);

  final List<MasjidEntry> entries;
  final List<String> states;

  /// Purata koordinat tempat berkoordinat bagi setiap daerah (kemudian negeri): anggaran kedudukan
  /// tempat tanpa koordinat supaya susunan "terdekat" tidak meletakkan 93% senarai di hujung.
  final Map<String, GeoPoint> _areaCentres;
  final Map<String, List<String>> _districts = {};

  static Map<String, GeoPoint> _centres(List<MasjidEntry> entries) {
    final sum = <String, (double, double, int)>{};
    void add(String key, GeoPoint p) {
      final (a, b, n) = sum[key] ?? (0.0, 0.0, 0);
      sum[key] = (a + p.lat, b + p.lng, n + 1);
    }

    for (final e in entries) {
      final p = e.point;
      if (p == null) continue;
      if (e.district != null) add('${e.state}|${e.district}', p);
    }
    return {
      for (final MapEntry(:key, value: (a, b, n)) in sum.entries)
        if (n >= 2) key: GeoPoint(a / n, b / n),
    };
  }

  GeoPoint? _approxPoint(MasjidEntry e) =>
      e.point ??
      (e.district == null ? null : _areaCentres['${e.state}|${e.district}']);

  static const asset = 'assets/jakim/masjid_surau.json.gz';

  static Future<MasjidDirectory> load() async {
    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    final rows = await Isolate.run(() => decodeMasjidRows(bytes));
    return MasjidDirectory(rows);
  }

  List<String> districtsOf(String state) => _districts[state] ??=
      (entries
          .where((e) => e.state == state && e.district != null)
          .map((e) => e.district!)
          .toSet()
          .toList()
        ..sort());

  /// Tempat yang sepadan. Dengan [near], disusun ikut jarak: koordinat tepat, atau pusat daerah
  /// (anggaran) bagi yang tiada; yang langsung tiada anggaran di hujung. Tanpa [near]: ikut nama.
  List<MasjidEntry> query(MasjidQuery q, {GeoPoint? near}) {
    final folded = foldMasjidText(q.text).trim();
    final words = folded.split(' ').where((w) => w.isNotEmpty).toList();
    final compact = folded.replaceAll(' ', '');
    bool matches(MasjidEntry e) =>
        words.every((w) => e.searchKey.contains(' $w')) ||
        (compact.length >= 4 && e.compactKey.contains(compact));
    final out = <MasjidEntry>[
      for (final e in entries)
        if ((q.type == null || e.type == q.type) &&
            (q.state == null || e.state == q.state) &&
            (q.district == null || e.district == q.district) &&
            (words.isEmpty || matches(e)))
          e,
    ];
    if (near == null) return out;
    final ranked = <(double, MasjidEntry)>[];
    final rest = <MasjidEntry>[];
    for (final e in out) {
      final p = _approxPoint(e);
      if (p == null) {
        rest.add(e);
      } else {
        ranked.add((distanceMeters(near, p), e));
      }
    }
    // Sama jarak (tempat sedaerah tanpa koordinat): yang berkoordinat tepat dahulu.
    ranked.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      return (a.$2.point == null ? 1 : 0) - (b.$2.point == null ? 1 : 0);
    });
    return [for (final (_, e) in ranked) e, ...rest];
  }
}

/// Menghurai aset (gzip JSON padat). Fungsi tulen untuk isolat dan ujian.
List<MasjidEntry> decodeMasjidRows(Uint8List gz) {
  final rows = jsonDecode(utf8.decode(gzip.decode(gz))) as List<dynamic>;
  final out = <MasjidEntry>[];
  for (final r in rows) {
    final e = r is List ? MasjidEntry.fromRow(r) : null;
    if (e != null) out.add(e);
  }
  return out;
}

/// Dimuat sekali dan disimpan selepas berjaya. Jika gagal, ia dibuang apabila halaman ditutup supaya
/// membuka semula benar-benar mencuba lagi (bukan ralat tersimpan sehingga app dimulakan semula).
final masjidDirectoryProvider = FutureProvider.autoDispose<MasjidDirectory>((
  ref,
) async {
  final dir = await MasjidDirectory.load();
  ref.keepAlive();
  return dir;
});
