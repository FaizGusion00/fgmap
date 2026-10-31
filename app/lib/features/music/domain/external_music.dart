/// Pautan carian ke app muzik yang pengguna sudah ada. FGMaps hanya membuka carian; lagu dimain
/// oleh app itu dengan akaun pengguna sendiri. Pautan HTTPS biasa: telefon membukanya terus dalam
/// app jika dipasang, jika tidak dalam pelayar.
Uri spotifySearchUri(String query) {
  final q = query.trim();
  return Uri(
    scheme: 'https',
    host: 'open.spotify.com',
    pathSegments: ['search', if (q.isNotEmpty) q],
  );
}

Uri youtubeMusicSearchUri(String query) {
  final q = query.trim();
  return Uri(
    scheme: 'https',
    host: 'music.youtube.com',
    path: q.isEmpty ? '/' : '/search',
    queryParameters: q.isEmpty ? null : {'q': q},
  );
}
