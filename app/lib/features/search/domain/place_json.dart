import '../../../core/utils/geo.dart';
import 'place.dart';

/// Penyirian [Place] untuk storan setempat (sejarah, tempat disimpan). Medan OSM bersifat pilihan dan
/// hanya ditulis jika ada, jadi data lama (tanpa medan itu) tetap sah dan bentuknya tidak berubah.
Map<String, Object?> placeToJson(Place place) => {
  'name': place.name,
  'subtitle': place.subtitle,
  'lat': place.point.lat,
  'lng': place.point.lng,
  'category': place.category,
  if (place.osmKey != null) 'osmKey': place.osmKey,
  if (place.osmType != null) 'osmType': place.osmType,
  if (place.osmId != null) 'osmId': place.osmId,
  if (place.extentDiagonalM != null) 'extent': place.extentDiagonalM,
  if (place.countryCode != null) 'cc': place.countryCode,
};

/// Null jika [json] rosak atau koordinat tidak sah.
Place? placeFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final name = json['name'];
  final subtitle = json['subtitle'];
  final lat = json['lat'];
  final lng = json['lng'];
  final category = json['category'];
  if (name is! String ||
      subtitle is! String ||
      lat is! num ||
      lng is! num ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180 ||
      (category != null && category is! String)) {
    return null;
  }
  String? str(String key) => json[key] is String ? json[key] as String : null;
  final osmType = str('osmType');
  final extent = json['extent'];
  return Place(
    name: name,
    subtitle: subtitle,
    point: GeoPoint(lat.toDouble(), lng.toDouble()),
    category: category is String ? category : null,
    osmKey: str('osmKey'),
    osmType: osmType == 'N' || osmType == 'W' || osmType == 'R'
        ? osmType
        : null,
    osmId: json['osmId'] is int ? json['osmId'] as int : null,
    extentDiagonalM: extent is num && extent.isFinite && extent > 0
        ? extent.toDouble()
        : null,
    countryCode: str('cc'),
  );
}
