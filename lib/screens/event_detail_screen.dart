import 'package:flutter/material.dart';

import '../data/comments_repository.dart';
import '../data/contacts_repository.dart';
import '../data/event_types_repository.dart';
import '../data/events_repository.dart';
import '../models/comment.dart';
import '../models/event.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/type_label.dart';
import 'event_form_screen.dart';

/// Read view for one event, with edit and (soft) delete. Pops `true` when the event
/// changed so the calendar refreshes.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventsRepository,
    required this.contactsRepository,
    required this.eventTypesRepository,
    required this.commentsRepository,
    required this.event,
  });

  final EventsRepository eventsRepository;
  final ContactsRepository contactsRepository;
  final EventTypesRepository eventTypesRepository;
  final CommentsRepository commentsRepository;
  final Event event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _event;
  bool _dirty = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          eventsRepository: widget.eventsRepository,
          contactsRepository: widget.contactsRepository,
          eventTypesRepository: widget.eventTypesRepository,
          existing: _event,
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _event = updated;
        _dirty = true;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${_event.title}" will be removed from your calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.eventsRepository.softDelete(_event.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('"${_event.title}" deleted')),
      );
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete — please try again")),
      );
    }
  }

  bool get _locationIsLink =>
      _event.location != null &&
      RegExp(r'^https?://', caseSensitive: false).hasMatch(_event.location!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = _event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = Navigator.of(context);
        Future.microtask(() => navigator.pop(_dirty));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event'),
          actions: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _deleting ? null : _edit,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(e.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            _Field(
              icon: Icons.schedule_outlined,
              label: 'When',
              value: _whenLabel(e),
            ),
            _Field(
              icon: Icons.sell_outlined,
              label: 'Type',
              // A soft-deleted type reads back null → "No type" (RLS hides the embed).
              child: TypeLabel(type: e.type, placeholder: 'No type'),
            ),
            if (e.location != null && e.location!.isNotEmpty)
              _Field(
                icon: _locationIsLink
                    ? Icons.link_outlined
                    : Icons.place_outlined,
                label: 'Location',
                value: e.location!,
                selectable: _locationIsLink,
              ),
            if (e.notes != null && e.notes!.isNotEmpty)
              _Field(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: e.notes!,
              ),
            const SizedBox(height: 4),
            _AttendeeList(event: e),
            const SizedBox(height: 28),
            _CommentsSection(
              repository: widget.commentsRepository,
              eventId: e.id,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Delete event',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _whenLabel(Event e) {
    final d = e.date;
    final date =
        '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]} ${d.year}';
    // Times are null iff all-day (DB CHECK enforces it) — guard anyway so a malformed
    // event never crashes the whole screen.
    if (e.allDay || e.startMin == null || e.endMin == null) {
      return '$date · All day';
    }
    return '$date · ${hhmm(e.startMin!)} – ${hhmm(e.endMin!)}';
  }
}

/// One labelled field. Renders nothing when the value is empty (no blank rows). A link
/// value is made [selectable] so a video link can be copied (no in-app launcher yet).
class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.selectable = false,
  }) : assert(value != null || child != null);

  final IconData icon;
  final String label;

  /// The value as text. Mutually exclusive with [child]; exactly one is provided.
  final String? value;

  /// A custom value widget (e.g. a type dot + name) shown in place of [value].
  final Widget? child;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                if (child != null)
                  child!
                else if (selectable)
                  SelectableText(value!, style: theme.textTheme.bodyLarge)
                else
                  Text(value!, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The attendee roster (avatar + name + company). Empty state when nobody is invited.
class _AttendeeList extends StatelessWidget {
  const _AttendeeList({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTENDEES · ${event.attendees.length}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (event.attendees.isEmpty)
          Text(
            'No attendees',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final c in event.attendees)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  InitialsAvatar(name: c.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: theme.textTheme.bodyLarge),
                        if (c.company != null && c.company!.isNotEmpty)
                          Text(
                            c.company!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Comments on the event — add, edit, archive (soft-delete), and view archived. Owns its
/// own load because the detail screen renders synchronously; mirrors the list screens'
/// `_lastData` stale-guard so a failed refresh keeps the cached list on screen.
///
/// Comments are never hard-deleted: "Archive" sets `deleted_at`, and archived comments stay
/// readable (RLS `select using (true)`) under the "Show archived" toggle.
class _CommentsSection extends StatefulWidget {
  const _CommentsSection({required this.repository, required this.eventId});

  final CommentsRepository repository;
  final String eventId;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  late Future<List<Comment>> _future;
  List<Comment>? _lastData;

  final _composer = TextEditingController();
  final _editController = TextEditingController();
  String? _editingId; // the comment currently in inline-edit mode
  bool _showArchived = false;
  bool _busy = false; // a write is in flight — disable the actions

  @override
  void initState() {
    super.initState();
    _composer.addListener(
      _rebuild,
    ); // toggle the Comment button as text changes
    _editController.addListener(_rebuild); // toggle the Save button
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _load() async {
    final future = widget.repository.fetchForEvent(widget.eventId);
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
        Comment.draft(eventId: widget.eventId, body: text),
      );
      _composer.clear();
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
  /// `mounted` after it (the `_confirmDelete` idiom used elsewhere in this file).
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
            const SizedBox(height: 12),
            _composerRow(),
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
      child: editing ? _editBody(c) : _viewBody(c),
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
            const Spacer(),
            _action('Edit', _busy ? null : () => _startEdit(c)),
            _action('Archive', _busy ? null : () => _archive(c)),
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
              const Spacer(),
              _action('Unarchive', _busy ? null : () => _unarchive(c)),
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

  /// Compact absolute 24h timestamp, e.g. "14:32 · 9 Jul". `createdAt` is UTC/offset, so
  /// convert to local first; `hhmm` takes minutes-from-midnight, not a DateTime.
  String _timestamp(Comment c) {
    final dt = c.createdAt;
    if (dt == null) return '';
    final t = dt.toLocal();
    return '${hhmm(t.hour * 60 + t.minute)} · ${t.day} ${monthShort[t.month - 1]}';
  }
}
