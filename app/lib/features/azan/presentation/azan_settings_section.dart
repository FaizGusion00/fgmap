import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/azan_settings.dart';
import '../domain/malaysia_cities.dart';
import '../domain/prayer.dart';
import 'azan_controller.dart';
import 'azan_l10n.dart';

/// Tetapan Waktu Azan (dalam halaman Tetapan dan lembaran azan). Suis utama dahulu; pilihan lain
/// hanya ditunjukkan apabila hidup supaya skrin tidak sesak.
class AzanSettingsSection extends ConsumerWidget {
  const AzanSettingsSection({super.key, this.showEnable = true});

  final bool showEnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(azanSettingsProvider);
    final controller = ref.read(azanSettingsProvider.notifier);
    final azan = ref.watch(azanControllerProvider);
    final azanController = ref.read(azanControllerProvider.notifier);

    Widget label(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleSmall),
          if (hint != null)
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showEnable)
          SwitchListTile(
            key: const ValueKey('azan-enable'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(l10n.azanEnable),
            subtitle: Text(l10n.azanEnableHint),
            value: settings.enabled,
            onChanged: (on) =>
                on ? azanController.enable() : azanController.disable(),
          ),
        if (azan.permissionDenied)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.azanPermissionDenied,
              key: const ValueKey('azan-permission-denied'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (settings.enabled && !azan.exactAllowed)
          Card(
            key: const ValueKey('azan-exact-card'),
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.azanExactAlarmTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    l10n.azanExactAlarmBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: azanController.openExactAlarmSettings,
                      child: Text(l10n.azanExactAlarmAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (settings.enabled || !showEnable) ...[
          label(l10n.azanPrayersLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in Prayer.fardu)
                FilterChip(
                  key: ValueKey('azan-prayer-${p.name}'),
                  avatar: Icon(_iconFor(p), size: 18),
                  label: Text(prayerName(l10n, p)),
                  selected: settings.prayers.contains(p),
                  onSelected: (on) => controller.setPrayer(p, on),
                ),
            ],
          ),
          label(l10n.azanSoundLabel, hint: l10n.azanSoundHint),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AzanSound>(
              key: const ValueKey('azan-sound'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AzanSound.full,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(l10n.azanSoundFull),
                ),
                ButtonSegment(
                  value: AzanSound.short,
                  icon: const Icon(Icons.notifications_rounded),
                  label: Text(l10n.azanSoundShort),
                ),
                ButtonSegment(
                  value: AzanSound.silent,
                  icon: const Icon(Icons.notifications_off_rounded),
                  label: Text(l10n.azanSoundSilent),
                ),
              ],
              selected: {settings.sound},
              onSelectionChanged: (s) => controller.setSound(s.first),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('azan-listen'),
              onPressed: azan.nowPlaying == null
                  ? azanController.preview
                  : azanController.dismiss,
              icon: Icon(
                azan.nowPlaying == null
                    ? Icons.play_arrow_rounded
                    : Icons.stop_rounded,
              ),
              label: Text(
                azan.nowPlaying == null
                    ? l10n.azanListen
                    : l10n.azanStopListening,
              ),
            ),
          ),
          label(l10n.azanReminderLabel),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              key: const ValueKey('azan-reminder'),
              showSelectedIcon: false,
              segments: [
                for (final m in AzanSettings.reminderChoices)
                  ButtonSegment(
                    value: m,
                    label: Text(
                      m == 0
                          ? l10n.azanReminderNone
                          : l10n.azanReminderMinutes(m),
                    ),
                  ),
              ],
              selected: {settings.reminderMinutes},
              onSelectionChanged: (s) => controller.setReminderMinutes(s.first),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('azan-during-nav'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.azanPlayDuringNav),
            subtitle: Text(l10n.azanPlayDuringNavHint),
            value: settings.playDuringNavigation,
            onChanged: controller.setPlayDuringNavigation,
          ),
          label(l10n.azanLocationLabel, hint: l10n.azanLocationAutoHint),
          DropdownMenu<String?>(
            key: const ValueKey('azan-city'),
            width: double.infinity,
            initialSelection: settings.cityName,
            label: Text(
              settings.useCity ? l10n.azanLocationCity : l10n.azanLocationAuto,
            ),
            onSelected: controller.setCity,
            dropdownMenuEntries: [
              DropdownMenuEntry(value: null, label: l10n.azanLocationAuto),
              for (final c in malaysianCities)
                DropdownMenuEntry(
                  value: c.name,
                  label: '${c.name}, ${c.state}',
                ),
            ],
          ),
          label(l10n.azanMethodLabel),
          DropdownMenu<AzanMethod>(
            key: const ValueKey('azan-method'),
            width: double.infinity,
            initialSelection: settings.method,
            onSelected: (m) => m == null ? null : controller.setMethod(m),
            dropdownMenuEntries: [
              for (final m in AzanMethod.values)
                DropdownMenuEntry(value: m, label: azanMethodName(l10n, m)),
            ],
          ),
          label(l10n.azanMadhabLabel),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AzanMadhab>(
              key: const ValueKey('azan-madhab'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AzanMadhab.shafi,
                  label: Text(l10n.azanMadhabShafi),
                ),
                ButtonSegment(
                  value: AzanMadhab.hanafi,
                  label: Text(l10n.azanMadhabHanafi),
                ),
              ],
              selected: {settings.madhab},
              onSelectionChanged: (s) => controller.setMadhab(s.first),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  static IconData _iconFor(Prayer p) => switch (p) {
    Prayer.fajr => Icons.wb_twilight_rounded,
    Prayer.sunrise => Icons.wb_sunny_outlined,
    Prayer.dhuhr => Icons.light_mode_rounded,
    Prayer.asr => Icons.wb_cloudy_rounded,
    Prayer.maghrib => Icons.nights_stay_outlined,
    Prayer.isha => Icons.dark_mode_rounded,
  };
}
