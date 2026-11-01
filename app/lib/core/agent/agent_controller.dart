import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/device_tier.dart';
import '../utils/log.dart';
import 'agent_targets.dart';

/// Navigator akar app (GoRouter): ejen kembali ke peta dan membuka halaman tanpa konteks widget.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Peranti sentuhan sintetik ejen: lapisan ejen mengabaikan sentuhan ini (sentuhan pengguna sebenar
/// menghentikan ejen).
const kAgentPointerDevice = 0x46474149; // "FGAI"

/// Kandungan app di bawah lapisan ejen: sentuhan ejen diuji-hit di sini sahaja.
final agentAppKey = GlobalKey(debugLabel: 'agent-app');

enum AgentStepStatus { pending, running, done, failed }

@immutable
class AgentStepView {
  const AgentStepView(this.label, this.status);

  final String label;
  final AgentStepStatus status;

  AgentStepView withStatus(AgentStepStatus s) => AgentStepView(label, s);
}

@immutable
class AgentState {
  const AgentState({
    this.active = false,
    this.title = '',
    this.steps = const [],
    this.pointer,
    this.target,
    this.pressing = false,
  });

  /// Ejen sedang mengawal skrin.
  final bool active;
  final String title;
  final List<AgentStepView> steps;

  /// Kedudukan jari hantu (global), atau null bila disembunyikan.
  final Offset? pointer;

  /// Kawalan yang sedang disorot.
  final Rect? target;

  /// Jari sedang "menekan" (riak).
  final bool pressing;

  AgentState copyWith({
    bool? active,
    String? title,
    List<AgentStepView>? steps,
    Offset? pointer,
    Rect? target,
    bool clearTarget = false,
    bool? pressing,
  }) => AgentState(
    active: active ?? this.active,
    title: title ?? this.title,
    steps: steps ?? this.steps,
    pointer: pointer ?? this.pointer,
    target: clearTarget ? null : (target ?? this.target),
    pressing: pressing ?? this.pressing,
  );
}

/// Hasil satu larian ejen.
@immutable
class AgentOutcome {
  const AgentOutcome(
    this.steps, {
    required this.completed,
    this.stopped = false,
  });

  final List<AgentStepView> steps;

  /// Semua langkah berjaya.
  final bool completed;

  /// Dihentikan oleh pengguna (butang Henti atau menyentuh skrin).
  final bool stopped;
}

/// Satu langkah: label untuk senarai semak dan tindakan yang dijalankan dengan [AgentRunner].
/// Memulangkan false jika langkah tidak dapat dilakukan (cth. butang tidak muncul).
class AgentStep {
  const AgentStep(this.label, this.run);

  final String label;
  final Future<bool> Function(AgentRunner r) run;
}

/// Primitif yang digunakan langkah: tekan, taip, tunggu, tatal, kembali ke peta.
class AgentRunner {
  AgentRunner._(this._ctl);

  final AgentController _ctl;
  static int _nextPointer = 900000;

  bool get cancelled => _ctl._cancelled;

  /// Tempoh jari bergerak ke sasaran (sifar dalam Mod Lite / ujian).
  Duration get _travel => LiteMode.enabled || AgentController.instant
      ? Duration.zero
      : const Duration(milliseconds: 420);

  Future<void> pause(Duration d) async {
    if (AgentController.instant) {
      await Future<void>.delayed(Duration.zero);
      return;
    }
    await Future<void>.delayed(d);
  }

