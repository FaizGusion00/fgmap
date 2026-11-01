import 'package:flutter/material.dart';

import '../../../core/agent/agent_targets.dart';
import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Satu alat peta pada [MapToolRail] (cuaca, kualiti udara, kiblat, muzik, peta luar talian).
class MapToolSpec {
  const MapToolSpec({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.agentId,
  });

  /// Id untuk ejen FG AI (cth. `tool.weather`), supaya ia boleh menekan alat ini.
  final String? agentId;

  final IconData icon;

  /// Tooltip, label semantik dan teks dalam menu limpahan.
  final String label;

  /// Warna ikon dan latar bulat lembutnya.
  final Color color;
  final VoidCallback onPressed;
}

/// Pelan susun atur kapsul alat: berapa alat muat, sebesar mana, dan perlukah butang "lagi".
@immutable
class MapToolRailPlan {
  const MapToolRailPlan({
    required this.visible,
    required this.button,
    required this.overflow,
    required this.width,
  });

  /// Bilangan alat yang dipaparkan terus; selebihnya masuk menu "lagi".
  final int visible;

  /// Garis pusat setiap butang bulat (dp).
  final double button;
  final bool overflow;

  /// Lebar kapsul keseluruhan.
  final double width;

  static const _gap = 2.0;
  static const _pad = 3.0;

  /// Pilih susun atur terbesar yang muat dalam [budget] dp. Butang mengecil antara [maxButton] dan
  /// [minButton] dahulu; jika masih tidak muat, alat terakhir dipindah ke menu "lagi" (peranti
  /// sempit atau tulisan besar) supaya pil waktu solat di sebelahnya sentiasa terbaca penuh.
  static MapToolRailPlan fit({
    required double budget,
    required int count,
    double minButton = 32,
    double maxButton = 36,
    double gap = _gap,
    double pad = _pad,
  }) {
    for (var shown = count; shown >= 0; shown--) {
      final overflow = shown < count;
      final slots = shown + (overflow ? 1 : 0);
      if (slots == 0) break;
      final b = (budget - 2 * pad - (slots - 1) * gap) / slots;
      if (b >= minButton || shown == 0) {
        final button = b.clamp(minButton, maxButton).toDouble();
        return MapToolRailPlan(
          visible: shown,
          button: button,
          overflow: overflow,
          width: 2 * pad + slots * button + (slots - 1) * gap,
        );
      }
    }
    return const MapToolRailPlan(
      visible: 0,
      button: 0,
      overflow: false,
      width: 0,
    );
  }
}

/// Baris bawah-atas peta: kandungan [leading] (pil waktu solat) di kiri, kapsul alat di kanan.
///
/// Responsif: kapsul diberi baki lebar selepas [leadingMinWidth] disimpan untuk [leading]. Butang
/// mengecil (32 hingga 36 dp; 44 hingga 52 dp dalam Mod mudah) dan alat berlebihan masuk menu "lagi",
/// jadi waktu solat tidak lagi terpotong pada telefon sempit.
class MapToolsRow extends StatelessWidget {
  const MapToolsRow({super.key, required this.tools, this.leading});

  final List<MapToolSpec> tools;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final easy = EasyModeScope.of(context);
    final leadingMin = leading == null ? 0.0 : (easy ? 176.0 : 140.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = leading == null ? 0.0 : 8.0;
        final budget = constraints.maxWidth - leadingMin - gap;
        final plan = MapToolRailPlan.fit(
          budget: budget,
          count: tools.length,
          minButton: easy ? 44 : 32,
          maxButton: easy ? 52 : 36,
          gap: easy ? 4 : 2,
          pad: easy ? 4 : 3,
        );
        return Row(
          children: [
            if (leading != null)
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leading),
              )
            else
              const Spacer(),
            if (leading != null) SizedBox(width: gap),
            MapToolRail(tools: tools, plan: plan),
          ],
        );
      },
    );
  }
}

/// Alat peta dalam SATU kapsul kaca, bukan beberapa bulatan berwarna-warni yang bersaing dengan
/// peta. Warna kekal sebagai gradien halus pada latar bulat setiap ikon.
class MapToolRail extends StatelessWidget {
  const MapToolRail({super.key, required this.tools, required this.plan});

  final List<MapToolSpec> tools;
  final MapToolRailPlan plan;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    final easy = EasyModeScope.of(context);
    final gap = easy ? 4.0 : 2.0;
    final shown = tools.take(plan.visible).toList();
    final hidden = tools.skip(plan.visible).toList();
    return Material(
      key: const ValueKey('tool-rail'),
      color: fg.glassSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
      child: Padding(
        padding: EdgeInsets.all(easy ? 4 : 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _ToolButton(spec: shown[i], size: plan.button, easy: easy),
            ],
            if (plan.overflow) ...[
              if (shown.isNotEmpty) SizedBox(width: gap),
              _OverflowButton(tools: hidden, size: plan.button, easy: easy),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.spec,
    required this.size,
    required this.easy,
  });

  final MapToolSpec spec;
  final double size;
  final bool easy;

  @override
  Widget build(BuildContext context) {
    return AgentTarget(id: spec.agentId, child: _button(context));
  }

  Widget _button(BuildContext context) {
    return PressScale(
      child: Tooltip(
        message: spec.label,
        child: Semantics(
          button: true,
          label: spec.label,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: spec.onPressed,
              child: Ink(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      spec.color.withValues(alpha: 0.26),
                      spec.color.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Icon(
                  spec.icon,
                  size: easy ? 26 : size * 0.52,
                  color: spec.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alat yang tidak muat dikumpulkan di sini; ketik membuka menu kecil berlabel.
class _OverflowButton extends StatelessWidget {
  const _OverflowButton({
    required this.tools,
    required this.size,
    required this.easy,
  });

  final List<MapToolSpec> tools;
  final double size;
  final bool easy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Ejen membuka menu ini untuk mencapai alat yang tersembunyi (`tool.more`), kemudian menekan
    // item `menu.<id>`.
    return AgentTarget(
      id: 'tool.more',
      child: PopupMenuButton<int>(
        key: const ValueKey('tool-rail-more'),
        tooltip: l10n.mapToolsMore,
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (i) => tools[i].onPressed(),
        itemBuilder: (context) => [
          for (var i = 0; i < tools.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: AgentTarget(
                id: tools[i].agentId == null
                    ? null
                    : 'menu.${tools[i].agentId}',
                child: Row(
                  children: [
                    Icon(tools[i].icon, color: tools[i].color, size: 22),
                    const SizedBox(width: 12),
                    Text(tools[i].label),
                  ],
                ),
              ),
            ),
        ],
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              size: easy ? 26 : size * 0.56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
