import '../domain/music_repository.dart';
import '../domain/track.dart';

/// Stesen yang URL strimnya disahkan menyiar audio (HTTPS, sambungan sebenar dan segmen audio
/// diambil) tetapi tiada, atau tidak berfungsi, dalam Radio Browser. Digabung ke hadapan senarai
/// kawasannya; stesen Radio Browser dengan nama sama digantikan kerana URL di sini yang disahkan.
///
/// Hanya URL awam yang digunakan oleh laman/aplikasi stesen itu sendiri atau penyedia strim
/// (Revma, StreamTheWorld); tiada token disembunyikan atau halangan wilayah dipintas. Stesen yang
/// hanya wujud melalui radiko (J-WAVE, TOKYO FM, NACK5; terkunci kepada Japan) sengaja tiada.
/// Semak semula dengan `tools/radio/check_curated_stations.py`; stesen yang gagal tetap tenggelam
/// ke bawah senarai pengguna melalui `RadioHealth`.
class CuratedStation {
  const CuratedStation({
    required this.id,
    required this.name,
    required this.stream,
    this.region = RadioRegion.malaysia,
    this.tags,
    this.homepage,
  });

  /// Unik dan tetap (menjadi sebahagian kunci trek dan kegemaran tersimpan).
  final String id;
  final String name;
  final String stream;
  final RadioRegion region;
  final String? tags;
  final String? homepage;

  Track toTrack() => Track(
    id: 'curated-$id',
    source: TrackSource.radio,
    title: name,
    artist: tags,
    streamUri: Uri.parse(stream),
    permalink: homepage == null ? null : Uri.parse(homepage!),
  );
}

const curatedStations = <CuratedStation>[
  // Astro Radio (Revma). ID daripada direktori awam; stesen disahkan menyiar lagu Melayu.
  CuratedStation(
    id: 'era',
    name: 'ERA',
    stream: 'https://stream.rcs.revma.com/crec9cmbv4uvv',
    tags: 'malay, pop',
  ),
  CuratedStation(
    id: 'thr-gegar',
    name: 'THR Gegar',
    stream: 'https://stream.rcs.revma.com/cn0zcqsbv4uvv',
    tags: 'malay',
  ),
  // StreamTheWorld: `icy-name` strim sepadan dengan nama stesen.
  CuratedStation(
    id: 'suria',
    name: 'Suria FM',
    stream:
        'https://playerservices.streamtheworld.com/api/livestream-redirect/SURIA_FMAAC_SC',
    tags: 'malay',
    homepage: 'https://www.suria.my',
  ),
  CuratedStation(
    id: 'sabah-fm',
    name: 'Sabah FM',
    stream:
        'https://playerservices.streamtheworld.com/api/livestream-redirect/SABAH_FMAAC_SC',
    tags: 'malay',
  ),
  CuratedStation(
    id: 'sarawak-fm',
    name: 'Sarawak FM',
    stream:
        'https://playerservices.streamtheworld.com/api/livestream-redirect/SARAWAK_FMAAC_SC',
    tags: 'malay',
  ),
];

/// Nama dinormalkan untuk membandingkan stesen: huruf kecil, alfanumerik sahaja, tanpa "fm",
/// "radio" dan "malaysia" ("Suria FM" == "SURIA FM Malaysia").
String normalizeStationName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('fm|radio|malaysia'), '')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// [other] ialah stesen yang sama dengan [curated] jika sama, atau hanya ditambah frekuensi
/// ("Suria FM 105.1"); "Red FM Kuching" bukan "Red FM" kerana akhirannya bukan nombor.
bool sameStation(String curated, String other) =>
    curated.isNotEmpty &&
    other.startsWith(curated) &&
    RegExp(r'^\d*$').hasMatch(other.substring(curated.length));