  /// Tunggu sehingga sasaran [id] dipasang dan dibentang (halaman baru dibuka, hasil dimuat).
  Future<bool> waitFor(
    String id, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final end = DateTime.now().add(timeout);
    var spins = 0;
    while (!cancelled) {
      if (AgentTargets.has(id)) return true;
      if (DateTime.now().isAfter(end) || spins > timeout.inMilliseconds ~/ 50) {
        return false;
      }
      spins++;
      // Jeda masa sahaja (bukan `endOfFrame`): bingkai mungkin tidak dijadualkan langsung bila skrin
      // tenang, dan menunggunya akan tergantung.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  /// Tunggu sehingga [id] hilang (lembaran ditutup, halaman bertukar): bukti tindakan berlaku.
  Future<bool> waitGone(
    String id, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!cancelled) {
      if (!AgentTargets.has(id)) return true;
      if (DateTime.now().isAfter(end)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  /// Gerakkan jari ke [id], tunjuk riak tekan, kemudian tekan widget sebenar di situ.
  Future<bool> tap(
    String id, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!await waitFor(id, timeout: timeout) || cancelled) return false;
    await ensureVisible(id);
    var rect = await _settledRect(id);
    // Halaman di atasnya mungkin masih beranimasi keluar (cth. halaman AI ditutup): tunggu sehingga
    // sasaran boleh disentuh sebelum jari bergerak.
    final until = DateTime.now().add(const Duration(milliseconds: 1800));
    while (rect != null &&
        !cancelled &&
        _hitPath(id, rect.center, quiet: true) == null &&
        DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      rect = await _settledRect(id);
    }
    if (rect == null || cancelled) return false;
    _ctl._point(rect);
    await pause(_travel + const Duration(milliseconds: 80));
    // Susun atur mungkin berubah semasa jari bergerak (lembaran naik, hasil dimuat): ikut sasaran.
    for (var i = 0; i < 3 && !cancelled; i++) {
      final now = await _settledRect(id);
      if (now == null) return false;
      if (now == rect) break;
      rect = now;
      _ctl._point(now);
      await pause(_travel);
    }
    if (cancelled) return false;
    _ctl._press(true);
    await pause(const Duration(milliseconds: 140));
    // Jujur: hanya tekan jika titik itu benar-benar mengenai kawalan sasaran (bukan kad status,
    // lembaran lain atau ruang kosong). Jika tidak, langkah gagal dan dilaporkan begitu.
    final path = _hitPath(id, rect!.center);
    if (path != null) _dispatchTap(rect.center, path);
    _ctl._press(false);
    await pause(const Duration(milliseconds: 280));
    return path != null && !cancelled;
  }

  /// Segi empat [id] setelah ia berhenti bergerak (animasi halaman/lembaran selesai).
  Future<Rect?> _settledRect(String id) async {
    var last = AgentTargets.rectOf(id);
    for (var i = 0; i < 40 && last != null && !cancelled; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final now = AgentTargets.rectOf(id);
      if (now == last) return now;
      last = now;
    }
    return last;
  }

  /// Laluan hit pada [p] di dalam kandungan app SAHAJA (di bawah lapisan ejen, jadi kad status, sorotan
  /// dan jari tidak pernah menghalang), atau null jika sentuhan di situ tidak sampai ke sasaran [id]
  /// (cth. dialog lain menutupnya): ejen tidak menekan apa-apa dan langkah dilaporkan gagal.
  static HitTestResult? _hitPath(String id, Offset p, {bool quiet = false}) {
    final app = agentAppKey.currentContext?.findRenderObject();
    final box = AgentTargets.contextOf(id)?.findRenderObject();
    if (app is! RenderBox || !app.attached || box == null) return null;
    final result = BoxHitTestResult();
    result.addWithPaintTransform(
      transform: app.getTransformTo(null),
      position: p,
      hitTest: (r, local) => app.hitTest(r, position: local),
    );
    final reaches = result.path.any((entry) {
      for (
        var o = entry.target is RenderObject
            ? entry.target as RenderObject
            : null;
        o != null;
        o = o.parent
      ) {
        if (identical(o, box)) return true;
      }
      return false;
    });
    if (!reaches) {
      if (!quiet) {
        logDiag('Ejen: sentuhan pada "$id" tidak mengenai sasaran');
      }
      return null;
    }
    // Seperti hitTestInView: GestureBinding menutup/menyapu arena gerak isyarat.
    result.add(HitTestEntry(GestureBinding.instance));
    return result;
  }

  /// Taip [text] ke dalam medan teks di dalam sasaran [id], huruf demi huruf, seperti pengguna.
  Future<bool> type(String id, String text) async {
    if (!await waitFor(id) || cancelled) return false;
    final rect = AgentTargets.rectOf(id);
    final field = _editableFor(id);
    if (rect == null || field == null) return false;
    _ctl._point(rect);
    await pause(_travel);
    if (!field.mounted) return false;
    field.requestKeyboard();
    final instant = LiteMode.enabled || AgentController.instant;
    final chunks = instant
        ? [text]
        : [for (var i = 1; i <= text.length; i++) text.substring(0, i)];
    for (final value in chunks) {
      if (cancelled) return false;
      field.userUpdateTextEditingValue(
        TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await pause(const Duration(milliseconds: 45));
    }
    return true;
  }

  /// Tekan butang tindakan papan kekunci (cth. "Cari") pada medan teks dalam sasaran [id].
  Future<bool> submit(String id) async {
    final field = _editableFor(id);
    if (field == null || !field.mounted || cancelled) return false;
    field.performAction(field.widget.textInputAction ?? TextInputAction.done);
    await pause(const Duration(milliseconds: 120));
    return !cancelled;
  }

  /// Tekan [resultId]; jika ia tidak muncul (carian gagal sekejap), hantar semula carian dalam
  /// [inputId] sekali dan cuba lagi, seperti pengguna menekan "Cari" semula.
  Future<bool> tapResult(
    String resultId, {
    required String inputId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (await tap(resultId, timeout: timeout)) return true;
    if (cancelled || !await submit(inputId)) return false;
    return tap(resultId, timeout: timeout + const Duration(seconds: 4));
  }

  /// Tatal sehingga [id] kelihatan (cth. kumpulan dalam Tetapan).
  Future<bool> ensureVisible(String id) async {
    final ctx = AgentTargets.contextOf(id);
    if (ctx == null) return false;
    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: _travel == Duration.zero
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    } on Object {
      // Tiada Scrollable di atasnya: sudah kelihatan.
    }
    return true;
  }

  /// Tutup halaman/lembaran di atas peta (termasuk halaman AI).
  Future<void> popToMap() async {
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    await pause(const Duration(milliseconds: 350));
  }

  /// Hantar tekan (turun + naik) terus ke [path], bukan melalui ujian hit seluruh skrin.
  void _dispatchTap(Offset p, HitTestResult path) {
    final pointer = _nextPointer++;
    final binding = GestureBinding.instance;
    binding.dispatchEvent(
      PointerDownEvent(
        pointer: pointer,
        position: p,
        device: kAgentPointerDevice,
      ),
      path,
    );
    binding.dispatchEvent(
      PointerUpEvent(
        pointer: pointer,
        position: p,
        device: kAgentPointerDevice,
      ),
      path,
    );
  }

  /// Medan teks di dalam sasaran [id] (dicari segerak pada pokok widget semasa).
  static EditableTextState? _editableFor(String id) {
    final ctx = AgentTargets.contextOf(id);
    return ctx == null ? null : _editableIn(ctx);
  }

  static EditableTextState? _editableIn(BuildContext ctx) {
    EditableTextState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        found = e.state as EditableTextState;
        return;
      }
      e.visitChildren(visit);
    }

    if (ctx is Element) visit(ctx);
    return found;
  }
}

/// Ejen yang menggunakan app untuk pengguna dan menunjukkan setiap langkah (ADR 0019).
class AgentController extends Notifier<AgentState> {
  /// Ujian: tiada jeda animasi.
  @visibleForTesting
  static bool instant = false;

  bool _cancelled = false;
  Completer<void>? _running;

  @override
  AgentState build() => const AgentState();

  bool get busy => _running != null;

  /// Jalankan [steps] dengan tajuk [title]. Langkah gagal menghentikan larian (langkah seterusnya
  /// bergantung padanya). Satu larian pada satu masa.
  Future<AgentOutcome> run(String title, List<AgentStep> steps) async {
    if (_running != null) stop();
    final done = Completer<void>();
    _running = done;
    _cancelled = false;
    var views = [
      for (final s in steps) AgentStepView(s.label, AgentStepStatus.pending),
    ];
    state = AgentState(active: true, title: title, steps: views);
    final runner = AgentRunner._(this);
    var completed = true;
    for (var i = 0; i < steps.length; i++) {
      if (_cancelled) {
        completed = false;
        break;
      }
      views = [...views]..[i] = views[i].withStatus(AgentStepStatus.running);
      state = state.copyWith(steps: views);
      var ok = false;
      try {
        ok = await steps[i].run(runner);
      } on Object catch (e) {
        logDiag('Ejen: langkah "${steps[i].label}" gagal: $e');
      }
      if (!ref.mounted) break;
      views = [...views]
        ..[i] = views[i].withStatus(
          ok && !_cancelled ? AgentStepStatus.done : AgentStepStatus.failed,
        );
      // Sorotan hanya untuk langkah semasa: halaman mungkin sudah bertukar, segi empat lama basi.
      state = state.copyWith(steps: views, clearTarget: true);
      if (!ok || _cancelled) {
        completed = false;
        break;
      }
    }
    final stopped = _cancelled;
    if (ref.mounted) {
      // Biar senarai semak kelihatan sekejap sebelum lapisan hilang.
      await runner.pause(const Duration(milliseconds: 700));
      if (ref.mounted && identical(_running, done)) {
        state = const AgentState();
      }
    }
    if (identical(_running, done)) _running = null;
    done.complete();
    return AgentOutcome(views, completed: completed, stopped: stopped);
  }

  /// Hentikan ejen (butang Henti, atau pengguna menyentuh skrin).
  void stop() {
    if (_running == null) return;
    _cancelled = true;
    state = state.copyWith(clearTarget: true, pressing: false);
  }

  void _point(Rect target) {
    state = state.copyWith(pointer: target.center, target: target);
  }

  void _press(bool on) => state = state.copyWith(pressing: on);
}

final agentControllerProvider = NotifierProvider<AgentController, AgentState>(
  AgentController.new,
);
