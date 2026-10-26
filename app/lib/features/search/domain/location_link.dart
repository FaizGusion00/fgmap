import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

@immutable
class SharedLocation {
  const SharedLocation({this.point, this.label});

  final GeoPoint? point;
  final String? label;
}

/// Extracts a destination from common Android/iOS map share links without opening
/// the link in an embedded browser or starting navigation automatically.
SharedLocation? sharedLocationFromUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final isMapScheme = const {
    'geo',
    'google.navigation',
    'waze',
    'comgooglemaps',
  }.contains(scheme);
  final isMapWebLink =
      const {'http', 'https'}.contains(scheme) &&
      const {
        'google.com',
        'www.google.com',
        'maps.google.com',
        'maps.app.goo.gl',
        'goo.gl',
        'waze.com',
        'www.waze.com',
        'maps.apple.com',
      }.contains(uri.host.toLowerCase());
  if (!isMapScheme && !isMapWebLink) return null;

  final params = uri.queryParameters;
  final candidate = switch (scheme) {
    'geo' => uri.path,
    'google.navigation' =>
      uri.queryParameters['q'] ??
          _parameterFromOpaquePath(uri.path, 'q') ??
          uri.path,
    _ =>
      params['destination'] ??
          params['daddr'] ??
          params['ll'] ??
          params['q'] ??
          params['query'],
  };
  final label = _placeLabel(uri, params);
  final preferredQuery = params['query'] ?? params['q'];
  final queryPoint = _coordinates(preferredQuery);
  final invalidGeoQuery =
      scheme == 'geo' &&
      preferredQuery != null &&
      _looksLikeCoordinates(preferredQuery) &&
      queryPoint == null;
  final geoPlaceholder =
      scheme == 'geo' &&
      params.containsKey('q') &&
      _coordinates(uri.path) == const GeoPoint(0, 0);
  final point =
      queryPoint ??
      (invalidGeoQuery || geoPlaceholder
          ? null
          : _coordinates(candidate) ?? _coordinatesFromMapPath(uri.path));
  if (point == null && (label == null || label.isEmpty)) return null;
  return SharedLocation(point: point, label: label);
}

GeoPoint? _coordinatesFromMapPath(String path) {
  final match = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  ).firstMatch(path);
  if (match == null) return null;
  return _point(match.group(1), match.group(2));
}

String? _parameterFromOpaquePath(String path, String name) {
  final match = RegExp('(?:^|[?&])$name=([^&]+)').firstMatch(path);
  return match == null ? null : Uri.decodeComponent(match.group(1)!);
}

GeoPoint? _coordinates(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
  ).firstMatch(value);
  if (match == null) return null;
  return _point(match.group(1), match.group(2));
}

bool _looksLikeCoordinates(String value) =>
    RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?').hasMatch(value);

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

String? _placeLabel(Uri uri, Map<String, String> params) {
  final query =
      params['q'] ??
      params['query'] ??
      params['destination'] ??
      params['daddr'];
  if (query != null) {
    final label = query
        .replaceFirst(
          RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*\(?'),
          '',
        )
        .replaceAll(RegExp(r'\)$'), '')
        .trim();
    if (label.isNotEmpty && _coordinates(query) == null) return label;
    if (label.isNotEmpty && label != query.trim()) return label;
  }

  final segments = uri.pathSegments;
  final placeIndex = segments.indexWhere(
    (segment) => segment == 'place' || segment == 'search',
  );
  if (placeIndex >= 0 && placeIndex + 1 < segments.length) {
    final place = segments[placeIndex + 1].replaceAll('+', ' ').trim();
    if (place.isNotEmpty) return place;
  }
  return null;
}
