import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Pek peta palsu (isi rawak, bukan tar sebenar: pemasang tidak menghurai tar) beserta manifest sahnya.
class FakePack {
  FakePack._(this.raw, this.gz, this.version);

  factory FakePack.create({
    int rawSize = 300000,
    String version = '20261026',
    int seed = 7,
  }) {
    final rnd = _Lcg(seed);
    // Separuh berulang (termampat) dan separuh rawak, supaya pek termampat bukan terlalu kecil.
    final raw = Uint8List(rawSize);
    for (var i = 0; i < rawSize; i++) {
      raw[i] = i.isEven ? (i ~/ 2) & 0xff : rnd.next();
    }
    return FakePack._(raw, Uint8List.fromList(gzip.encode(raw)), version);
  }

  final Uint8List raw;
  final Uint8List gz;
  final String version;

  String get file => 'malaysia-$version.tar.gz';

  Map<String, Object?> manifestJson({String valhalla = '3.9.1'}) => {
    'schema': 1,
    'region': 'malaysia',
    'version': version,
    'valhalla': valhalla,
    'file': file,
    'sizeBytes': gz.length,
    'sha256': sha256.convert(gz).toString(),
    'extractedSizeBytes': raw.length,
    'extractedSha256': sha256.convert(raw).toString(),
  };
}

class _Lcg {
  _Lcg(this._s);
  int _s;
  int next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return (_s >> 16) & 0xff;
  }
}

/// Pelayan HTTP setempat yang menyerupai hos pek (GitHub Releases/R2), dengan tingkah laku boleh
/// dikawal untuk menguji kegagalan.
class PackServer {
  PackServer._(this._server, this.pack);

  static Future<PackServer> start(FakePack pack) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = PackServer._(server, pack);
    server.listen(s._handle);
    return s;
  }

  final HttpServer _server;
  FakePack pack;

  /// Pelayan mengabaikan Range dan sentiasa menghantar 200 dari awal.
  bool ignoreRange = false;

  /// Putuskan sambungan selepas sekian bait pada permintaan pek seterusnya (sekali sahaja).
  int? dropAfterBytes;

  /// Tulis ganti badan pek (cth. rosak) tanpa mengubah manifest.
  Uint8List? overrideBody;

  /// Manifest yang dipulangkan; null = jana daripada [pack].
  Map<String, Object?>? manifestOverride;

  /// Badan manifest mentah (cth. bukan JSON); mengatasi [manifestOverride].
  String? manifestRaw;
  int? packStatus;
  int? manifestStatus;
  Duration chunkDelay = Duration.zero;

  final List<String?> rangeHeaders = [];
  int packRequests = 0;
  int manifestRequests = 0;

  String get manifestUrl => 'http://127.0.0.1:${_server.port}/manifest.json';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      if (req.uri.path == '/manifest.json') {
        manifestRequests++;
        if (manifestStatus != null) {
          res.statusCode = manifestStatus!;
          await res.close();
          return;
        }
        res.headers.contentType = ContentType.json;
        res.write(
          manifestRaw ?? jsonEncode(manifestOverride ?? pack.manifestJson()),
        );
        await res.close();
        return;
      }
      if (req.uri.path == '/${pack.file}') {
        packRequests++;
        rangeHeaders.add(req.headers.value(HttpHeaders.rangeHeader));
        if (packStatus != null) {
          res.statusCode = packStatus!;
          await res.close();
          return;
        }
        final body = overrideBody ?? pack.gz;
        var start = 0;
        final range = req.headers.value(HttpHeaders.rangeHeader);
        if (!ignoreRange && range != null) {
          final m = RegExp(r'bytes=(\d+)-').firstMatch(range);
          if (m != null) start = int.parse(m.group(1)!);
        }
        if (start > 0) {
          res.statusCode = HttpStatus.partialContent;
          res.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-${body.length - 1}/${body.length}',
          );
        }
        final slice = body.sublist(start);
        res.contentLength = slice.length;

        final drop = dropAfterBytes;
        dropAfterBytes = null;
        const chunk = 16 * 1024;
        var sent = 0;
        for (var i = 0; i < slice.length; i += chunk) {
          final end = (i + chunk).clamp(0, slice.length);
          if (drop != null && sent >= drop) {
            // Menutup respons dengan bait kurang daripada Content-Length: dart:io memusnahkan soket,
            // dan klien melihat sambungan terputus serta-merta (seperti pelayan sebenar yang mati).
            try {
              await res.close();
            } on Object {
              // dijangka: "Content size below specified contentLength"
            }
            return;
          }
          res.add(slice.sublist(i, end));
          sent += end - i;
          await res.flush();
          if (chunkDelay > Duration.zero) {
            await Future<void>.delayed(chunkDelay);
          }
        }
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.notFound;
      await res.close();
    } on Object {
      // Klien memutuskan sambungan (cth. dibatalkan): tidak mengapa.
    }
  }
}
