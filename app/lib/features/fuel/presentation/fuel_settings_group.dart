import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/domain/route_option.dart';
import '../data/fuel_price_service.dart';
import '../data/fuel_settings.dart';
import '../domain/fuel.dart';

String fuelTypeLabel(AppLocalizations l10n, FuelType type) => switch (type) {
  FuelType.ron95 => l10n.fuelTypeRon95,
  FuelType.ron97 => l10n.fuelTypeRon97,
  FuelType.diesel => l10n.fuelTypeDiesel,
};

/// Kandungan tetapan kos minyak: jenis, penggunaan setiap kenderaan, dan harga sendiri (pilihan).
/// Dipaparkan dalam kumpulan "Kos minyak" di halaman Tetapan.
class FuelSettingsSection extends ConsumerWidget {
  const FuelSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(fuelSettingsProvider);
    final controller = ref.read(fuelSettingsProvider.notifier);
    final prices = ref.watch(fuelPricesProvider);
    final fetched = prices.value?.priceOf(settings.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FuelType>(
            key: const ValueKey('fuel-type'),
            showSelectedIcon: false,
            segments: [
              for (final t in FuelType.values)
                ButtonSegment(value: t, label: Text(fuelTypeLabel(l10n, t))),
            ],
            selected: {settings.type},
            onSelectionChanged: (s) => controller.setType(s.first),
          ),
        ),
        const SizedBox(height: 8),
        if (fetched != null)
          Text(
            l10n.fuelPriceSource(
              fetched.toStringAsFixed(2),
              prices.value?.effectiveDate ?? '-',
            ),
            key: const ValueKey('fuel-source'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else if (!prices.isLoading)
          Text(
            l10n.fuelPriceUnavailable,
            key: const ValueKey('fuel-unavailable'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        _ConsumptionStepper(
          keyPrefix: 'fuel-car',
          label: l10n.fuelConsumptionCar,
          value: settings.carLitersPer100Km,
          onChanged: (v) => controller.setConsumption(RouteVehicle.car, v),
        ),
        _ConsumptionStepper(
          keyPrefix: 'fuel-moto',
          label: l10n.fuelConsumptionMoto,
          value: settings.motorcycleLitersPer100Km,
          onChanged: (v) =>
              controller.setConsumption(RouteVehicle.motorcycle, v),
        ),
        const SizedBox(height: 12),
        _ManualPriceField(initial: settings.manualPrice),
        const SizedBox(height: 6),
        Text(
          l10n.fuelManualPriceHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConsumptionStepper extends StatelessWidget {
  const _ConsumptionStepper({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  static const _step = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        IconButton(
          key: ValueKey('$keyPrefix-minus'),
          tooltip: '-',
          onPressed: value - _step < minConsumption
              ? null
              : () => onChanged(value - _step),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(1),
            key: ValueKey('$keyPrefix-value'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        IconButton(
          key: ValueKey('$keyPrefix-plus'),
          tooltip: '+',
          onPressed: value + _step > maxConsumption
              ? null
              : () => onChanged(value + _step),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _ManualPriceField extends ConsumerStatefulWidget {
  const _ManualPriceField({required this.initial});

  final double? initial;

  @override
  ConsumerState<_ManualPriceField> createState() => _ManualPriceFieldState();
}

class _ManualPriceFieldState extends ConsumerState<_ManualPriceField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.toStringAsFixed(2) ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _changed(String raw) {
    final controller = ref.read(fuelSettingsProvider.notifier);
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) {
      controller.setManualPrice(null);
      return;
    }
    final value = double.tryParse(cleaned);
    if (value != null) controller.setManualPrice(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const ValueKey('fuel-manual-price'),
      controller: _text,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: l10n.fuelManualPrice,
        prefixText: 'RM ',
        border: const OutlineInputBorder(),
      ),
      onChanged: _changed,
    );
  }
}
