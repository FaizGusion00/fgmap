import 'package:flutter/widgets.dart';

/// Pendaftaran kawalan UI yang boleh "ditekan" oleh ejen FG AI, mengikut id yang stabil
/// (cth. `tool.weather`, `planner.result.0`). Ejen menekan widget SEBENAR di skrin (peristiwa sentuhan
/// pada kedudukannya), jadi apa sahaja yang pengguna boleh tekan, ejen boleh tekan, tanpa laluan rahsia.
abstract final class AgentTargets {
  static final Map<String, List<GlobalKey>> _byId = {};

  static void _add(String id, GlobalKey key) => (_byId[id] ??= []).add(key);

  static void _remove(String id, GlobalKey key) {
    final list = _byId[id];
    list?.remove(key);
    if (list != null && list.isEmpty) _byId.remove(id);
  }

  /// Konteks sasaran [id] yang paling baru dipasang dan masih kelihatan, atau null.
  static BuildContext? contextOf(String id) {
    final list = _byId[id];
    if (list == null) return null;
    for (final key in list.reversed) {
      final ctx = key.currentContext;
      if (ctx != null && ctx.mounted) return ctx;
    }
    return null;
  }

  /// Segi empat sasaran dalam koordinat global, atau null jika tiada/belum dibentang.
  static Rect? rectOf(String id) {
    final ctx = contextOf(id);
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static bool has(String id) => rectOf(id) != null;

  @visibleForTesting
  static void reset() => _byId.clear();
}

/// Tandakan [child] sebagai kawalan yang boleh digunakan ejen dengan [id].
class AgentTarget extends StatefulWidget {
  const AgentTarget({super.key, required this.id, required this.child});

  final String? id;
  final Widget child;

  @override
  State<AgentTarget> createState() => _AgentTargetState();
}

class _AgentTargetState extends State<AgentTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id != null) AgentTargets._add(id, _key);
  }

  @override
  void didUpdateWidget(AgentTarget old) {
    super.didUpdateWidget(old);
    if (old.id == widget.id) return;
    if (old.id != null) AgentTargets._remove(old.id!, _key);
    if (widget.id != null) AgentTargets._add(widget.id!, _key);
  }

  @override
  void dispose() {
    final id = widget.id;
    if (id != null) AgentTargets._remove(id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
