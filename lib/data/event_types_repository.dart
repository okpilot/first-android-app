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

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres. Single-table
/// CRUD goes direct (per docs/database.md, like contacts); only the delete is routed
/// through the `soft_delete_event_type` RPC (a direct REST UPDATE of deleted_at fails the
/// SELECT policy's RETURNING re-check, 42501).
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
    final row = await _client
        .from(_table)
        .insert(draft.toWrite())
        .select(_columns)
        .single();
    return EventType.fromJson(row);
  }

  @override
  Future<EventType> update(EventType type) async {
    final row = await _client
        .from(_table)
        .update(type.toWrite())
        .eq('id', type.id)
        .select(_columns)
        .single();
    return EventType.fromJson(row);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_event_type', params: {'p_id': id});
}
