/// A comment on a parent record (an event or a task) — mirrors an `*_comments` table
/// (`event_comments`, `task_comments`). **Parent-agnostic:** [parentId] is the FK to whichever
/// record owns the comment, delivered by each repository as a `parent_id` select alias so this
/// one model reads either table. The shared `CommentsSection` widget renders it for any parent.
///
/// Pure Dart (no Flutter import) so it unit-tests without a widget tree. The server owns
/// `id`, `created_at`, `updated_at`, and `deleted_at`; the client writes only the parent FK +
/// `body`. All writes — add / edit / archive / unarchive — go through SECURITY DEFINER RPCs
/// (Decision 26); the RPC param-building lives in the repositories (each knows its own RPC
/// signature — `p_event_id` vs `p_task_id`), not on the model. `deleted_at` is set server-side
/// by the archive / restore RPCs, never by the client.
///
/// Unlike most models, this one reads `deleted_at` back: archived comments
/// (`deleted_at != null`) stay visible under a "Show archived" toggle rather than being
/// hidden by RLS, so the UI needs to know which is which ([isArchived]).
class Comment {
  final String id;
  final String parentId;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Comment({
    required this.id,
    required this.parentId,
    required this.body,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// A not-yet-persisted comment. Uses an empty id — the DB assigns the real one.
  const Comment.draft({required this.parentId, required this.body})
    : id = '',
      createdAt = null,
      updatedAt = null,
      deletedAt = null;

  /// Reads the parent FK back as `parent_id` — each repository aliases its own FK column
  /// (`parent_id:event_id` / `parent_id:task_id`) in the select, so this one factory parses
  /// rows from either `*_comments` table.
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    parentId: json['parent_id'] as String,
    body: json['body'] as String,
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    deletedAt: _parseDate(json['deleted_at']),
  );

  /// Archived == soft-deleted. NULL `deleted_at` means a live comment.
  bool get isArchived => deletedAt != null;

  Comment copyWith({String? body}) => Comment(
    id: id,
    parentId: parentId,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
