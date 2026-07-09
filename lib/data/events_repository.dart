import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';

/// Data access for calendar events. An interface so screens depend on the abstraction
/// and tests can inject a fake (CI has no backend).
abstract interface class EventsRepository {
  /// Live (non-deleted) events with their attendees, sorted by date then time.
  Future<List<Event>> fetchAll();
  Future<Event> create(Event draft);
  Future<Event> update(Event event);
  Future<void> softDelete(String id);
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres.
/// Reads are a direct embedded select; writes are multi-table (event + attendees) so
/// they go through the SECURITY DEFINER RPCs (see docs/database.md #1 and the
/// event-write-rpcs migration).
class SupabaseEventsRepository implements EventsRepository {
  SupabaseEventsRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'events';

  // The attendee embed: event_attendees is to-many, each row's `contacts` is to-one.
  static const _select =
      'id, title, event_date, all_day, start_time, end_time, location, notes, '
      'event_attendees(contact_id, contacts(id, name, company))';

  @override
  Future<List<Event>> fetchAll() async {
    final rows = await _client.from(_table).select(_select);
    // Sort in Dart (not via .order()): Postgres orders NULLs last, which would push
    // all-day events after timed ones — the opposite of compareForDay's intent.
    final events = rows.map(Event.fromJson).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : Event.compareForDay(a, b);
      });
    return events;
  }

  @override
  Future<Event> create(Event draft) async {
    final id = await _client.rpc('create_event', params: draft.toRpcParams());
    return _fetchOne(id as String);
  }

  @override
  Future<Event> update(Event event) async {
    await _client.rpc(
      'update_event',
      params: {'p_id': event.id, ...event.toRpcParams()},
    );
    return _fetchOne(event.id);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_event', params: {'p_id': id});

  Future<Event> _fetchOne(String id) async {
    final row = await _client
        .from(_table)
        .select(_select)
        .eq('id', id)
        .single();
    return Event.fromJson(row);
  }
}
