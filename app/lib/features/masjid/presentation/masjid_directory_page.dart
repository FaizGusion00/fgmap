import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_targets.dart';
import '../../../core/platform/external_actions.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../data/masjid_directory.dart';

/// Pilihan daripada direktori: tempat (sudah berkoordinat) dan sama ada terus mula navigasi.
@immutable
class MasjidPick {
  const MasjidPick(this.place, {required this.go, this.approximate = false});

  final Place place;

  /// "Pergi": kira laluan dan mula navigasi (seperti Rumah/Kerja). Jika tidak, pratonton laluan.
  final bool go;

  /// Koordinat daripada carian alamat, bukan padanan tepat OSM.
  final bool approximate;
}

/// Senarai semua masjid dan surau di Malaysia (JAKIM). Memulangkan [MasjidPick] bila pengguna memilih
/// Arah atau Pergi.
Future<MasjidPick?> showMasjidDirectory(
  BuildContext context, {
  GeoPoint? near,
  MasjidQuery initial = const MasjidQuery(),
}) => Navigator.of(context).push<MasjidPick>(
  fadeThroughRoute(MasjidDirectoryPage(near: near, initial: initial)),
);

class MasjidDirectoryPage extends ConsumerStatefulWidget {
  const MasjidDirectoryPage({
    super.key,
    this.near,
    this.initial = const MasjidQuery(),
  });

  /// Lokasi pengguna: senarai disusun ikut jarak.
  final GeoPoint? near;
  final MasjidQuery initial;

  @override
  ConsumerState<MasjidDirectoryPage> createState() =>
      _MasjidDirectoryPageState();
}

class _MasjidDirectoryPageState extends ConsumerState<MasjidDirectoryPage> {
  late MasjidQuery _q = widget.initial;
  late final TextEditingController _text = TextEditingController(
    text: widget.initial.text,
  );
  final ScrollController _filters = ScrollController();

  @override
  void dispose() {
    _text.dispose();
    _filters.dispose();
    super.dispose();
  }

