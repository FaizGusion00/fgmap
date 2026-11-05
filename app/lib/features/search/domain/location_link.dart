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
        // Google Malaysia (carian dalam app dihantar ke google.com.my).
        'google.com.my',
        'www.google.com.my',
        'maps.google.com.my',
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
  // Google Search "Arah" kadang-kadang menghantar `destination=Nama, Alamat @3.21,101.75`.
  final at = RegExp(
    r'@\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(params['destination'] ?? params['daddr'] ?? '');
  if (scheme != 'geo' && scheme != 'google.navigation' && at != null) {
    final p = _point(at.group(1), at.group(2));
    final name = (params['destination'] ?? params['daddr'])!
        .substring(0, at.start)
        .trim()
        .replaceFirst(RegExp(r',\s*$'), '');
    if (p != null) {
      return SharedLocation(point: p, label: sanitizeSharedLabel(name));
    }
  }
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
          : _coordinates(candidate) ??
                // Pin tempat (`!3d<lat>!4d<lng>` dalam data=) lebih tepat daripada `@` (pusat peta).
                _pinFromData(uri) ??
                _coordinatesFromMapPath(uri.path));
  final cleanLabel = sanitizeSharedLabel(label);
  if (point == null && (cleanLabel == null || cleanLabel.isEmpty)) return null;
  return SharedLocation(point: point, label: cleanLabel);
}

GeoPoint? _pinFromData(Uri uri) {
  final match = RegExp(
    r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
  ).firstMatch(Uri.decodeFull(uri.toString()));
  if (match == null) return null;
  return _point(match.group(1), match.group(2));
}

/// Pautan dalam pelayar carian yang patut dibuka dalam FGMaps (bukan dimuat dalam pelayar): halaman
/// Google Maps, pautan pendek peta, dan skema app peta. Halaman carian Google biasa (`/search?q=`)
/// TIDAK termasuk walaupun ada `q`.
bool isMapHandoffUrl(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (const {'geo', 'google.navigation', 'comgooglemaps'}.contains(scheme)) {
    return true;
  }
  if (scheme != 'http' && scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host == 'maps.app.goo.gl') return true;
  if (host == 'goo.gl') return uri.path.startsWith('/maps');
  if (host.startsWith('maps.google.')) return true;
  final google = RegExp(r'^(?:www\.)?google\.com(?:\.my)?$').hasMatch(host);
  return google && uri.path.startsWith('/maps');
}

/// Pautan peta daripada `intent://` (butang "Arah" Google pada telefon membuka app Google Maps):
/// `S.browser_fallback_url` jika ada, jika tidak bina semula `https://<hos><laluan>`.
Uri? mapLinkFromIntent(String url) {
  if (!url.startsWith('intent://')) return null;
  final hash = url.indexOf('#Intent;');
  final fallback = RegExp(
    r'S\.browser_fallback_url=([^;]+)',
  ).firstMatch(hash < 0 ? '' : url.substring(hash));
  if (fallback != null) {
    final u = Uri.tryParse(Uri.decodeComponent(fallback.group(1)!));
    if (u != null && sharedLocationFromUri(u) != null) return u;
  }
  final body = url.substring('intent://'.length, hash < 0 ? url.length : hash);
  final scheme = RegExp(r'scheme=([a-z.]+);').firstMatch(url)?.group(1);
  final rebuilt = Uri.tryParse(
    scheme == 'geo' || scheme == 'google.navigation'
        ? '$scheme:$body'
        : 'https://$body',
  );
  return rebuilt != null && sharedLocationFromUri(rebuilt) != null
      ? rebuilt
      : null;
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
  // `/maps/dir/<dari>/<ke>/@…`: destinasi ialah segmen bernama terakhir selepas `dir`.
  final dirIndex = segments.indexOf('dir');
  if (dirIndex >= 0) {
    for (final seg in segments.skip(dirIndex + 1).toList().reversed) {
      final t = seg.replaceAll('+', ' ').trim();
      if (t.isEmpty || t.startsWith('@') || t.startsWith('data=')) continue;
      if (_coordinates(t) != null) continue;
      return t;
    }
  }
  return null;
}

/// Membersihkan label daripada pautan luaran yang tidak dipercayai sebelum dipaparkan atau dicari:
/// membuang aksara kawalan dan aksara arah teks dua hala (boleh memalsukan teks yang dipaparkan),
/// mengemas ruang kosong dan menghad panjang kepada [maxSharedLabelLength] aksara.
String? sanitizeSharedLabel(String? label) {
  if (label == null) return null;
  final cleaned = label
      .replaceAll(
        RegExp(
          '[\\u0000-\\u001F\\u007F-\\u009F\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069]',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  if (runes.length <= maxSharedLabelLength) return cleaned;
  return '${String.fromCharCodes(runes.take(maxSharedLabelLength)).trimRight()}…';
}

const maxSharedLabelLength = 80;
