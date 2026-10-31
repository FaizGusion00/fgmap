import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/azan_scheduler.dart';
import '../domain/prayer.dart';

/// Nama waktu dalam bahasa UI.
String prayerName(AppLocalizations l10n, Prayer p) => switch (p) {
  Prayer.fajr => l10n.azanPrayerFajr,
  Prayer.sunrise => l10n.azanPrayerSunrise,
  Prayer.dhuhr => l10n.azanPrayerDhuhr,
  Prayer.asr => l10n.azanPrayerAsr,
  Prayer.maghrib => l10n.azanPrayerMaghrib,
  Prayer.isha => l10n.azanPrayerIsha,
};

String azanMethodName(AppLocalizations l10n, AzanMethod m) => switch (m) {
  AzanMethod.jakim => l10n.azanMethodJakim,
  AzanMethod.mwl => l10n.azanMethodMwl,
  AzanMethod.egyptian => l10n.azanMethodEgyptian,
  AzanMethod.karachi => l10n.azanMethodKarachi,
  AzanMethod.ummAlQura => l10n.azanMethodUmmAlQura,
};

/// "1 j 12 min" / "12 min".
String remainingText(AppLocalizations l10n, Duration d) {
  final m = d.inMinutes.clamp(0, 1 << 30);
  if (m >= 60) return l10n.azanRemainingHours(m ~/ 60, m % 60);
  return l10n.azanRemainingMinutes(m);
}

String formatClock(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(t));

/// Teks notifikasi untuk penjadual, dalam bahasa UI semasa.
AzanNotificationTexts azanNotificationTexts(
  AppLocalizations l10n,
  Locale locale,
) => AzanNotificationTexts(
  locale: locale,
  prayerNames: {for (final p in Prayer.values) p: prayerName(l10n, p)},
  azanTitle: l10n.azanNowTitle,
  azanBody: l10n.azanNowBody,
  reminderTitle: l10n.azanReminderTitle,
  reminderBody: l10n.azanReminderBody,
  channelFull: l10n.azanChannelFull,
  channelShort: l10n.azanChannelShort,
  channelSilent: l10n.azanChannelSilent,
  channelReminder: l10n.azanChannelReminder,
);
