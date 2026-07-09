import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../widgets/initials_avatar.dart';
import 'event_form_screen.dart';

/// Read view for one event, with edit and (soft) delete. Pops `true` when the event
/// changed so the calendar refreshes.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventsRepository,
    required this.contactsRepository,
    required this.event,
  });

  final EventsRepository eventsRepository;
  final ContactsRepository contactsRepository;
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
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;
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
                selectable
                    ? SelectableText(value, style: theme.textTheme.bodyLarge)
                    : Text(value, style: theme.textTheme.bodyLarge),
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