  void _set(MasjidQuery q) {
    final revealDistrict = _q.state == null && q.state != null;
    setState(() => _q = q);
    if (!revealDistrict) return;
    // Tunggu cip daerah selesai muncul (AnimatedSize) sebelum menatal, supaya ia
    // tidak tertinggal di luar skrin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 230), () {
        if (!mounted || !_filters.hasClients) return;
        _filters.animateTo(
          _filters.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final directory = ref.watch(masjidDirectoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.masjidDirectoryTitle)),
      body: directory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(text: l10n.masjidDirectoryLoadFailed),
        data: (dir) {
          final results = dir.query(_q, near: widget.near);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AgentTarget(
                  id: 'masjid.search.input',
                  child: TextField(
                    key: const ValueKey('masjid-search'),
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l10n.masjidSearchHint,
                      suffixIcon: _q.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.masjidClear,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _text.clear();
                                _set(_q.copyWith(text: ''));
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => _set(_q.copyWith(text: v)),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  controller: _filters,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final (type, label) in [
                      (null, l10n.masjidAll),
                      (MasjidType.masjid, l10n.masjidTypeMasjid),
                      (MasjidType.surau, l10n.masjidTypeSurau),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: ChoiceChip(
                          key: ValueKey('masjid-type-${type?.name ?? 'all'}'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(label),
                          selected: _q.type == type,
                          onSelected: (_) => _set(
                            type == null
                                ? _q.copyWith(clearType: true)
                                : _q.copyWith(type: type),
                          ),
                        ),
                      ),
                    _FilterMenu(
                      key: const ValueKey('masjid-state'),
                      scope: 'state',
                      title: l10n.masjidStateTitle,
                      value: _q.state,
                      allLabel: l10n.masjidAllStates,
                      items: dir.states,
                      onChanged: (s) => _set(
                        s == null
                            ? _q.copyWith(clearState: true)
                            : _q.copyWith(state: s, clearDistrict: true),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: _q.state == null
                          ? const SizedBox(width: 0, height: 32)
                          : _FilterMenu(
                              key: const ValueKey('masjid-district'),
                              scope: 'district',
                              title: l10n.masjidDistrictTitle,
                              value: _q.district,
                              allLabel: l10n.masjidAllDistricts,
                              items: dir.districtsOf(_q.state!),
                              onChanged: (d) => _set(
                                d == null
                                    ? _q.copyWith(clearDistrict: true)
                                    : _q.copyWith(district: d),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.masjidCount(results.length),
                    key: const ValueKey('masjid-count'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _Message(text: l10n.masjidNoResults)
                    : ListView.builder(
                        itemCount: results.length + 1,
                        itemBuilder: (context, i) => i == results.length
                            ? _Attribution(text: l10n.masjidAttribution)
                            : _Row(
                                entry: results[i],
                                near: widget.near,
                                onTap: () => _open(results[i]),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _open(MasjidEntry entry) async {
    final pick = await showModalBottomSheet<MasjidPick>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => MasjidDetailSheet(entry: entry, near: widget.near),
    );
    if (pick != null && mounted) Navigator.of(context).pop(pick);
  }
}

/// Pilihan penapis yang dipulangkan lembaran. `null` pada [value] bermaksud "semua".
/// Tutup lembaran tanpa memilih memulangkan null, bukan objek ini.
class _FilterChoice {
  const _FilterChoice(this.value);

  final String? value;
}

/// Cip negeri/daerah. DropdownButton dibuang kerana lebarnya ikut item terpanjang
/// ("Negeri Sembilan"), jadi label "Semua negeri" kelihatan besar dan terpotong pada skrin kecil.
class _FilterMenu extends StatefulWidget {
  const _FilterMenu({
    super.key,
    required this.scope,
    required this.title,
    required this.value,
    required this.allLabel,
    required this.items,
    required this.onChanged,
  });

  final String scope;
  final String title;
  final String? value;
  final String allLabel;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  State<_FilterMenu> createState() => _FilterMenuState();
}

class _FilterMenuState extends State<_FilterMenu> {
  bool _open = false;

  Future<void> _openSheet() async {
    setState(() => _open = true);
    final choice = await showModalBottomSheet<_FilterChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        scope: widget.scope,
        title: widget.title,
        value: widget.value,
        allLabel: widget.allLabel,
        items: widget.items,
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (choice != null) widget.onChanged(choice.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.value != null;
    final maxLabel = (MediaQuery.sizeOf(context).width * 0.38).clamp(
      96.0,
      148.0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsetsDirectional.only(start: 2, end: 0),
        selected: selected,
        onSelected: (_) => _openSheet(),
        label: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLabel),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: Text(
                    widget.value ?? widget.allLabel,
                    key: ValueKey(widget.value ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.scope,
    required this.title,
    required this.value,
    required this.allLabel,
    required this.items,
  });

  final String scope;
  final String title;
  final String? value;
  final String allLabel;
  final List<String> items;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  final TextEditingController _search = TextEditingController();
  final GlobalKey _selectedKey = GlobalKey();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : [
            for (final s in widget.items)
              if (s.toLowerCase().contains(q)) s,
          ];
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final cap = media.size.height - keyboard - media.padding.top - 48;
    final preferred = media.size.height * 0.62;
    final height = cap <= 0 ? 0.0 : (preferred < cap ? preferred : cap);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.value == null
                        ? const SizedBox(key: ValueKey('clear-off'), width: 48)
                        : IconButton(
                            key: const ValueKey('masjid-filter-clear'),
                            tooltip: widget.allLabel,
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(const _FilterChoice(null)),
                            icon: const Icon(Icons.filter_alt_off_rounded),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const ValueKey('masjid-filter-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.masjidFilterSearch,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('masjid-filter-list'),
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  16 + media.viewPadding.bottom,
                ),
                children: [
                  if (q.isEmpty)
                    _FilterOption(
                      label: widget.allLabel,
                      selected: widget.value == null,
                      itemKey: ValueKey('masjid-filter-${widget.scope}-all'),
                      onTap: () =>
                          Navigator.of(context).pop(const _FilterChoice(null)),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.masjidFilterEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final s in shown)
                      _FilterOption(
                        label: s,
                        selected: widget.value == s,
                        rowKey: widget.value == s ? _selectedKey : null,
                        itemKey: ValueKey('masjid-filter-${widget.scope}-$s'),
                        onTap: () =>
                            Navigator.of(context).pop(_FilterChoice(s)),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.itemKey,
    required this.onTap,
    this.rowKey,
  });

  final String label;
  final bool selected;
  final Key itemKey;
  final Key? rowKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: itemKey,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.near, required this.onTap});

  final MasjidEntry entry;
  final GeoPoint? near;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = entry.point;
    final where = [
      entry.district,
      entry.state,
      if (p != null && near != null)
        formatDistance(l10n, distanceMeters(near!, p).round()),
    ].whereType<String>().join(' · ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Icon(
          entry.type == MasjidType.masjid
              ? Icons.mosque_rounded
              : Icons.home_work_rounded,
          size: 20,
        ),
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [where, if (entry.address != null) entry.address!].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: p == null
          ? Tooltip(
              message: l10n.masjidApproximateHint,
              child: Icon(
                Icons.location_searching_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

/// Butiran satu tempat: alamat, telefon, Arah dan Pergi. Tempat tanpa koordinat dicari dahulu
/// melalui alamat (Photon/Nominatim) dan ditanda "lokasi anggaran".
class MasjidDetailSheet extends ConsumerStatefulWidget {
  const MasjidDetailSheet({super.key, required this.entry, this.near});

  final MasjidEntry entry;
  final GeoPoint? near;

  @override
  ConsumerState<MasjidDetailSheet> createState() => _MasjidDetailSheetState();
}

class _MasjidDetailSheetState extends ConsumerState<MasjidDetailSheet> {
  bool _finding = false;
  bool _notFound = false;

  Future<void> _choose({required bool go}) async {
    final e = widget.entry;
    final exact = e.point;
    if (exact != null) {
      Navigator.of(context).pop(MasjidPick(_place(exact), go: go));
      return;
    }
    setState(() {
      _finding = true;
      _notFound = false;
    });
    final found = await findMasjidLocation(
      ref.read(geocoderProvider),
      e,
      near: widget.near,
      areaCentre: ref.read(masjidDirectoryProvider).value?.areaCentreOf(e),
    );
    if (!mounted) return;
    if (found == null) {
      setState(() {
        _finding = false;
        _notFound = true;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(MasjidPick(_place(found), go: go, approximate: true));
  }

  Place _place(GeoPoint p) => Place(
    name: widget.entry.name,
    subtitle: [
      widget.entry.district,
      widget.entry.state,
    ].whereType<String>().join(', '),
    point: p,
    category: 'mosque',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.type == MasjidType.masjid
                ? l10n.masjidTypeMasjid
                : l10n.masjidTypeSurau,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(e.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (e.address != null)
            _InfoRow(icon: Icons.place_outlined, text: e.address!),
          _InfoRow(
            icon: Icons.map_outlined,
            text: [
              e.postcode,
              e.district,
              e.state,
            ].whereType<String>().join(', '),
          ),
          if (e.phone != null)
            _InfoRow(
              icon: Icons.call_outlined,
              text: e.phone!,
              onTap: () => ref.read(phoneDialerProvider).dial(e.phone!),
            ),
          if (e.point == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _notFound ? l10n.masjidNotFound : l10n.masjidApproximateHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _notFound
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('masjid-directions'),
                  onPressed: _finding ? null : () => _choose(go: false),
                  icon: const Icon(Icons.directions_rounded),
                  label: Text(l10n.masjidDirections),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('masjid-go'),
                  onPressed: _finding ? null : () => _choose(go: true),
                  icon: _finding
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.navigation_rounded),
                  label: Text(l10n.masjidGo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mencari lokasi tempat tanpa koordinat: nama di daerahnya dahulu, kemudian alamat, kemudian
/// kawasan poskod. Hasil diterima hanya jika:
///  - ia bukan kawasan besar (negeri/daerah/bandar raya) yang pusatnya disangka lokasi masjid;
///  - negeri atau daerahnya sendiri sama (bukan nama jalan: "Jalan Perak" di KL bukan Perak), dengan
///    ejaan Photon ("Penang", "Malacca");
///  - carian nama: nama hasil berkongsi perkataan bermakna dengan nama masjid;
///  - dalam [maxFromAreaM] daripada [areaCentre] (pusat daerah) jika diketahui.
Future<GeoPoint?> findMasjidLocation(
  Geocoder geocoder,
  MasjidEntry e, {
  GeoPoint? near,
  GeoPoint? areaCentre,
  double maxFromAreaM = 60000,
}) async {
  final queries = e.geocodeQueries;
  for (var qi = 0; qi < queries.length; qi++) {
    final q = queries[qi];
    if (q.trim().length < 3) continue;
    try {
      final results = await geocoder.search(q, near: near);
      for (final r in results) {
        if (_tooCoarse(r) || !_inArea(r, e)) continue;
        if (areaCentre != null &&
            distanceMeters(areaCentre, r.point) > maxFromAreaM) {
          continue;
        }
        if (qi == 0 && !_sharesNameWord(r.name, e.name)) continue;
        return r.point;
      }
    } on Object {
      // Rangkaian gagal: cuba pertanyaan seterusnya, kemudian beritahu pengguna.
    }
  }
  return null;
}

const _coarsePlaces = {
  'country',
  'state',
  'region',
  'province',
  'county',
  'district',
  'municipality',
  'city',
};

/// Negeri/daerah/bandar raya: pusatnya bukan lokasi sebuah masjid.
bool _tooCoarse(Place r) =>
    (r.osmKey == 'place' || r.osmKey == 'boundary') &&
    _coarsePlaces.contains(r.category);

const _stateSpellings = {
  'Pulau Pinang': ['pulau pinang', 'penang', 'pinang'],
  'Melaka': ['melaka', 'malacca'],
  'Negeri Sembilan': ['negeri sembilan', 'negri sembilan'],
  'Johor': ['johor', 'johore'],
  'Terengganu': ['terengganu', 'trengganu'],
  'Kuala Lumpur': ['kuala lumpur'],
};

final _roadPart = RegExp(
  r'^(?:\d+[a-z]?\s+)?(?:jalan|jln|lorong|lrg|persiaran|lebuh|lebuhraya|lingkaran|road|street|lane|avenue)\b',
);

/// Bahagian alamat hasil (selepas nama) yang menyebut negeri atau daerah masjid sebagai kawasan,
/// bukan sebagai nama jalan.
bool _inArea(Place r, MasjidEntry e) {
  final parts = [
    for (final p in r.subtitle.toLowerCase().split(','))
      if (p.trim().isNotEmpty && !_roadPart.hasMatch(p.trim())) p.trim(),
  ];
  final names = [
    ...(_stateSpellings[e.state] ?? [e.state.toLowerCase()]),
    if (e.district != null) e.district!.toLowerCase(),
  ];
  for (final part in parts) {
    for (final n in names) {
      if (RegExp('(^|\\s)${RegExp.escape(n)}(\$|\\s)').hasMatch(part)) {
        return true;
      }
    }
  }
  return false;
}

const _genericNameWords = {
  'masjid',
  'surau',
  'musolla',
  'musalla',
  'musollah',
  'mosque',
  'jamek',
  'jamik',
  'jami',
  'al',
  'ar',
  'as',
  'an',
  'at',
  'ad',
  'ash',
  'asy',
  'el',
  'dan',
  'kampung',
  'taman',
  'bandar',
  'jalan',
};

bool _sharesNameWord(String found, String wanted) {
  Set<String> words(String s) => {
    for (final w in foldMasjidText(s).trim().split(' '))
      if (w.length >= 3 && !_genericNameWords.contains(w)) w,
  };
  final want = words(wanted);
  // Nama masjid tanpa perkataan khusus (cth. "Masjid Jamek"): tidak boleh disemak, terima.
  if (want.isEmpty) return true;
  final got = words(
    found,
  ).map((w) => w.replaceAll(RegExp('^(al|as|ar|an|at|asy)'), ''));
  final wantBare = want.map(
    (w) => w.replaceAll(RegExp('^(al|as|ar|an|at|asy)'), ''),
  );
  return got.any(wantBare.contains);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onTap == null ? null : theme.colorScheme.primary,
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
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
