import 'contact.dart';

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
///
/// [contacts] are the task's linked People (the `task_contacts` → `contacts` embed), managed like
/// an event's attendees. Only id/name/company are populated from the embed. Written atomically by
/// the task-write RPCs (`p_contacts`); a soft-deleted (RLS-hidden) contact comes back as a null
/// `contacts` on the join row and is skipped here (parity with [Event.attendees]).
class Task {
  final String id;
  final String title;
  final bool isDone;
  final String? notes;

  /// The linked People. Only id/name/company are populated from the embed.
  final List<Contact> contacts;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Task({
    required this.id,
    required this.title,
    this.isDone = false,
    this.notes,
    this.contacts = const [],
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// A not-yet-persisted task. Uses an empty id — the DB assigns the real one. Always live and
  /// not-done: new tasks are created active. [notes] and [contacts] are optional (a new task may
  /// carry both).
  const Task.draft({required this.title, this.notes, this.contacts = const []})
    : id = '',
      isDone = false,
      createdAt = null,
      updatedAt = null,
      deletedAt = null;

  factory Task.fromJson(Map<String, dynamic> json) {
    // task_contacts is a to-many array; each row's `contacts` is a to-ONE object (or null when
    // that contact was soft-deleted and hidden by RLS — skip those). Mirrors Event.fromJson.
    final contacts = <Contact>[];
    for (final row in (json['task_contacts'] as List? ?? const [])) {
      final c = (row as Map<String, dynamic>)['contacts'];
      if (c is Map<String, dynamic>) contacts.add(Contact.fromJson(c));
    }
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['is_done'] as bool? ?? false,
      notes: json['notes'] as String?,
      contacts: contacts,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      deletedAt: _parseDate(json['deleted_at']),
    );
  }

  /// Params for the `create_task` RPC (Decision 26 — all writes go through RPCs). Matches the
  /// `create_task(p_title, p_notes, p_contacts)` signature: `p_title` is trimmed here
  /// (belt-and-suspenders with the server, which also trims); `p_notes` is sent verbatim (possibly
  /// null — the server normalizes blank/whitespace to NULL); `p_contacts` is the linked-People id
  /// list (empty when none). Follows the project's RPC-write convention (as [Comment] does, though
  /// its param map now lives in the repo): `toRpcParams` matches the `create_*` shape and `is_done`
  /// is NOT included because `create_task` creates live+not-done. Updates go through `update_task`
  /// with an explicit `{p_id, p_title, p_is_done, p_notes, p_contacts}` built in the repo, never
  /// this map.
  Map<String, dynamic> toRpcParams() => {
    'p_title': title.trim(),
    'p_notes': notes,
    'p_contacts': [for (final c in contacts) c.id],
  };

  /// Archived == soft-deleted. NULL `deleted_at` means a live task.
  bool get isArchived => deletedAt != null;

  /// Rename / edit notes / edit People / toggle done. A null [notes] argument means "keep the
  /// current notes" (matching [title]); the form clears notes by passing `''`, which the server
  /// normalizes to NULL on the round-trip — so this can't represent an explicit clear, and doesn't
  /// need to. [contacts] defaults to `this.contacts` — LOAD-BEARING: both complete-toggle paths
  /// call `copyWith(isDone: …)` WITHOUT contacts, and `update` re-sends the whole `p_contacts` set
  /// (delete-then-reinsert), so preserving them here is what stops a toggle from wiping the links.
  Task copyWith({
    String? title,
    bool? isDone,
    String? notes,
    List<Contact>? contacts,
  }) => Task(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    notes: notes ?? this.notes,
    contacts: contacts ?? this.contacts,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
