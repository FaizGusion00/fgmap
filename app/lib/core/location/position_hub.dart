import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Keperluan GPS, disusun dari paling ringan ke paling berat. Mod paling berat yang sedang
/// diminta menentukan tetapan aliran platform.
enum PositionMode { tracking, oneShot, navigation }

/// Satu-satunya langganan GPS platform untuk seluruh app.
///
/// Pemalam Android (geolocator_android) memulangkan semula aliran yang sedang hidup dan
/// MENGABAIKAN tetapan baharu. Tanpa hab ini, pelanggan kedua (cth. memandu bebas, atau
/// `currentFix`) tersangkut pada tetapan pelanggan pertama: memandu bebas tanpa servis latar
/// depan (GPS berhenti bila skrin padam), atau peta terbiar kekal pada GPS gred navigasi
/// (bateri). Hab ini memegang satu langganan dan membukanya semula dengan tetapan yang betul
/// setiap kali mod paling berat berubah.
class PositionHub {
  PositionHub(this._open, this._settingsFor);

  final Stream<Position> Function(LocationSettings settings) _open;
  final LocationSettings Function(PositionMode mode) _settingsFor;

  final List<_Client> _clients = [];
  StreamSubscription<Position>? _platform;
  PositionMode? _mode;

  /// Mod aliran platform yang sedang dibuka (null = GPS tidak didengar).
  @visibleForTesting
  PositionMode? get activeMode => _platform == null ? null : _mode;

  /// Aliran kedudukan untuk [mode]. GPS dibuka apabila didengar dan ditutup apabila pelanggan
  /// terakhir berhenti.
  Stream<Position> stream(PositionMode mode) {
    late final _Client client;
    final controller = StreamController<Position>();
    client = _Client(mode, controller);
    controller
      ..onListen = () {
        _clients.add(client);
        _reconcile();
      }
      ..onCancel = () {
        _clients.remove(client);
        _reconcile();
      };
    return controller.stream;
  }

  void _reconcile() {
    PositionMode? want;
    for (final c in _clients) {
      if (want == null || c.mode.index > want.index) want = c.mode;
    }
    if (want == _mode && (_platform != null) == (want != null)) return;
    final old = _platform;
    _platform = null;
    _mode = want;
    // Batal dahulu (serentak) supaya pemalam melupakan aliran lama sebelum yang baharu dibuka.
    if (old != null) unawaited(old.cancel());
    if (want == null) return;
    try {
      _platform = _open(
        _settingsFor(want),
      ).listen(_emit, onError: _fail, onDone: _done);
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _emit(Position position) {
    for (final c in List.of(_clients)) {
      if (!c.controller.isClosed) c.controller.add(position);
    }
  }

  void _fail(Object error, [StackTrace? stack]) {
    for (final c in List.of(_clients)) {
      if (!c.controller.isClosed) c.controller.addError(error, stack);
    }
  }

  void _done() {
    _platform = null;
    _mode = null;
    final clients = List.of(_clients);
    _clients.clear();
    for (final c in clients) {
      unawaited(c.controller.close());
    }
  }
}

class _Client {
  _Client(this.mode, this.controller);

  final PositionMode mode;
  final StreamController<Position> controller;
}
