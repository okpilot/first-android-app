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
/// Single-table CRUD goes direct (per docs/database.md); the delete is the one
/// exception, routed through the `soft_delete_contact` RPC.
class SupabaseContactsRepository implements ContactsRepository {
  SupabaseContactsRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'contacts';

  @override
  Future<List<Contact>> fetchAll() async {
    final rows =
        await _client.from(_table).select().order('name', ascending: true);
    return rows.map(Contact.fromJson).toList();
  }

  @override
  Future<Contact> create(Contact draft) async {
    final row =
        await _client.from(_table).insert(draft.toWrite()).select().single();
    return Contact.fromJson(row);
  }

  @override
  Future<Contact> update(Contact contact) async {
    final row = await _client
        .from(_table)
        .update(contact.toWrite())
        .eq('id', contact.id)
        .select()
        .single();
    return Contact.fromJson(row);
  }

  @override
  Future<void> softDelete(String id) =>
      _client.rpc('soft_delete_contact', params: {'p_id': id});
}
