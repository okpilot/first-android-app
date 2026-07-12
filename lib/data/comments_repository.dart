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

/// Talks to PostgREST under RLS via `supabase_flutter` — never raw Postgres.
/// Reads go direct (a plain `select`); all writes go through SECURITY DEFINER RPCs
/// (`create_comment` / `update_comment` / `soft_delete_comment` / `restore_comment`) per
/// docs/database.md (Decision 26). Those RPCs are for uniformity, not necessity — this table's
/// `using (true)` SELECT policy means a direct write would have worked (no 42501 to dodge).
/// Each write RPC returns the id; we re-`select` the full row so callers get a Comment with the
/// server-populated timestamps (and the `deleted_at` the archive/restore RPCs set).
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
    final id = await _client.rpc('create_comment', params: draft.toRpcParams());
    return _fetchOne(id as String);
  }

  @override
  Future<Comment> edit(Comment comment) async {
    // Body-only on purpose — update_comment takes no p_event_id, so an edit can't
    // move a comment to another event.
    await _client.rpc(
      'update_comment',
      params: {'p_id': comment.id, 'p_body': comment.body.trim()},
    );
    return _fetchOne(comment.id);
  }

  @override
  Future<Comment> archive(String id) async {
    await _client.rpc('soft_delete_comment', params: {'p_id': id});
    return _fetchOne(id);
  }

  @override
  Future<Comment> unarchive(String id) async {
    await _client.rpc('restore_comment', params: {'p_id': id});
    return _fetchOne(id);
  }

  Future<Comment> _fetchOne(String id) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .single();
    return Comment.fromJson(row);
  }
}
