/// A task — mirrors the `public.tasks` table (Decision 27).
///
/// Pure Dart (no Flutter import) so it unit-tests without a widget tree. The server owns
/// `id`, `created_at`, `updated_at`, and `deleted_at`; the client writes only `title` and
/// `is_done` (see [toRpcParams]). All writes — add / complete / edit / archive / restore — go
/// through SECURITY DEFINER RPCs (Decision 26); `deleted_at` is set server-side by the archive /
/// restore RPCs, never by the client.
///
/// Like [Comment], this model reads `deleted_at` back: archived tasks (`deleted_at != null`) stay
/// visible under a "Show archived" section rather than being hidden by RLS, so the UI needs to
/// know which is which ([isArchived]).
///
/// [notes] is a single optional freeform description on the task itself (a scalar column) — set on
/// the form, shown on the detail. Distinct from the separate task-comments log. NULL means no
/// notes; the server normalizes a blank/whitespace box to NULL, so the client never stores `''`.
class Task {
  final String id;
  final String title;
  final bool isDone;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Task({
    required this.id,
    required this.title,
    this.isDone = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// A not-yet-persisted task. Uses an empty id — the DB assigns the real one. Always live and
  /// not-done: new tasks are created active. [notes] is optional (a new task may carry notes).
  const Task.draft({required this.title, this.notes})
    : id = '',
      isDone = false,
      createdAt = null,
      updatedAt = null,
      deletedAt = null;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    isDone: json['is_done'] as bool? ?? false,
    notes: json['notes'] as String?,
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
    deletedAt: _parseDate(json['deleted_at']),
  );

  /// Params for the `create_task` RPC (Decision 26 — all writes go through RPCs). Matches the
  /// `create_task(p_title, p_notes)` signature: `p_title` is trimmed here (belt-and-suspenders
  /// with the server, which also trims); `p_notes` is sent verbatim (possibly null — the server
  /// normalizes blank/whitespace to NULL). Mirrors the [Comment.toRpcParams] convention:
  /// `toRpcParams` matches the `create_*` shape; `is_done` is NOT included because `create_task`
  /// creates live+not-done. Updates go through `update_task` with an explicit
  /// `{p_id, p_title, p_is_done, p_notes}` built in the repo, never this map.
  Map<String, dynamic> toRpcParams() => {
    'p_title': title.trim(),
    'p_notes': notes,
  };

  /// Archived == soft-deleted. NULL `deleted_at` means a live task.
  bool get isArchived => deletedAt != null;

  /// Rename / edit notes / toggle done. A null [notes] argument means "keep the current notes"
  /// (matching [title]); the form clears notes by passing `''`, which the server normalizes to
  /// NULL on the round-trip — so this can't represent an explicit clear, and doesn't need to.
  Task copyWith({String? title, bool? isDone, String? notes}) => Task(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
