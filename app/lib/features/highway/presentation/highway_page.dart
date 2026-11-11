import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/agent/agent_targets.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../route_preview/presentation/route_format.dart';
import '../data/llm_cctv.dart';
import '../data/llm_toll_client.dart';
import '../domain/highways.dart';

enum HighwayTab { cctv, toll }

/// Lebuh raya: CCTV langsung (LLM) dan kalkulator tol rasmi LLM.
///
/// [routeCodes]: lebuh raya laluan semasa (didahulukan). [routePoints]: garisan laluan, untuk menanda
/// kamera yang berada di laluan. [near]: lokasi pengguna (jarak kamera).
Future<void> showHighwayPage(
  BuildContext context, {
  HighwayTab tab = HighwayTab.cctv,
  List<String> routeCodes = const [],
  List<GeoPoint> routePoints = const [],
  GeoPoint? near,
}) => Navigator.of(context).push<void>(
  fadeThroughRoute(
    HighwayPage(
      tab: tab,
      routeCodes: routeCodes,
      routePoints: routePoints,
      near: near,
    ),
  ),
);

const _llmHome = 'https://www.llm.gov.my/';

/// Video langsung KLCCC (DBKL): strim HLS dilindungi daripada pautan luar, jadi dibuka di laman mereka
/// sendiri (bukan dibenam dalam app).
const _klcccVideo = 'https://klccc.dbkl.gov.my/cctv-images/';

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    // Tiada pelayar: tiada apa yang boleh dibuat.
  }
}

Future<void> _openLlm() => _open(_llmHome);

class HighwayPage extends ConsumerWidget {
  const HighwayPage({
    super.key,
    this.tab = HighwayTab.cctv,
    this.routeCodes = const [],
    this.routePoints = const [],
    this.near,
  });

