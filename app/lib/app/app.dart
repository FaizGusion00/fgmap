import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_preferences.dart';
import '../core/settings/easy_mode_scope.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/navigation/presentation/car_session_hub.dart';
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
    final prefs = ref.watch(appPreferencesProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: _lightTheme,
      darkTheme: settings.amoled ? _amoledTheme : _darkTheme,
      themeMode: ref.watch(effectiveThemeModeProvider),
      themeAnimationDuration: _themeAnimation(prefs.reduceMotion),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Pilihan bahasa pengguna mengatasi bahasa peranti; null = ikut peranti (BM lalai).
      locale: prefs.locale,
      localeResolutionCallback: resolveLocale,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        ref.watch(carSessionHubProvider);
        return _SystemUiStyle(
          child: _applyAccessibility(
            context,
            prefs,
            child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Saiz teks pilihan pengguna didarab dengan tetapan sistem (dihadkan supaya susun atur tidak pecah),
/// "Kurangkan animasi" memaksa Reduce Motion untuk seluruh app, dan Mod mudah (teks sekurang-kurangnya
/// 115%) disebarkan melalui [EasyModeScope].
Widget _applyAccessibility(
  BuildContext context,
  AppPreferences prefs,
  Widget child,
) {
  final media = MediaQuery.of(context);
  final system = media.textScaler.scale(1);
  return EasyModeScope(
    enabled: prefs.easyMode,
    child: MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(
          (system * prefs.effectiveTextScale).clamp(0.8, 2.0),
        ),
        disableAnimations: media.disableAnimations || prefs.reduceMotion,
      ),
      child: child,
    ),
  );
}

/// Peralihan tema lembut (~300 ms, Bahagian 14.6); tiada peralihan jika pengguna meminta Reduce Motion.
Duration _themeAnimation(bool reduceMotion) => reduceMotion
    ? Duration.zero
    : WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations
    ? Duration.zero
    : const Duration(milliseconds: 300);

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
