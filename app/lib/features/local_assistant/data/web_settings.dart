import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';

const assistantAutoWebPrefsKey = 'assistant.web.auto';

/// FG AI boleh mencari maklumat terkini di internet secara automatik bila soalan memerlukannya
/// ("siapa … sekarang", "keputusan … semalam"). Permintaan jelas ("cari online", berita, pautan)
/// sentiasa dijalankan. Lalai: hidup.
class AutoWebController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(assistantAutoWebPrefsKey) ??
      true;

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(assistantAutoWebPrefsKey, value);
  }
}

final assistantAutoWebProvider = NotifierProvider<AutoWebController, bool>(
  AutoWebController.new,
);
