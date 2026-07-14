import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';

/// Data access for tasks. An interface so screens depend on the abstraction and tests can inject
/// a fake (CI has no backend).
abstract interface class TasksRepository {
  /// Every task — live AND archived (the UI splits by [Task.isDone] / [Task.isArchived]).
  /// Active first, then done; newest within each group.
  Future<List<Task>> fetchAll();
  Future<Task> create(Task draft);
  Future<Task> update(Task task); // title + is_done + notes, in one
  Future<Task> archive(String id); // set deleted_at
  Future<Task> restore(String id); // clear deleted_at
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres.
/// Reads go direct (a plain `select`); all writes go through SECURITY DEFINER RPCs
/// (`create_task` / `update_task` / `soft_delete_task` / `restore_task`) per docs/database.md
/// (Decision 26). Those RPCs are for uniformity, not necessity — this table's `using (true)`
/// SELECT policy means a direct write would have worked (no 42501 to dodge), same as event_comments.
/// Each write RPC returns the id; we re-`select` the full row so callers get a Task with the
/// server-populated timestamps (and the `deleted_at` the archive/restore RPCs set).
class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'tasks';
  // Embed the People join on EVERY read (fetchAll AND _fetchOne): the write path replaces the
  // whole `p_contacts` set, so any in-memory Task fed to update() must carry its full contacts or
  // the save/complete-toggle would wipe the links. task_contacts is to-many; each row's `contacts`
  // is to-one (null for a soft-deleted, RLS-hidden contact — Task.fromJson skips those).
  static const _columns =
      'id, title, is_done, notes, created_at, updated_at, deleted_at, '
      'task_contacts(contact_id, contacts(id, name, company))';

  @override
  Future<List<Task>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .order('is_done', ascending: true) // active (false) before done (true)
        .order('created_at', ascending: false) // newest first within each group
        .order('id'); // stable tiebreaker for same-instant rows
    return rows.map(Task.fromJson).toList();
  }

  @override
  Future<Task> create(Task draft) async {
    // draft.toRpcParams() is {p_title, p_notes, p_contacts} — matches create_task(p_title, p_notes,
    // p_contacts). Spread, like siblings.
    final id = await _client.rpc('create_task', params: draft.toRpcParams());
    return _fetchOne(id as String);
  }

  @override
  Future<Task> update(Task task) async {
    // Explicit params (NOT toRpcParams, which is the create shape): update_task carries the
    // title, is_done, notes AND the People set, so one write path serves the form save AND the
    // list/detail complete-toggle (which re-sends the unchanged title + notes + contacts with a
    // flipped is_done). The server normalizes blank/whitespace notes to NULL and replaces the
    // whole task_contacts set from p_contacts.
    await _client.rpc(
      'update_task',
      params: {
        'p_id': task.id,
        'p_title': task.title.trim(),
        'p_is_done': task.isDone,
        'p_notes': task.notes,
        'p_contacts': [for (final c in task.contacts) c.id],
      },
    );
    return _fetchOne(task.id);
  }

  @override
  Future<Task> archive(String id) async {
    await _client.rpc('soft_delete_task', params: {'p_id': id});
    return _fetchOne(id);
  }

  @override
  Future<Task> restore(String id) async {
    await _client.rpc('restore_task', params: {'p_id': id});
    return _fetchOne(id);
  }

  Future<Task> _fetchOne(String id) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .single();
    return Task.fromJson(row);
  }
}
