import '../../../core/utils/geo.dart';
import 'location_link.dart';
import 'place.dart';

/// True jika teks nampak seperti koordinat atau pautan peta (layak carian terus).
bool looksLikeDirectDestination(String text) {
  final q = text.trim();
  if (q.isEmpty) return false;
  if (_coordinatesOnly(q) != null) return true;
  final uri = _tryUri(q);
  if (uri == null) return false;
  if (isShortMapLink(uri)) return true;
  return sharedLocationFromUri(uri) != null;
}

/// Membina [Place] daripada koordinat atau pautan peta yang sudah ada lat/lng.
///
/// Pautan pendek (`maps.app.goo.gl`) tanpa koordinat dalam URL: pulang null —
/// [resolveDirectDestination] perlu resolve redirect dahulu.
Place? placeFromDirectQuery(String text) {
  final q = text.trim();
  if (q.isEmpty) return null;

  final coords = _coordinatesOnly(q);
  if (coords != null) {
    return Place(
      name: _formatPoint(coords),
      subtitle: '',
      point: coords,
      category: 'coordinates',
    );
  }

  final uri = _tryUri(q);
  if (uri == null) return null;
  final shared = sharedLocationFromUri(uri);
  final point = shared?.point;
  if (point == null) return null;
  final label = shared?.label?.trim();
  return Place(
    name: (label != null && label.isNotEmpty) ? label : _formatPoint(point),
    subtitle: _formatPoint(point),
    point: point,
    category: 'coordinates',
  );
}

/// Jika pautan Maps hanya ada nama (tiada lat/lng), pulangkan label untuk dicari
/// melalui Photon/Nominatim.
String? searchLabelFromMapLink(String text) {
  final uri = _tryUri(text.trim());
  if (uri == null) return null;
  final shared = sharedLocationFromUri(uri);
  if (shared == null || shared.point != null) return null;
  final label = shared.label?.trim();
  return (label != null && label.isNotEmpty) ? label : null;
}

bool isShortMapLink(Uri uri) =>
    uri.scheme == 'https' &&
    const {'maps.app.goo.gl', 'goo.gl'}.contains(uri.host.toLowerCase());

GeoPoint? _coordinatesOnly(String value) {
  final match = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(value);
  if (match == null) return null;
  return _point(match.group(1), match.group(2));
}

GeoPoint? _point(String? latitude, String? longitude) {
  final lat = double.tryParse(latitude ?? '');
  final lng = double.tryParse(longitude ?? '');
  if (lat == null ||
      lng == null ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180) {
    return null;
  }
  return GeoPoint(lat, lng);
}

Uri? _tryUri(String text) {
  final raw = text.trim();
  if (!raw.contains('://') &&
      !raw.startsWith('geo:') &&
      !raw.startsWith('google.navigation:') &&
      !raw.startsWith('waze:') &&
      !raw.startsWith('comgooglemaps:')) {
    // Allow bare maps.app.goo.gl/... pasted without scheme.
    if (raw.startsWith('maps.app.goo.gl/') ||
        raw.startsWith('goo.gl/') ||
        raw.startsWith('www.google.com/maps') ||
        raw.startsWith('maps.google.com/') ||
        raw.startsWith('waze.com/') ||
        raw.startsWith('www.waze.com/') ||
        raw.startsWith('maps.apple.com/')) {
      return Uri.tryParse('https://$raw');
    }
    return null;
  }
  return Uri.tryParse(raw);
}

String _formatPoint(GeoPoint p) =>
    '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
