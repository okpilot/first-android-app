import '../util/ids.dart';

/// A task category (user-owned tag) — mirrors the `public.task_categories` table.
///
/// Pure Dart (no Flutter import, like [Contact]/[Task]/[EventType]): the colour is kept as the raw
/// `#RRGGBB` hex string exactly as the DB stores it, and the UI layer maps it to a Flutter `Color`
/// at render time (reusing the shared event-type palette helpers). Keeping it widget-free means it
/// unit-tests without a widget tree, and the model never depends on `dart:ui`.
///
/// A deliberate parallel of [EventType] rather than a shared abstraction: task categories are their
/// OWN taxonomy (the user chose independent lists) and will diverge in Slice B (delete semantics),
/// so they stay a separate model — same call as event vs task comments.
class TaskCategory {
  final String id;
  final String name;

  /// A `#RRGGBB` (6-digit) hex string. Guaranteed well-formed when the instance comes from the DB
  /// via [fromJson] (which falls back to a neutral grey rather than keeping garbage); the raw const
  /// constructor cannot re-validate — const forbids the regex call — so in-app callers must pass a
  /// clean value (they build it from the palette).
  final String colorHex;

  const TaskCategory({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  /// A not-yet-persisted category. Mints a client-side id up front (issue #9) so
  /// `create_task_category` is idempotent on it; pass [id] to reuse one across a retry.
  factory TaskCategory.draft({
    String? id,
    required String name,
    required String colorHex,
  }) => TaskCategory(id: id ?? newEntityId(), name: name, colorHex: colorHex);

  /// Params for the `create_task_category` / `update_task_category` RPCs (all writes go through RPCs).
  /// `p_name` is trimmed here (belt-and-suspenders with the server, which also trims); `p_color` is
  /// already a clean `#RRGGBB` built from the palette. `p_id` is the client-minted id —
  /// `create_task_category` inserts it with `on conflict (id) do nothing` (idempotent, issue #9),
  /// and `update_task_category` uses it as the target row.
  Map<String, dynamic> toRpcParams() => {
    'p_id': id,
    'p_name': name.trim(),
    'p_color': colorHex,
  };

  TaskCategory copyWith({String? name, String? colorHex}) => TaskCategory(
    id: id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
  );

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    colorHex: _validHex(json['color']),
  );

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Guard so a malformed or missing colour never throws (and never blows up a whole `fetchAll`):
  /// anything that isn't a clean `#RRGGBB` becomes a neutral grey.
  static String _validHex(Object? v) =>
      (v is String && _hex.hasMatch(v)) ? v : '#888888';
}
