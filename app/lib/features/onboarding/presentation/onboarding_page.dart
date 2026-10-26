import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/motion.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../map/presentation/location_prompt.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/domain/instruction_text.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../data/onboarding_controller.dart';

/// Sambutan kali pertama: nilai app, privasi (apa yang dihantar ke mana), dan persediaan pantas
/// (kenderaan, bahasa suara, kebenaran lokasi). Boleh dilangkau pada setiap halaman.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _pages = 3;
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingDoneProvider.notifier).complete();
  }

  Future<void> _next() async {
    if (_page >= _pages - 1) {
      await _finish();
      return;
    }
    final duration = Motion.of(context, Motion.normal);
    // Reduce Motion: animateToPage menolak tempoh sifar, jadi lompat terus.
    if (duration == Duration.zero) {
      _controller.jumpToPage(_page + 1);
      return;
    }
    await _controller.nextPage(duration: duration, curve: Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = _page == _pages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextButton(
                  key: const ValueKey('onboarding-skip'),
                  onPressed: _finish,
                  child: Text(l10n.onbSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('onboarding-pages'),
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_WelcomePage(), _PrivacyPage(), _SetupPage()],
              ),
            ),
            Semantics(
              label: l10n.onbPageOf(_page + 1, _pages),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages; i++)
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const ValueKey('onboarding-next'),
                  onPressed: _next,
                  child: Text(last ? l10n.onbStart : l10n.onbNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bingkai halaman: ilustrasi ikon yang masuk dengan lembut, tajuk, kandungan boleh digulung
/// (teks sistem besar atau skrin mendatar).
class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Motion.of(context, Motion.emphasized),
                curve: Motion.enter,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Icon(
                      icon,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _PageFrame(
      icon: Icons.navigation_rounded,
      title: l10n.onbWelcomeTitle,
      children: [
        Text(
          l10n.onbWelcomeBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _Bullet(icon: Icons.alt_route_rounded, text: l10n.onbFeatureRoutes),
        _Bullet(
          icon: Icons.local_gas_station_rounded,
          text: l10n.onbFeatureNearby,
        ),
        _Bullet(icon: Icons.add_alert_rounded, text: l10n.onbFeatureReports),
        _Bullet(
          icon: Icons.cloud_download_outlined,
          text: l10n.onbFeatureOffline,
        ),
      ],
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PageFrame(
      icon: Icons.shield_outlined,
      title: l10n.onbPrivacyTitle,
      children: [
        _Bullet(icon: Icons.phone_android_rounded, text: l10n.onbPrivacyLocal),
        _Bullet(icon: Icons.public_rounded, text: l10n.onbPrivacyServers),
        _Bullet(icon: Icons.my_location_rounded, text: l10n.onbPrivacyLocation),
      ],
    );
  }
}

class _SetupPage extends ConsumerWidget {
  const _SetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vehicle = ref.watch(routeVehicleProvider);
    final settings = ref.watch(navigationSettingsProvider);
    final access = ref.watch(locationAccessProvider);
    final granted = access == LocationAccess.granted;

    return _PageFrame(
      icon: Icons.tune_rounded,
      title: l10n.onbSetupTitle,
      children: [
        Text(l10n.onbVehicleQuestion, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<RouteVehicle>(
            key: const ValueKey('onboarding-vehicle'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: RouteVehicle.car,
                icon: const Icon(Icons.directions_car_rounded),
                label: Text(l10n.routeVehicleCar),
              ),
              ButtonSegment(
                value: RouteVehicle.motorcycle,
                icon: const Icon(Icons.two_wheeler_rounded),
                label: Text(l10n.routeVehicleMotorcycle),
              ),
            ],
            selected: {vehicle},
            onSelectionChanged: (s) =>
                ref.read(routeVehicleProvider.notifier).set(s.first),
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.onbVoiceQuestion, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<VoiceLanguage?>(
            key: const ValueKey('onboarding-voice'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: null, label: Text(l10n.navVoiceFollowApp)),
              ButtonSegment(
                value: VoiceLanguage.ms,
                label: Text(l10n.navVoiceMalay),
              ),
              ButtonSegment(
                value: VoiceLanguage.en,
                label: Text(l10n.navVoiceEnglish),
              ),
            ],
            selected: {settings.voiceLanguage},
            onSelectionChanged: (s) => ref
                .read(navigationSettingsProvider.notifier)
                .setVoiceLanguage(s.first),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('onboarding-location'),
            icon: Icon(
              granted ? Icons.check_circle_rounded : Icons.my_location_rounded,
            ),
            onPressed: granted
                ? null
                : () => unawaited(ensureLocationAccess(context, ref)),
            label: Text(
              granted ? l10n.onbLocationGranted : l10n.onbAllowLocation,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onbLocationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
