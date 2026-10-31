import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Bandar untuk pilihan manual apabila lokasi tidak tersedia. Koordinat pusat bandar (anggaran
/// ~1 km sudah memadai untuk waktu solat).
@immutable
class MalaysianCity {
  const MalaysianCity(this.name, this.state, this.point);

  final String name;
  final String state;
  final GeoPoint point;
}

const malaysianCities = <MalaysianCity>[
  MalaysianCity('Kuala Lumpur', 'WP Kuala Lumpur', GeoPoint(3.139, 101.687)),
  MalaysianCity('Putrajaya', 'WP Putrajaya', GeoPoint(2.926, 101.696)),
  MalaysianCity('Shah Alam', 'Selangor', GeoPoint(3.073, 101.518)),
  MalaysianCity('Johor Bahru', 'Johor', GeoPoint(1.493, 103.741)),
  MalaysianCity('Ipoh', 'Perak', GeoPoint(4.597, 101.090)),
  MalaysianCity('George Town', 'Pulau Pinang', GeoPoint(5.414, 100.329)),
  MalaysianCity('Alor Setar', 'Kedah', GeoPoint(6.121, 100.368)),
  MalaysianCity('Kangar', 'Perlis', GeoPoint(6.441, 100.198)),
  MalaysianCity('Kota Bharu', 'Kelantan', GeoPoint(6.125, 102.238)),
  MalaysianCity('Kuala Terengganu', 'Terengganu', GeoPoint(5.330, 103.137)),
  MalaysianCity('Kuantan', 'Pahang', GeoPoint(3.808, 103.326)),
  MalaysianCity('Seremban', 'Negeri Sembilan', GeoPoint(2.726, 101.938)),
  MalaysianCity('Melaka', 'Melaka', GeoPoint(2.196, 102.251)),
  MalaysianCity('Kuching', 'Sarawak', GeoPoint(1.553, 110.359)),
  MalaysianCity('Sibu', 'Sarawak', GeoPoint(2.287, 111.831)),
  MalaysianCity('Miri', 'Sarawak', GeoPoint(4.399, 113.991)),
  MalaysianCity('Kota Kinabalu', 'Sabah', GeoPoint(5.980, 116.073)),
  MalaysianCity('Sandakan', 'Sabah', GeoPoint(5.840, 118.117)),
  MalaysianCity('Tawau', 'Sabah', GeoPoint(4.245, 117.891)),
  MalaysianCity('Labuan', 'WP Labuan', GeoPoint(5.283, 115.241)),
  MalaysianCity('Langkawi', 'Kedah', GeoPoint(6.350, 99.800)),
];

MalaysianCity? cityNamed(String? name) {
  for (final c in malaysianCities) {
    if (c.name == name) return c;
  }
  return null;
}

/// Bandar terdekat dengan [p].
MalaysianCity nearestCity(GeoPoint p) {
  var best = malaysianCities.first;
  var bestD = double.infinity;
  for (final c in malaysianCities) {
    final d = distanceMeters(p, c.point);
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  return best;
}
