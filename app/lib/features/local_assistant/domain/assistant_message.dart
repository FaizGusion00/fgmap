import 'package:flutter/foundation.dart';

import '../../search/domain/nearby_category.dart';

/// Satu mesej dalam sejarah sembang pembantu.
@immutable
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.at,
    this.sources = const [],
    this.actions = const [],
    this.places = const [],
    this.notice,
    this.local = false,
  });

  final AssistantRole role;
  final String text;
  final DateTime? at;

  /// Rujukan jawapan (FGMuslim): dipaparkan sebagai kad yang boleh dilipat, bukan URL dalam teks.
  final List<AnswerSource> sources;

  /// Butang tindakan di bawah jawapan (cth. "Mula navigasi", "Laluan ke ...").
  final List<AssistantAction> actions;

  /// Tempat yang dijumpai (carian/berdekatan): dipaparkan sebagai kad dengan jarak dan butang "Pergi".
  final List<ChatPlace> places;

  /// Nota tetap di atas jawapan (penafian, had kadar). Dipaparkan dalam bahasa UI semasa.
  final AnswerNotice? notice;

  /// Jawapan dijana oleh app (templat penghala, Wikipedia), bukan oleh model. Tidak dimainkan semula
  /// kepada model: model kecil menyalin jawapan lama sebagai jawapan soalan baharu.
  final bool local;

  AssistantMessage copyWith({
    String? text,
    List<AnswerSource>? sources,
    List<AssistantAction>? actions,
    List<ChatPlace>? places,
    bool? local,
  }) => AssistantMessage(
    role: role,
    text: text ?? this.text,
    at: at,
    sources: sources ?? this.sources,
    actions: actions ?? this.actions,
    places: places ?? this.places,
    notice: notice,
    local: local ?? this.local,
  );

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    if (at != null) 'at': at!.toIso8601String(),
    if (sources.isNotEmpty) 'sources': [for (final s in sources) s.toJson()],
    if (actions.isNotEmpty) 'actions': [for (final a in actions) a.toJson()],
    if (places.isNotEmpty) 'places': [for (final p in places) p.toJson()],
    if (notice != null) 'notice': notice!.name,
    if (local) 'local': true,
  };

  static AssistantMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final roleName = raw['role']?.toString();
    final text = raw['text']?.toString() ?? '';
    final role = AssistantRole.values
        .where((r) => r.name == roleName)
        .firstOrNull;
    if (role == null) return null;
    final sourcesRaw = raw['sources'];
    final actionsRaw = raw['actions'];
    final placesRaw = raw['places'];
    final notice = AnswerNotice.values
        .where((n) => n.name == raw['notice']?.toString())
        .firstOrNull;
    final sources = sourcesRaw is List
        ? [for (final e in sourcesRaw) ?AnswerSource.fromJson(e)]
        : const <AnswerSource>[];
    // Teks kosong hanya sah untuk jawapan pembantu yang ada nota atau sumber
    // (had kadar, tidak berasas, pautan fatwa). Peranan lain mesti ada teks.
    if (text.trim().isEmpty &&
        (role != AssistantRole.assistant ||
            (sources.isEmpty && notice == null))) {
      return null;
    }
    return AssistantMessage(
      role: role,
      text: text,
      at: DateTime.tryParse(raw['at']?.toString() ?? ''),
      sources: sources,
      actions: actionsRaw is List
          ? [for (final e in actionsRaw) ?AssistantAction.fromJson(e)]
          : const [],
      places: placesRaw is List
          ? [for (final e in placesRaw) ?ChatPlace.fromJson(e)]
          : const [],
      notice: notice,
      local: raw['local'] == true,
    );
  }
}

enum AssistantRole { user, assistant, system }

enum AnswerSourceKind { classical, fatwa }

/// Satu rujukan berpetikan (kitab klasik islamic.app atau fatwa deen.ai).
@immutable
class AnswerSource {
  const AnswerSource({
    required this.kind,
    required this.title,
    required this.url,
    this.n,
    this.subtitle,
    this.original,
  });

  final AnswerSourceKind kind;

  /// Nombor petikan dalam jawapan ("[2]"), jika ada.
  final int? n;
  final String title;

  /// Bab dan halaman, atau mazhab dan penerbit fatwa.
  final String? subtitle;

  /// Tajuk asal (cth. Arab) bila [title] ialah transliterasi.
  final String? original;
  final String url;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'url': url,
    if (n != null) 'n': n,
    if (subtitle != null) 'subtitle': subtitle,
    if (original != null) 'original': original,
  };

  static AnswerSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title']?.toString();
    final url = raw['url']?.toString();
    if (title == null || url == null) return null;
    return AnswerSource(
      kind:
          AnswerSourceKind.values
              .where((k) => k.name == raw['kind']?.toString())
              .firstOrNull ??
          AnswerSourceKind.classical,
      title: title,
      url: url,
      n: (raw['n'] as num?)?.toInt(),
      subtitle: raw['subtitle']?.toString(),
      original: raw['original']?.toString(),
    );
  }
}

/// Nota piawai FGMuslim (diterjemah semasa dipaparkan, bukan disimpan sebagai teks).
enum AnswerNotice { classicalSummary, rateLimited, notGrounded, unreachable }

enum AssistantActionKind {
  /// Tutup halaman AI dan tunjuk pratonton laluan pada peta.
  showRoute,

  /// Mula navigasi pada laluan terpilih.
  startNavigation,

  /// Rancang laluan ke tempat ini ([AssistantAction.label], [lat], [lng]).
  routeTo,

  /// Cadangan soalan: mengetik menghantar [AssistantAction.label] sebagai mesej pengguna.
  ask,
}

@immutable
class AssistantAction {
  const AssistantAction(this.kind, {this.label, this.lat, this.lng});

  final AssistantActionKind kind;
  final String? label;
  final double? lat;
  final double? lng;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (label != null) 'label': label,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };

  static AssistantAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = AssistantActionKind.values
        .where((k) => k.name == raw['kind']?.toString())
        .firstOrNull;
    if (kind == null) return null;
    return AssistantAction(
      kind,
      label: raw['label']?.toString(),
      lat: (raw['lat'] as num?)?.toDouble(),
      lng: (raw['lng'] as num?)?.toDouble(),
    );
  }
}

/// Satu tempat dalam jawapan carian/berdekatan.
@immutable
class ChatPlace {
  const ChatPlace({
    required this.name,
    required this.lat,
    required this.lng,
    this.area,
    this.distanceM,
    this.category,
  });

  final String name;

  /// Kawasan/jalan ringkas (bahagian pertama alamat), untuk membezakan dua "Caltex" yang berlainan.
  final String? area;
  final double lat;
  final double lng;

  /// Jarak lurus dari pengguna, dalam meter.
  final int? distanceM;

  /// Menentukan ikon kad; null untuk carian nama biasa.
  final NearbyCategory? category;

  Map<String, Object?> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    if (area != null) 'area': area,
    if (distanceM != null) 'distance_m': distanceM,
    if (category != null) 'category': category!.name,
  };

  static ChatPlace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString();
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    if (name == null || name.isEmpty || lat == null || lng == null) return null;
    return ChatPlace(
      name: name,
      lat: lat,
      lng: lng,
      area: raw['area']?.toString(),
      distanceM: (raw['distance_m'] as num?)?.round(),
      category: NearbyCategory.values
          .where((c) => c.name == raw['category']?.toString())
          .firstOrNull,
    );
  }
}
