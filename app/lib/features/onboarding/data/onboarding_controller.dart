import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';

const onboardingKey = 'onboarding.v1';

/// Sama ada pengguna sudah melalui sambutan pertama. Kunci berversi: skrin sambutan baharu pada
/// versi akan datang boleh dipaparkan semula dengan menaikkan versi.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(onboardingKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(onboardingKey, true);
  }

  /// Untuk tetapan "Lihat sambutan semula".
  Future<void> reset() async {
    state = false;
    await ref.read(sharedPreferencesProvider).remove(onboardingKey);
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);
