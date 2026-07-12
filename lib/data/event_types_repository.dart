import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_type.dart';

/// Data access for event types. An interface so screens depend on the abstraction and
/// tests can inject a fake (CI has no backend).
abstract interface class EventTypesRepository {
  /// Live (non-deleted) types, ordered by name (case-insensitive). RLS hides deleted.
  Future<List<EventType>> fetchAll();
  Future<EventType> create(EventType draft);
  Future<EventType> update(EventType type);
  Future<void> softDelete(String id);
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres.
/// Reads go direct (a plain `select`); all writes go through SECURITY DEFINER RPCs
/// (`create_event_type` / `update_event_type` / `soft_delete_event_type`) per docs/database.md
/// (Decision 26). Each write RPC returns the id; we re-`select` the full row so callers get an
/// EventType built from the persisted values.
class SupabaseEventTypesRepository implements EventTypesRepository {
  SupabaseEventTypesRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'event_types';
  static const _columns = 'id, name, color';

  @override
  Future<List<EventType>> fetchAll() async {
    final rows = await _client.from(_table).select(_columns);
    // Sort in Dart, case-insensitively: PostgREST's .order() uses the default collation,
    // which sorts uppercase before lowercase ("Work" before "admin").
    return rows.map(EventType.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<EventType> create(EventType draft) async {
    final id = await _client.rpc(
      'create_event_type',
      params: draft.toRpcParams(),
    );
    return _fetchOne(id as String);
  }

  @override
  Future<EventType> update(EventType type) async {
    await _client.rpc(
      'update_event_type',
      params: {'p_id': type.id, ...type.toRpcParams()},
    );
    return _fetchOne(type.id);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_event_type', params: {'p_id': id});

  Future<EventType> _fetchOne(String id) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .single();
    return EventType.fromJson(row);
  }
}
