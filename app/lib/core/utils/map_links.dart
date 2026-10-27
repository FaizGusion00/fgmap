import 'geo.dart';

/// Pautan OpenStreetMap ke satu titik; dibuka di mana-mana pelayar dan boleh dibaca penerima tanpa app
/// ini. 5 perpuluhan (~1 m).
String osmPointLink(GeoPoint p, {int zoom = 17}) {
  final lat = p.lat.toStringAsFixed(5);
  final lng = p.lng.toStringAsFixed(5);
  return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=$zoom/$lat/$lng';
}

/// "3.15790, 101.71160".
String coordinateText(GeoPoint p) =>
    '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
