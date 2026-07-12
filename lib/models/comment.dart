/// A comment on an event — mirrors the `public.event_comments` table.
///
/// Pure Dart (no Flutter import) so it unit-tests without a widget tree. The server owns
/// `id`, `created_at`, `updated_at`, and `deleted_at`; the client writes only `event_id` +
/// `body` (see [toRpcParams]). All writes — add / edit / archive / unarchive — go through
/// SECURITY DEFINER RPCs (Decision 26); `deleted_at` is set server-side by the archive /
/// restore RPCs, never by the client.
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

  /// Params for the `create_comment` RPC (Decision 26 — all writes go through RPCs). Only the
  /// client-writable fields: `p_body` is trimmed here (belt-and-suspenders with the server,
  /// which also trims). Edits go through `update_comment` with `{p_id, p_body}` — body-only, so
  /// an edit can't move a comment to another event — and never re-send `p_event_id`.
  Map<String, dynamic> toRpcParams() => {
    'p_event_id': eventId,
    'p_body': body.trim(),
  };

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
