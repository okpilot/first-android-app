import 'dart:async';

import 'package:flutter/material.dart';

import '../data/comments_repository.dart';
import '../data/contacts_repository.dart';
import '../data/event_types_repository.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../widgets/comments_section.dart';
import '../widgets/detail_field.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/subtle_button.dart';
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
        unawaited(Future.microtask(() => navigator.pop(_dirty)));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event'),
          // Edit top-right is the app's shared SubtleButton ('Edit' tonal chip), same as
          // everywhere else, NOT a bare pencil (Decisions 29 + 49).
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: SubtleButton(
                  label: 'Edit',
                  onPressed: _deleting ? null : _edit,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(e.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            DetailField(
              icon: Icons.schedule_outlined,
              label: 'When',
              value: _whenLabel(e),
            ),
            DetailField(
              icon: Icons.sell_outlined,
              label: 'Type',
              // A soft-deleted type reads back null → "No type" (RLS hides the embed).
              child: TypeLabel(type: e.type, placeholder: 'No type'),
            ),
            if (e.location != null && e.location!.isNotEmpty)
              DetailField(
                icon: _locationIsLink
                    ? Icons.link_outlined
                    : Icons.place_outlined,
                label: 'Location',
                value: e.location!,
                selectable: _locationIsLink,
              ),
            if (e.notes != null && e.notes!.isNotEmpty)
              DetailField(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: e.notes!,
              ),
            const SizedBox(height: 4),
            _AttendeeList(event: e),
            const SizedBox(height: 28),
            CommentsSection(
              repository: widget.commentsRepository,
              parentId: e.id,
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
    final date = longDate(d);
    // Times are null iff all-day (DB CHECK enforces it) — guard anyway so a malformed
    // event never crashes the whole screen.
    if (e.allDay || e.startMin == null || e.endMin == null) {
      return '$date · All day';
    }
    return '$date · ${hhmm(e.startMin!)} – ${hhmm(e.endMin!)}';
  }
}

/// The People roster (avatar + name + company). Empty state when nobody is invited.
/// (Class/field names keep the `attendee` domain noun — `Event.attendees` + the
/// `event_attendees` table; only the user-facing copy is "people", per Decision 47.)
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
          'PEOPLE · ${event.attendees.length}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (event.attendees.isEmpty)
          Text(
            'No people',
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
