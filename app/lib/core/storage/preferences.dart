import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences` dimuat dalam `main()` sebelum `runApp` (supaya tema dibaca sebelum frame
/// pertama dan tiada kilat putih), lalu disuntik melalui override. Lihat main.dart.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider mesti di-override dalam main()',
  ),
);
