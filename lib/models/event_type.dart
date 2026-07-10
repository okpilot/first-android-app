/// An event type (category) — mirrors the `public.event_types` table.
///
/// Pure Dart (no Flutter import, like [Contact]/[Event]): the colour is kept as the raw
/// `#RRGGBB` hex string exactly as the DB stores it, and the UI layer maps it to a
/// Flutter `Color` at render time. Keeping it widget-free means it unit-tests without a
/// widget tree, and the model never depends on `dart:ui`.
class EventType {
  final String id;
  final String name;

  /// A `#RRGGBB` (6-digit) hex string. Guaranteed well-formed when the instance comes
  /// from the DB via [fromJson] (which falls back to a neutral grey rather than keeping
  /// garbage); the raw const constructor cannot re-validate — const forbids the regex
  /// call — so in-app callers must pass a clean value (they build it from the palette).
  final String colorHex;

  const EventType({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  /// A not-yet-persisted type. Empty id — the DB assigns the real one.
  const EventType.draft({required this.name, required this.colorHex}) : id = '';

  /// Only the client-writable fields, for the direct-under-RLS insert/update. Name is
  /// trimmed here (server doesn't normalise it); colour is already a clean `#RRGGBB`.
  Map<String, dynamic> toWrite() => {'name': name.trim(), 'color': colorHex};

  EventType copyWith({String? name, String? colorHex}) => EventType(
    id: id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
  );

  factory EventType.fromJson(Map<String, dynamic> json) => EventType(
    id: json['id'] as String,
    name: json['name'] as String,
    colorHex: _validHex(json['color']),
  );

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Guard so a malformed or missing colour never throws (and never blows up a whole
  /// `fetchAll`): anything that isn't a clean `#RRGGBB` becomes a neutral grey.
  static String _validHex(Object? v) =>
      (v is String && _hex.hasMatch(v)) ? v : '#888888';
}
