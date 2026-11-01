import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AiMapRequestKind {
  /// Tutup halaman AI dan tunjuk pratonton laluan pada peta.
  showRoute,

  /// Tutup halaman AI dan mula navigasi pada laluan terpilih.
  startNavigation,
}

@immutable
class AiMapRequest {
  const AiMapRequest(this.kind, this.id);

  final AiMapRequestKind kind;

  /// Unik setiap permintaan supaya permintaan sama berturut-turut tetap dikesan.
  final int id;
}

/// Jambatan AI → peta. Halaman AI tidak boleh memulakan navigasi sendiri (perlu kebenaran lokasi dan
/// konteks skrin peta), jadi ia meminta; skrin peta mendengar, menutup halaman AI dan bertindak.
class AiMapRequestController extends Notifier<AiMapRequest?> {
  int _next = 0;

  @override
  AiMapRequest? build() => null;

  void showRoute() => state = AiMapRequest(AiMapRequestKind.showRoute, ++_next);

  void startNavigation() =>
      state = AiMapRequest(AiMapRequestKind.startNavigation, ++_next);
}

final aiMapRequestProvider =
    NotifierProvider<AiMapRequestController, AiMapRequest?>(
      AiMapRequestController.new,
    );
