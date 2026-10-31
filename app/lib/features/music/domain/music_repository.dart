import 'player_state.dart';
import 'track.dart';

/// Katalog Audius: cari lagu dan trending. Semua percuma tanpa kunci.
abstract interface class AudiusRepository {
  Future<List<Track>> search(String query);
  Future<List<Track>> trending();
}

/// Kawasan/genre stesen radio yang boleh dilayari tanpa menaip. Hanya penapis yang tepat:
/// `language=malay` sengaja tidak digunakan kerana ia turut memadankan Malayalam.
enum RadioRegion {
  /// Stesen yang ditanda pengguna (disimpan pada peranti); bukan carian Radio Browser.
  favorites,
  malaysia,
  indonesia,
  japan,
  jpop,
  korea,
  kpop;

  /// Parameter carian Radio Browser untuk kawasan ini.
  Map<String, Object> get params => switch (this) {
    RadioRegion.favorites => const {},
    RadioRegion.malaysia => const {'countrycode': 'MY'},
    RadioRegion.indonesia => const {'countrycode': 'ID'},
    RadioRegion.japan => const {'countrycode': 'JP'},
    RadioRegion.jpop => const {'tag': 'jpop'},
    RadioRegion.korea => const {'countrycode': 'KR'},
    RadioRegion.kpop => const {'tag': 'kpop'},
  };
}

/// Stesen radio daripada Radio Browser: Malaysia, Indonesia, Japan, J-pop, Korea dan K-pop.
abstract interface class RadioRepository {
  /// Stesen (HTTPS sahaja), paling popular dahulu, untuk [region]. [query] tidak kosong mencari
  /// mengikut nama di seluruh dunia (cth. "Prambors", "KBS") dan menggabungkan dengan padanan
  /// dalam senarai [region].
  Future<List<Track>> stations({
    String query = '',
    RadioRegion region = RadioRegion.malaysia,
  });

  /// Kiraan klik tanpa nama (dasar Radio Browser: hantar untuk setiap main). Tidak melontar.
  Future<void> countClick(String stationUuid);
}

/// Fail muzik yang diimport ke storan app (sentiasa berfungsi luar talian).
abstract interface class LocalLibrary {
  Future<List<Track>> list();

  /// Buka pemilih fail dan salin pilihan ke pustaka; mengembalikan lagu yang ditambah.
  Future<List<Track>> import();
  Future<void> remove(Track track);
  Future<void> clear();
}

/// Enjin audio (just_audio di belakang antara muka supaya pengawal boleh diuji dengan palsu).
abstract interface class MusicEngine {
  Stream<EngineSnapshot> get snapshots;
  Future<void> setQueue(List<Track> tracks, int startIndex);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> setVolume(double volume);

  /// Guna [gainsDb] (5 jalur) pada penyama peranti; tiada kesan jika tidak disokong.
  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gainsDb,
  });
  bool get equalizerSupported;
  Future<void> dispose();
}
