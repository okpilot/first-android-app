/// A comment on an event — mirrors the `public.event_comments` table.
///
/// Pure Dart (no Flutter import) so it unit-tests without a widget tree. The server owns
/// `id`, `created_at`, `updated_at`, and `deleted_at`; the client writes only `event_id` +
/// `body` (see [toWrite]). Archive / unarchive set `deleted_at` directly in the repository.
///
/// Unlike every other model, this one reads `deleted_at` back: archived comments
/// (`deleted_at != null`) stay visible under a "Show archived" toggle rather than being
/// hidden by RLS, so the UI needs to know which is which ([isArchived]).
class Comment {
  final String id;
  final String eventId;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Comment({
    required this.id,
    required this.eventId,
    required this.body,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// A not-yet-persisted comment. Uses an empty id — the DB assigns the real one.
  const Comment.draft({required this.eventId, required this.body})
    : id = '',
      createdAt = null,
      updatedAt = null,
      deletedAt = null;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    eventId: json['event_id'] as String,
    body: json['body'] as String,
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    deletedAt: _parseDate(json['deleted_at']),
  );

  /// Only the client-writable fields. The server owns id/timestamps; `deleted_at` is set
  /// directly by the repository's archive/unarchive, never here.
  Map<String, dynamic> toWrite() => {'event_id': eventId, 'body': body.trim()};

  /// Archived == soft-deleted. NULL `deleted_at` means a live comment.
  bool get isArchived => deletedAt != null;

  Comment copyWith({String? body}) => Comment(
    id: id,
    eventId: eventId,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
