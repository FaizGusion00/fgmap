import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';

// ThemeData dibina sekali sahaja; membina semula pada setiap build akan mencetuskan animasi tema.
final _lightTheme = AppTheme.light();
final _darkTheme = AppTheme.dark();
final _amoledTheme = AppTheme.dark(amoled: true);

class FgmapApp extends ConsumerWidget {
  const FgmapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: _lightTheme,
      darkTheme: settings.amoled ? _amoledTheme : _darkTheme,
      themeMode: settings.mode,
      themeAnimationDuration: Motion.themeSwitch,
      themeAnimationCurve: Motion.standard,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveLocale,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          _SystemUiStyle(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Bahasa Melayu ialah bahasa lalai (Bahagian 14.5): hanya English jika peranti memintanya;
/// bahasa lain (cth. Mandarin, Tamil, yang belum disokong) jatuh balik kepada Bahasa Melayu.
/// Tanpa ini Flutter jatuh balik kepada locale pertama yang disokong, iaitu English (abjad).
Locale resolveLocale(Locale? device, Iterable<Locale> supported) {
  if (device?.languageCode == 'en') return const Locale('en');
  return const Locale('ms');
}

/// Ikon bar status dan bar navigasi mengikut kecerahan tema, di atas kandungan tepi-ke-tepi.
class _SystemUiStyle extends StatelessWidget {
  const _SystemUiStyle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: base.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
