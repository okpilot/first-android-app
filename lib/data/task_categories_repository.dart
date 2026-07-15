import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_category.dart';

/// Data access for task categories. An interface so screens depend on the abstraction and tests
/// can inject a fake (CI has no backend). Mirrors [EventTypesRepository] — a parallel taxonomy for
/// tasks.
abstract interface class TaskCategoriesRepository {
  /// Live (non-deleted) categories, ordered by name (case-insensitive). RLS hides deleted.
  Future<List<TaskCategory>> fetchAll();
  Future<TaskCategory> create(TaskCategory draft);
  Future<TaskCategory> update(TaskCategory category);
  Future<void> softDelete(String id);
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres. Reads go direct (a
/// plain `select`); all writes go through SECURITY DEFINER RPCs (`create_task_category` /
/// `update_task_category` / `soft_delete_task_category`) per docs/database.md. Each write RPC returns
/// the id; we re-`select` the full row so callers get a TaskCategory built from the persisted values.
class SupabaseTaskCategoriesRepository implements TaskCategoriesRepository {
  SupabaseTaskCategoriesRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'task_categories';
  static const _columns = 'id, name, color';

  @override
  Future<List<TaskCategory>> fetchAll() async {
    final rows = await _client.from(_table).select(_columns);
    // Sort in Dart, case-insensitively: PostgREST's .order() uses the default collation, which
    // sorts uppercase before lowercase ("Work" before "admin").
    return rows.map(TaskCategory.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<TaskCategory> create(TaskCategory draft) async {
    final id = await _client.rpc(
      'create_task_category',
      params: draft.toRpcParams(),
    );
    return _fetchOne(id as String);
  }

  @override
  Future<TaskCategory> update(TaskCategory category) async {
    await _client.rpc(
      'update_task_category',
      params: {'p_id': category.id, ...category.toRpcParams()},
    );
    return _fetchOne(category.id);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_task_category', params: {'p_id': id});

  Future<TaskCategory> _fetchOne(String id) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .single();
    return TaskCategory.fromJson(row);
  }
}
