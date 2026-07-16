import '../util/ids.dart';
import 'contact.dart';
import 'task_category.dart';

/// A task — mirrors the `public.tasks` table (Decision 27).
///
/// Pure Dart (no Flutter import) so it unit-tests without a widget tree. The server owns
/// `created_at`, `updated_at`, and `deleted_at`; the client writes `title`, `is_done`, and `id` —
/// a new task mints its id client-side (see [Task.draft]) so `create_task` is idempotent on it
/// (issue #9). See [toRpcParams]. All writes — add / complete / edit / archive / restore — go
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
///
/// [importance] is a fixed 0..3 priority marker (0 = none, 1/2/3 = !/!!/!!!) — the `importance`
/// scalar column (Decision 38). A fixed semantic scale the UI maps to a hue, NOT user-owned
/// colour-as-data. Written by the task-write RPCs (`p_importance`) and used to sort active tasks
/// (highest first). The DB `check (importance between 0 and 3)` bounds it.
///
/// [categories] are the task's linked [TaskCategory]s (the `task_category_links` → `task_categories`
/// embed) — a user-owned colour-as-data taxonomy (Decision 40, Slice B), managed exactly like the
/// [contacts] People set. Written atomically by the task-write RPCs (`p_categories`); a soft-deleted
/// (RLS-hidden) category comes back as a null `task_categories` on the join row and is skipped here
/// (parity with [contacts]). Unlike [importance] (a fixed scale), each category carries its own hue.
class Task {
  final String id;
  final String title;
  final bool isDone;
  final String? notes;

  /// The linked People. Only id/name/company are populated from the embed.
  final List<Contact> contacts;

  /// Priority marker, 0..3 (0 = none, 1/2/3 = !/!!/!!!). See [importanceMarks].
  final int importance;

  /// The linked categories. Full [TaskCategory]s (id/name/colorHex) from the embed, so rows and the
  /// detail can render colour without a second fetch.
  final List<TaskCategory> categories;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Task({
    required this.id,
    required this.title,
    this.isDone = false,
    this.notes,
    this.contacts = const [],
    this.importance = 0,
    this.categories = const [],
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// A not-yet-persisted task. Mints a client-side id up front (issue #9) so `create_task` is
  /// idempotent on it; pass [id] to reuse one across a retry (the form holds a stable id). Always
  /// live and not-done: new tasks are created active. [notes], [contacts], [importance] and
  /// [categories] are optional (a new task may carry all of them).
  factory Task.draft({
    String? id,
    required String title,
    String? notes,
    List<Contact> contacts = const [],
    int importance = 0,
    List<TaskCategory> categories = const [],
  }) => Task(
    id: id ?? newEntityId(),
    title: title,
    notes: notes,
    contacts: contacts,
    importance: importance,
    categories: categories,
  );

  factory Task.fromJson(Map<String, dynamic> json) {
    // task_contacts is a to-many array; each row's `contacts` is a to-ONE object (or null when
    // that contact was soft-deleted and hidden by RLS — skip those). Mirrors Event.fromJson.
    final contacts = <Contact>[];
    for (final row in (json['task_contacts'] as List? ?? const [])) {
      final c = (row as Map<String, dynamic>)['contacts'];
      if (c is Map<String, dynamic>) contacts.add(Contact.fromJson(c));
    }
    // task_category_links is a to-many array; each row's `task_categories` is a to-ONE object (or
    // null when that category was soft-deleted and hidden by RLS — skip those). Mirrors the contacts
    // embed above.
    final categories = <TaskCategory>[];
    for (final row in (json['task_category_links'] as List? ?? const [])) {
      final c = (row as Map<String, dynamic>)['task_categories'];
      if (c is Map<String, dynamic>) categories.add(TaskCategory.fromJson(c));
    }
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['is_done'] as bool? ?? false,
      notes: json['notes'] as String?,
      contacts: contacts,
      importance: json['importance'] as int? ?? 0,
      categories: categories,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      deletedAt: _parseDate(json['deleted_at']),
    );
  }

  /// Params for the `create_task` RPC (Decision 26 — all writes go through RPCs). Matches the
  /// `create_task(p_title, p_notes, p_contacts, p_importance, p_categories, p_id)` signature: `p_id`
  /// is the client-minted id, inserted with `on conflict (id) do nothing` (idempotent, issue #9);
  /// `p_title` is trimmed here (belt-and-suspenders with the server, which also trims); `p_notes` is
  /// sent verbatim (possibly null — the server normalizes blank/whitespace to NULL); `p_contacts` is
  /// the linked-People id list (empty when none); `p_importance` is the 0..3 priority; `p_categories`
  /// is the linked-category id list (empty when none). Follows the project's RPC-write convention (as
  /// [Comment] does, though its param map now lives in the repo): `toRpcParams` matches the `create_*`
  /// shape and `is_done` is NOT included because `create_task` creates live+not-done. Updates go
  /// through `update_task` with an explicit
  /// `{p_id, p_title, p_is_done, p_notes, p_contacts, p_importance, p_categories}` built in the repo,
  /// never this map.
  Map<String, dynamic> toRpcParams() => {
    'p_id': id,
    'p_title': title.trim(),
    'p_notes': notes,
    'p_contacts': [for (final c in contacts) c.id],
    'p_importance': importance,
    'p_categories': [for (final c in categories) c.id],
  };

  /// Archived == soft-deleted. NULL `deleted_at` means a live task.
  bool get isArchived => deletedAt != null;

  /// Rename / edit notes / edit People / edit importance / edit categories / toggle done. A null
  /// [notes] argument means "keep the current notes" (matching [title]); the form clears notes by
  /// passing `''`, which the server normalizes to NULL on the round-trip — so this can't represent an
  /// explicit clear, and doesn't need to. [contacts], [importance] and [categories] default to
  /// `this.` — LOAD-BEARING: both complete-toggle paths call `copyWith(isDone: …)` WITHOUT them, and
  /// `update` re-sends the whole `p_contacts` + `p_categories` sets + `p_importance`
  /// (delete-then-reinsert / overwrite), so preserving them here is what stops a toggle from wiping
  /// the links or resetting the marker.
  Task copyWith({
    String? title,
    bool? isDone,
    String? notes,
    List<Contact>? contacts,
    int? importance,
    List<TaskCategory>? categories,
  }) => Task(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    notes: notes ?? this.notes,
    contacts: contacts ?? this.contacts,
    importance: importance ?? this.importance,
    categories: categories ?? this.categories,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
