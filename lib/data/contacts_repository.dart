import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';

/// Data access for contacts. An interface so screens depend on the abstraction and
/// tests can inject a fake (CI has no backend).
abstract interface class ContactsRepository {
  /// Live (non-deleted) contacts, ordered by name. RLS hides soft-deleted rows.
  Future<List<Contact>> fetchAll();
  Future<Contact> create(Contact draft);
  Future<Contact> update(Contact contact);
  Future<void> softDelete(String id);
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres.
/// Reads go direct (a plain `select`); all writes go through SECURITY DEFINER RPCs
/// (`create_contact` / `update_contact` / `soft_delete_contact`) per docs/database.md
/// (Decision 26). Each write RPC returns the id; we re-`select` the full row so callers
/// get a Contact with the server-populated timestamps.
class SupabaseContactsRepository implements ContactsRepository {
  SupabaseContactsRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'contacts';

  @override
  Future<List<Contact>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('name', ascending: true);
    return rows.map(Contact.fromJson).toList();
  }

  @override
  Future<Contact> create(Contact draft) async {
    final id = await _client.rpc('create_contact', params: draft.toRpcParams());
    return _fetchOne(id as String);
  }

  @override
  Future<Contact> update(Contact contact) async {
    await _client.rpc(
      'update_contact',
      params: {'p_id': contact.id, ...contact.toRpcParams()},
    );
    return _fetchOne(contact.id);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_contact', params: {'p_id': id});

  Future<Contact> _fetchOne(String id) async {
    final row = await _client.from(_table).select().eq('id', id).single();
    return Contact.fromJson(row);
  }
}