  final HighwayTab tab;
  final List<String> routeCodes;
  final List<GeoPoint> routePoints;
  final GeoPoint? near;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: tab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.highwayTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                key: const ValueKey('highway-tab-cctv'),
                icon: const Icon(Icons.videocam_rounded),
                text: l10n.highwayTabCctv,
              ),
              AgentTarget(
                id: 'highway.tab.toll',
                child: Tab(
                  key: const ValueKey('highway-tab-toll'),
                  icon: const Icon(Icons.calculate_rounded),
                  text: l10n.highwayTabToll,
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CctvView(
              routeCodes: routeCodes,
              routePoints: routePoints,
              near: near,
            ),
            const TollCalculatorView(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- CCTV

/// Kamera dalam jarak ini daripada garisan laluan ditanda "Di laluan".
const _onRouteM = 1000.0;

double? _distanceToRoute(GeoPoint p, List<GeoPoint> route) {
  if (route.length < 2) return null;
  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final d = projectToSegment(p, route[i], route[i + 1]).distanceM;
    if (d < best) best = d;
  }
  return best;
}

class CctvView extends ConsumerStatefulWidget {
  const CctvView({
    super.key,
    this.routeCodes = const [],
    this.routePoints = const [],
    this.near,
  });

  final List<String> routeCodes;
  final List<GeoPoint> routePoints;
  final GeoPoint? near;

  /// LLM mengemas kini snapshot kira-kira setiap minit (cache pelayan 60 s); dimuat semula setiap 30 s
  /// supaya bingkai baharu muncul paling lewat 30 s selepas LLM menyiarkannya. Senarai perlu dimuat semula
  /// (bukan imej sahaja) kerana URL bertandatangan.
  static const refreshEvery = Duration(seconds: 30);

  @override
  ConsumerState<CctvView> createState() => _CctvViewState();
}

class _CctvViewState extends ConsumerState<CctvView>
    with AutomaticKeepAliveClientMixin {
  late String _code = widget.routeCodes.isNotEmpty
      ? widget.routeCodes.first
      : llmHighways.first.code;
  Timer? _ticker;
  DateTime? _loadedAt;
  DateTime _nextAt = DateTime.now().add(CctvView.refreshEvery);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Satu detik: umur imej dan kiraan undur; muat semula bila sampai masanya. Hanya bila benar-benar
    // kelihatan: halaman teratas, tab CCTV dipilih (tab dikekalkan hidup), dan app di hadapan. Dulu
    // ia terus memuat turun imej setiap 30 s dari tab kalkulator tol dan dari latar belakang.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_visible) return;
      if (!DateTime.now().isBefore(_nextAt)) _refresh();
      setState(() {});
    });
  }

  bool get _visible {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final tabs = DefaultTabController.maybeOf(context);
    // CCTV ialah tab pertama dalam HighwayPage.
    return tabs == null || tabs.index == 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _refresh() {
    _nextAt = DateTime.now().add(CctvView.refreshEvery);
    ref.invalidate(cctvCamerasProvider(_code));
  }

  void _select(String code) {
    if (code == _code) return;
    setState(() {
      _code = code;
      _loadedAt = null;
      _nextAt = DateTime.now().add(CctvView.refreshEvery);
    });
  }

  List<LlmHighway> get _ordered => [
    for (final c in widget.routeCodes) ?llmHighwayByCode(c),
    for (final h in llmHighways)
      if (!widget.routeCodes.contains(h.code)) h,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final driving = ref.watch(
      navigationControllerProvider.select((s) => s.isActive),
    );
    ref.listen(cctvCamerasProvider(_code), (_, next) {
      if (next.hasValue && !next.isLoading) {
        setState(() => _loadedAt = DateTime.now());
      }
    });
    final cams = ref.watch(cctvCamerasProvider(_code));
    final highway = llmHighwayByCode(_code);
    final count = cams.value?.length;
    return Column(
      children: [
        if (driving)
          MaterialBanner(
            key: const ValueKey('cctv-driving-warning'),
            leading: const Icon(Icons.warning_amber_rounded),
            content: Text(l10n.cctvDrivingWarning),
            actions: const [SizedBox.shrink()],
          ),
        // Semua cip dibina (bukan malas) supaya ejen FG AI boleh menatal ke cip mana-mana lebuh raya.
        SingleChildScrollView(
          key: const ValueKey('cctv-highways'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              for (final h in _ordered)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AgentTarget(
                    id: 'cctv.hw.${h.code}',
                    child: _HighwayChip(
                      key: ValueKey('cctv-hw-${h.code}'),
                      highway: h,
                      selected: h.code == _code,
                      onRoute: widget.routeCodes.contains(h.code),
                      onTap: () => _select(h.code),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      highway?.name ?? _code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (count != null)
                      Text(
                        l10n.cctvCameraCount(count),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _SnapshotStatus(
          loadedAt: _loadedAt,
          nextAt: _nextAt,
          loading: cams.isLoading,
          onRefresh: _refresh,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              _nextAt = DateTime.now().add(CctvView.refreshEvery);
              return ref.refresh(cctvCamerasProvider(_code).future);
            },
            child: cams.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _Message(
                key: const ValueKey('cctv-error'),
                text: l10n.cctvLoadFailed,
                onRetry: _refresh,
              ),
              data: (list) => list.isEmpty
                  ? _Message(
                      key: const ValueKey('cctv-empty'),
                      text: l10n.cctvEmpty,
                    )
                  : _CameraGrid(
                      code: _code,
                      cameras: list,
                      routePoints: widget.routePoints,
                      near: widget.near,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighwayChip extends StatelessWidget {
  const _HighwayChip({
    super.key,
    required this.highway,
    required this.selected,
    required this.onRoute,
    required this.onTap,
  });

  final LlmHighway highway;
  final bool selected;
  final bool onRoute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(
            color: onRoute && !selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: selected ? 0 : 1),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Perisai nombor laluan (seperti papan tanda E-).
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.onPrimary.withValues(alpha: 0.18)
                        : const Color(0xFF0B6B3A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    highway.ref,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (onRoute) ...[
                  Icon(Icons.route_rounded, size: 16, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  highway.short,
                  style: theme.textTheme.labelLarge?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Jalur status jujur: snapshot (bukan video), kekerapan kemas kini LLM, umur muatan, dan kiraan undur.
class _SnapshotStatus extends StatelessWidget {
  const _SnapshotStatus({
    required this.loadedAt,
    required this.nextAt,
    required this.loading,
    required this.onRefresh,
  });

  final DateTime? loadedAt;
  final DateTime nextAt;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final total = CctvView.refreshEvery.inSeconds;
    final left = nextAt.difference(now).inSeconds.clamp(0, total);
    final age = loadedAt == null ? null : now.difference(loadedAt!).inSeconds;
    return Padding(
      key: const ValueKey('cctv-status'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.cctvSnapshotBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cctvUpdateEvery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        [
                          if (age != null) l10n.cctvLoadedAgo(age),
                          l10n.cctvNextIn(left),
                        ].join(' · '),
                        key: const ValueKey('cctv-status-age'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.highwayRetry,
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: 1 - left / total,
                  minHeight: 3,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraGrid extends StatelessWidget {
  const _CameraGrid({
    required this.code,
    required this.cameras,
    required this.routePoints,
    required this.near,
  });

  final String code;
  final List<CctvCamera> cameras;
  final List<GeoPoint> routePoints;
  final GeoPoint? near;

  @override
  Widget build(BuildContext context) {
    final rows =
        [
          for (final c in cameras)
            (
              cam: c,
              onRoute:
                  c.point != null &&
                  (_distanceToRoute(c.point!, routePoints) ??
                          double.infinity) <=
                      _onRouteM,
              away: c.point == null || near == null
                  ? null
                  : distanceMeters(near!, c.point!),
            ),
        ]..sort((a, b) {
          if (a.onRoute != b.onRoute) return a.onRoute ? -1 : 1;
          final x = a.away ?? double.infinity;
          final y = b.away ?? double.infinity;
          return x.compareTo(y);
        });
    final cols = MediaQuery.sizeOf(context).width >= 600 ? 3 : 1;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          sliver: SliverGrid.builder(
            // Imej LLM 4:3 (320 x 240): kad = imej penuh, teks di atas imej.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 4 / 3,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) => _CameraCard(
              code: code,
              camera: rows[i].cam,
              onRoute: rows[i].onRoute,
              awayM: rows[i].away,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _LiveVideoCard()),
      ],
    );
  }
}

/// Jawapan jujur kepada "ada video langsung?": apa yang wujud dan di mana.
class _LiveVideoCard extends StatelessWidget {
  const _LiveVideoCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Container(
        key: const ValueKey('cctv-live-video'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.live_tv_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.cctvLiveVideoTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.cctvLiveVideoBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const ValueKey('cctv-kl-video'),
                  onPressed: () => _open(_klcccVideo),
                  icon: const Icon(Icons.play_circle_rounded, size: 18),
                  label: Text(l10n.cctvKlVideo),
                ),
                TextButton.icon(
                  onPressed: _openLlm,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l10n.cctvOpenLlm),
                ),
              ],
            ),
            Text(
              l10n.cctvFooter,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

String? _directionLabel(AppLocalizations l10n, String? d) => switch (d) {
  'N' => l10n.cctvDirN,
  'S' => l10n.cctvDirS,
  'E' => l10n.cctvDirE,
  'W' => l10n.cctvDirW,
  _ => null,
};

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.code,
    required this.camera,
    required this.onRoute,
    required this.awayM,
  });

  final String code;
  final CctvCamera camera;
  final bool onRoute;
  final double? awayM;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dir = _directionLabel(l10n, camera.direction);
    final away = awayM == null ? null : formatDistance(l10n, awayM!.round());
    return Semantics(
      button: true,
      label: [camera.label, ?dir, ?away].join(', '),
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push<void>(
            fadeThroughRoute(_CameraFullScreen(code: code, camera: camera)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: _CctvImage(url: camera.imageUrl, fit: BoxFit.cover),
              ),
              // Kecerunan bawah supaya teks putih sentiasa boleh dibaca di atas imej.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.55, 1],
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    if (onRoute)
                      _Pill(
                        icon: Icons.route_rounded,
                        text: l10n.cctvOnRoute,
                        color: scheme.primary,
                        textColor: scheme.onPrimary,
                      ),
                    const Spacer(),
                    if (away != null)
                      _Pill(
                        icon: Icons.near_me_rounded,
                        text: away,
                        color: const Color(0x99000000),
                        textColor: Colors.white,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            camera.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (dir != null)
                            Text(
                              dir,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.fullscreen_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CctvImage extends StatelessWidget {
  const _CctvImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Image.network(
      url,
      fit: fit,
      // URL baharu setiap muat semula: kekalkan imej lama sehingga yang baharu siap (tiada kelip).
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, _) => frame == null
          ? const ColoredBox(
              color: Color(0xFF111418),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            )
          : child,
      errorBuilder: (context, _, _) => ColoredBox(
        color: const Color(0xFF111418),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54),
              const SizedBox(height: 4),
              Text(
                l10n.cctvImageUnavailable,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skrin penuh: imej yang sama, dimuat semula sendiri setiap [CctvView.refreshEvery].
class _CameraFullScreen extends ConsumerStatefulWidget {
  const _CameraFullScreen({required this.code, required this.camera});

  final String code;
  final CctvCamera camera;

  @override
  ConsumerState<_CameraFullScreen> createState() => _CameraFullScreenState();
}

class _CameraFullScreenState extends ConsumerState<_CameraFullScreen> {
  Timer? _timer;
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(CctvView.refreshEvery, (_) {
      // Jangan muat turun imej ketika app di latar belakang.
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ref.invalidate(cctvCamerasProvider(widget.code));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.listen(cctvCamerasProvider(widget.code), (_, next) {
      if (next.hasValue && !next.isLoading) {
        setState(() => _loadedAt = DateTime.now());
      }
    });
    // URL terkini bagi kamera yang sama (URL bertandatangan berubah setiap muat semula).
    final latest =
        ref
            .watch(cctvCamerasProvider(widget.code))
            .value
            ?.where((c) => c.fileName == widget.camera.fileName)
            .firstOrNull ??
        widget.camera;
    final dir = _directionLabel(l10n, latest.direction);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(_loadedAt));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(latest.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              [?dir, l10n.cctvFullscreenLoaded(time)].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.highwayRetry,
            onPressed: () => ref.invalidate(cctvCamerasProvider(widget.code)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _CctvImage(
                      url: latest.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.cctvUpdateEvery,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            if (onRetry != null)
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.highwayRetry),
              ),
            TextButton(onPressed: _openLlm, child: Text(l10n.cctvOpenLlm)),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Kalkulator

final _llmHighwaysProvider = FutureProvider.autoDispose<List<LlmOption>>(
  (ref) => ref.watch(llmTollClientProvider).highways(),
);

class TollCalculatorView extends ConsumerStatefulWidget {
  const TollCalculatorView({super.key});

  @override
  ConsumerState<TollCalculatorView> createState() => _TollCalculatorViewState();
}

class _TollCalculatorViewState extends ConsumerState<TollCalculatorView>
    with AutomaticKeepAliveClientMixin {
  LlmOption? _highway;
  LlmOption? _entry;
  LlmOption? _exit;
  List<LlmOption>? _entries;
  List<LlmOption>? _exits;
  List<LlmTollRate>? _rates;
  bool _busy = false;
  bool _failed = false;

  /// Setiap pilihan baharu membatalkan jawapan lama yang tiba lewat.
  int _seq = 0;

  @override
  bool get wantKeepAlive => true;

  LlmTollClient get _client => ref.read(llmTollClientProvider);

  Future<void> _run(Future<void> Function(int seq) body) async {
    final seq = ++_seq;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await body(seq);
    } on LlmTollFailure {
      if (mounted && seq == _seq) setState(() => _failed = true);
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  void _pickHighway(LlmOption? h) {
    setState(() {
      _highway = h;
      _entry = _exit = null;
      _entries = _exits = null;
      _rates = null;
    });
    if (h == null) return;
    unawaited(
      _run((seq) async {
        final list = await _client.entries(h.id);
        if (mounted && seq == _seq) setState(() => _entries = list);
      }),
    );
  }

  void _pickEntry(LlmOption? e) {
    final h = _highway;
    setState(() {
      _entry = e;
      _exit = null;
      _exits = null;
      _rates = null;
    });
    if (h == null || e == null) return;
    unawaited(
      _run((seq) async {
        final exits = await _client.exits(h.id, e.id);
        if (!mounted || seq != _seq) return;
        setState(() => _exits = exits);
        // Plaza harga tetap: tiada plaza keluar, kadar terus.
        if (exits.isEmpty) {
          final rates = await _client.rates(h.id, e.id, null);
          if (mounted && seq == _seq) setState(() => _rates = rates);
        }
      }),
    );
  }

  void _pickExit(LlmOption? x) {
    final h = _highway;
    final e = _entry;
    setState(() {
      _exit = x;
      _rates = null;
    });
    if (h == null || e == null || x == null) return;
    unawaited(
      _run((seq) async {
        final rates = await _client.rates(h.id, e.id, x.id);
        if (mounted && seq == _seq) setState(() => _rates = rates);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final highways = ref.watch(_llmHighwaysProvider);
    Widget dropdown({
      required String key,
      required String label,
      required List<LlmOption> items,
      required LlmOption? value,
      required ValueChanged<LlmOption?> onChanged,
    }) => DropdownButtonFormField<LlmOption>(
      key: ValueKey(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in items)
          DropdownMenuItem(
            value: o,
            child: Text(o.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy ? null : onChanged,
    );

    return highways.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        key: const ValueKey('toll-calc-error'),
        text: l10n.tollCalcFailed,
        onRetry: () => ref.invalidate(_llmHighwaysProvider),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          dropdown(
            key: 'toll-calc-highway',
            label: l10n.tollCalcHighway,
            items: list,
            value: _highway,
            onChanged: _pickHighway,
          ),
          if (_entries != null) ...[
            const SizedBox(height: 12),
            dropdown(
              key: 'toll-calc-entry-${_highway?.id}',
              label: l10n.tollCalcEntry,
              items: _entries!,
              value: _entry,
              onChanged: _pickEntry,
            ),
          ],
          if (_exits != null && _exits!.isNotEmpty) ...[
            const SizedBox(height: 12),
            dropdown(
              key: 'toll-calc-exit-${_highway?.id}-${_entry?.id}',
              label: l10n.tollCalcExit,
              items: _exits!,
              value: _exit,
              onChanged: _pickExit,
            ),
          ],
          if (_exits != null && _exits!.isEmpty && _entry != null) ...[
            const SizedBox(height: 8),
            Text(l10n.tollCalcOpenPlaza, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_failed)
            _Message(
              key: const ValueKey('toll-calc-step-error'),
              text: l10n.tollCalcFailed,
            ),
          if (_rates != null) _RatesCard(rates: _rates!),
          if (_rates == null && !_busy && !_failed)
            Text(
              l10n.tollCalcPick,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.tollCalcSource,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.rates});

  final List<LlmTollRate> rates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String label(int c) => switch (c) {
      1 => l10n.tollCalcClass1,
      2 => l10n.tollCalcClass2,
      3 => l10n.tollCalcClass3,
      4 => l10n.tollCalcClass4,
      5 => l10n.tollCalcClass5,
      _ => '$c',
    };
    if (rates.isEmpty) return Text(l10n.tollCalcNoRate);
    return Card(
      key: const ValueKey('toll-calc-rates'),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final r in rates)
            ListTile(
              dense: true,
              title: Text(
                label(r.vehicleClass),
                style: r.vehicleClass == 1
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
              trailing: Text(
                l10n.routeTollRm(r.rm.toStringAsFixed(2)),
                style: r.vehicleClass == 1
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
