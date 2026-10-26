import 'dart:convert';

/// Badan respons sebagai teks, tidak kira bagaimana Dio menyahkodnya.
///
/// Dio menyahkod badan JSON secara automatik berdasarkan `Content-Type` walaupun `ResponseType.plain`
/// diminta, jadi hos yang menghantar `application/json` (R2, server Valhalla awam) memberi `Map`, manakala
/// hos yang menghantar `application/octet-stream` (GitHub Releases) memberi `String`. Pemanggil meminta
/// `ResponseType.bytes` untuk mendapat bait mentah; fungsi ini juga menerima bentuk lain supaya
/// tidak bergantung pada tingkah laku itu.
String? responseText(Object? data) {
  if (data == null) return null;
  if (data is String) return data;
  if (data is List<int>) return utf8.decode(data, allowMalformed: true);
  try {
    return jsonEncode(data);
  } on Object {
    return null;
  }
}
