import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/map/presentation/map_screen.dart';
import '../features/onboarding/data/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';

const _onboardingPath = '/onboarding';

final routerProvider = Provider<GoRouter>((ref) {
  // Penghala dibina sekali; perubahan bendera sambutan hanya menilai semula `redirect`.
  final done = ValueNotifier<bool>(ref.read(onboardingDoneProvider));
  ref.listen<bool>(onboardingDoneProvider, (_, next) => done.value = next);
  ref.onDispose(done.dispose);

  return GoRouter(
    refreshListenable: done,
    redirect: (context, state) {
      final onboarded = ref.read(onboardingDoneProvider);
      final atOnboarding = state.matchedLocation == _onboardingPath;
      if (!onboarded && !atOnboarding) return _onboardingPath;
      if (onboarded && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MapScreen()),
      GoRoute(
        path: _onboardingPath,
        builder: (context, state) => const OnboardingPage(),
      ),
    ],
  );
});
