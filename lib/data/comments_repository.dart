import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';

/// Data access for event comments. An interface so screens depend on the abstraction and
/// tests can inject a fake (CI has no backend).
abstract interface class CommentsRepository {
  /// Every comment for an event — live AND archived (the UI splits by [Comment.isArchived]).
  /// Newest first.
  Future<List<Comment>> fetchForEvent(String eventId);
  Future<Comment> add(Comment draft);
  Future<Comment> edit(Comment comment); // body only
  Future<Comment> archive(String id); // set deleted_at
  Future<Comment> unarchive(String id); // clear deleted_at
}

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres. All writes go
/// DIRECT (single table): unlike the other tables, `event_comments`' SELECT policy is
/// `using (true)`, so a just-archived row survives PostgREST's RETURNING re-check —
/// archive/unarchive/edit are plain UPDATEs, no soft-delete RPC needed.
class SupabaseCommentsRepository implements CommentsRepository {
  SupabaseCommentsRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'event_comments';
  static const _columns =
      'id, event_id, body, created_at, updated_at, deleted_at';

  @override
  Future<List<Comment>> fetchForEvent(String eventId) async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .order('id'); // stable tiebreaker for same-instant rows
    return rows.map(Comment.fromJson).toList();
  }

  @override
  Future<Comment> add(Comment draft) async {
    final row = await _client
        .from(_table)
        .insert(draft.toWrite())
        .select(_columns)
        .single();
    return Comment.fromJson(row);
  }

  @override
  Future<Comment> edit(Comment comment) async {
    // Body-only on purpose — never re-send event_id, so an edit can't move a
    // comment to another event (toWrite() is for inserts, where event_id is set).
    final row = await _client
        .from(_table)
        .update({'body': comment.body.trim()})
        .eq('id', comment.id)
        .select(_columns)
        .single();
    return Comment.fromJson(row);
  }

  @override
  Future<Comment> archive(String id) =>
      _setDeletedAt(id, DateTime.now().toUtc().toIso8601String());

  @override
  Future<Comment> unarchive(String id) => _setDeletedAt(id, null);

  /// Direct UPDATE of `deleted_at` (safe here because the SELECT policy is `using (true)`,
  /// so the mutated row survives the RETURNING re-check).
  Future<Comment> _setDeletedAt(String id, String? value) async {
    final row = await _client
        .from(_table)
        .update({'deleted_at': value})
        .eq('id', id)
        .select(_columns)
        .single();
    return Comment.fromJson(row);
  }
}
