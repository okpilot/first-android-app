import 'dart:async';

import 'package:flutter/material.dart';

import '../data/comments_repository.dart';
import '../models/comment.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../util/ids.dart';

/// Comments on a parent record (an event or a task) — add, edit, archive (soft-delete), and
/// view archived. Parent-agnostic: give it a [CommentsRepository] and the [parentId] of the
/// owning record. Owns its own load because the host detail renders synchronously; mirrors the
/// list screens' `_lastData` stale-guard so a failed refresh keeps the cached list on screen.
///
/// Comments are never hard-deleted: "Archive" sets `deleted_at`, and archived comments stay
/// readable (RLS `select using (true)`) under the "Show archived" toggle. Extracted from the
/// event detail so events and tasks share one implementation (Decision 2a — shared widget).
///
/// [readOnly] renders the log for viewing only — no composer, and no per-comment Edit / Archive /
/// Unarchive actions. Used for an **archived task** (Slice 2b): its comments are frozen history.
/// The live/archived list and the "Show archived" toggle still work; only the mutating affordances
/// are removed. Defaults to false, so the event caller is unaffected.
class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.repository,
    required this.parentId,
    this.readOnly = false,
  });

  final CommentsRepository repository;
  final String parentId;
  final bool readOnly;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  late Future<List<Comment>> _future;
  List<Comment>? _lastData;

  final _composer = TextEditingController();
  final _editController = TextEditingController();
  String? _editingId; // the comment currently in inline-edit mode
  bool _showArchived = false;
  bool _busy = false; // a write is in flight — disable the actions

  // A stable client-minted id for the next new comment, reused across re-taps so a retry after a hung
  // add is idempotent (create_*_comment does `on conflict (id) do nothing`, issue #9). Unlike the
  // pop-on-success forms, this composer stays mounted, so it's mutable — reset after each successful
  // add (see _add), else the next comment would collide on this id and be silently dropped.
  String _pendingId = newEntityId();

  @override
  void initState() {
    super.initState();
    _composer.addListener(
      _rebuild,
    ); // toggle the Comment button as text changes
    _editController.addListener(_rebuild); // toggle the Save button
    unawaited(_load());
  }

  @override
  void dispose() {
    _composer.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent flips to read-only while a comment editor is open (e.g. the task is archived
    // in place — an in-place rebuild with no remount on the phone path), close the editor so it
    // can't reappear on a later restore. A rebuild is already in flight, so no setState here.
    if (widget.readOnly && !oldWidget.readOnly) _editingId = null;
  }

  void _rebuild() => setState(() {});

  Future<void> _load() async {
    final future = widget.repository.fetchFor(widget.parentId);
    setState(() {
      _future = future;
    });
    try {
      final data = await future;
      // Ignore a stale fetch a newer _load() has superseded.
      if (identical(future, _future)) _lastData = data;
    } catch (_) {
      // With cached data on screen a failed refresh is otherwise invisible — surface it,
      // but only for the current fetch (not one a newer _load() already replaced).
      if (mounted && _lastData != null && identical(future, _future)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't refresh comments — showing saved data"),
          ),
        );
      }
    }
  }

  Future<void> _add() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _busy) return;
    await _run("Couldn't add comment — please try again", () async {
      await widget.repository.add(
        Comment.draft(id: _pendingId, parentId: widget.parentId, body: text),
      );
      _composer.clear();
      // Only reached on success (a failed add throws out of _run before here): retire this id so the
      // next comment gets a fresh one and doesn't conflict-skip against the row we just wrote.
      _pendingId = newEntityId();
    });
  }

  Future<void> _saveEdit(Comment c) async {
    final text = _editController.text.trim();
    if (text.isEmpty || _busy) return;
    await _run("Couldn't save — please try again", () async {
      await widget.repository.edit(c.copyWith(body: text));
      _editingId = null;
    });
  }

  Future<void> _archive(Comment c) => _run(
    "Couldn't archive — please try again",
    () => widget.repository.archive(c.id),
  );

  Future<void> _unarchive(Comment c) => _run(
    "Couldn't restore — please try again",
    () => widget.repository.unarchive(c.id),
  );

  /// Runs a mutation, then reloads. Captures the messenger before the await and re-checks
  /// `mounted` after it.
  Future<void> _run(String errorMessage, Future<void> Function() op) async {
    // re-entrancy guard: a double-tap can't fire the op twice
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit(Comment c) {
    setState(() {
      _editingId = c.id;
      _editController.text = c.body;
    });
  }

  void _cancelEdit() => setState(() => _editingId = null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Comment>>(
      future: _future,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            _lastData == null;
        final errored = snapshot.hasError && _lastData == null;
        final comments = snapshot.data ?? _lastData ?? const <Comment>[];
        final live = comments.where((c) => !c.isArchived).toList();
        final archived = comments.where((c) => c.isArchived).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(live.length),
            // No composer in read-only mode (an archived task's log is frozen history).
            if (!widget.readOnly) ...[
              const SizedBox(height: 12),
              _composerRow(),
            ],
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errored)
              _inlineError()
            else ...[
              if (live.isEmpty)
                _emptyText()
              else
                for (final c in live) _liveTile(c),
              if (archived.isNotEmpty) _archivedSection(archived),
            ],
          ],
        );
      },
    );
  }

  Widget _header(int liveCount) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Comments', style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$liveCount', style: theme.textTheme.labelMedium),
        ),
      ],
    );
  }

  Widget _composerRow() {
    final canSend = !_busy && _composer.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _composer,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Add a comment…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: canSend ? _add : null,
          child: const Text('Comment'),
        ),
      ],
    );
  }

  Widget _liveTile(Comment c) {
    final theme = Theme.of(context);
    final editing = _editingId == c.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      // Gate the editor on readOnly too — not just _editingId. Otherwise archiving the task
      // while a comment editor is open (an in-place readOnly flip with no remount on the phone
      // path) would leave a live Save on a frozen log.
      child: (editing && !widget.readOnly) ? _editBody(c) : _viewBody(c),
    );
  }

  Widget _viewBody(Comment c) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 2),
          child: Text(c.body, style: theme.textTheme.bodyLarge),
        ),
        Row(
          children: [
            Text(
              _timestamp(c),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Read-only (archived task): timestamp only, no mutating actions.
            if (!widget.readOnly) ...[
              const Spacer(),
              _action('Edit', _busy ? null : () => _startEdit(c)),
              _action('Archive', _busy ? null : () => _archive(c)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _editBody(Comment c) {
    final canSave = !_busy && _editController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 6),
          child: TextField(
            controller: _editController,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _action('Cancel', _busy ? null : _cancelEdit),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: canSave ? () => _saveEdit(c) : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _archivedSection(List<Comment> archived) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        InkWell(
          onTap: () => setState(() => _showArchived = !_showArchived),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  _showArchived ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_showArchived ? 'Hide' : 'Show'} archived (${archived.length})',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showArchived)
          for (final c in archived) _archivedTile(c),
      ],
    );
  }

  Widget _archivedTile(Comment c) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 2),
            child: Text(
              c.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            children: [
              _archivedChip(),
              const SizedBox(width: 8),
              Text(
                _timestamp(c),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Read-only (archived task): no Unarchive affordance on the frozen log.
              if (!widget.readOnly) ...[
                const Spacer(),
                _action('Unarchive', _busy ? null : () => _unarchive(c)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _archivedChip() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'ARCHIVED',
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// A compact, subtle text action (Edit / Archive / Unarchive / Cancel).
  Widget _action(String label, VoidCallback? onPressed) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  Widget _emptyText() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'No comments yet.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _inlineError() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load comments.",
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Compact absolute 24h timestamp, e.g. "9 Jul · 14:32" — date first, so it reads in the same
  /// direction as every other date in the app (Decision 47). `createdAt` is UTC/offset, so
  /// convert to local first; `hhmm` takes minutes-from-midnight, not a DateTime.
  String _timestamp(Comment c) {
    final dt = c.createdAt;
    if (dt == null) return '';
    final t = dt.toLocal();
    return '${displayDateNoYear(t)} · ${hhmm(t.hour * 60 + t.minute)}';
  }
}
