import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/onboarding/data/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/splash/data/splash_controller.dart';
import '../features/splash/presentation/splash_page.dart';

const _splashPath = '/splash';
const _onboardingPath = '/onboarding';

/// Peralihan antara skrin utama: pudar lembut (Reduce Motion: serta-merta).
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.emphasized,
    reverseTransitionDuration: Motion.normal,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Motion.standard),
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // Penghala dibina sekali; perubahan bendera hanya menilai semula `redirect`.
  final refresh = ValueNotifier<int>(0);
  ref.listen<bool>(onboardingDoneProvider, (_, _) => refresh.value++);
  ref.listen<bool>(splashDoneProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final openOnMap = ref.read(splashDoneProvider);
  return GoRouter(
    initialLocation: openOnMap ? '/' : _splashPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final splashDone = ref.read(splashDoneProvider);
      final onboarded = ref.read(onboardingDoneProvider);

      // Splash dahulu pada setiap permulaan app.
      if (!splashDone) return path == _splashPath ? null : _splashPath;
      if (path == _splashPath) return onboarded ? '/' : _onboardingPath;

      if (!onboarded && path != _onboardingPath) return _onboardingPath;
      if (onboarded && path == _onboardingPath) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: _splashPath,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadePage(state, const MapScreen()),
      ),
      GoRoute(
        path: _onboardingPath,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingPage()),
      ),
    ],
  );
});
