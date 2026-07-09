import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../data/events_repository.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../widgets/initials_avatar.dart';
import 'attendee_picker_screen.dart';

/// Add (when [existing] is null) or edit an event. Pops the saved [Event] on success,
/// or nothing on cancel. New events prefill from [initialDate]/[initialHour] (the
/// empty-timeline-slot entry point).
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    required this.eventsRepository,
    required this.contactsRepository,
    this.existing,
    this.initialDate,
    this.initialHour,
  });

  final EventsRepository eventsRepository;
  final ContactsRepository contactsRepository;
  final Event? existing;
  final DateTime? initialDate;
  final int? initialHour;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  late DateTime _date;
  late bool _allDay;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late List<Contact> _attendees;
  String? _timeError;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _allDay = e?.allDay ?? false;
    _attendees = List<Contact>.from(e?.attendees ?? const <Contact>[]);
    _date = dayOnly(e?.date ?? widget.initialDate ?? DateTime.now());

    if (e != null && !e.allDay) {
      _start = _fromMin(e.startMin!);
      _end = _fromMin(e.endMin!);
    } else {
      final h = widget.initialHour ?? 9;
      _start = TimeOfDay(hour: h.clamp(0, 22), minute: 0);
      _end = TimeOfDay(hour: (h + 1).clamp(1, 23), minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  static int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _fromMin(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Event date',
    );
    if (picked != null) setState(() => _date = dayOnly(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Start time' : 'End time',
      // Always 24-hour (no AM/PM), regardless of device locale.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep end sensibly after start if the user pushed start past it.
        if (_toMin(_end) <= _toMin(_start)) {
          _end = _fromMin((_toMin(_start) + 60).clamp(0, 23 * 60 + 59));
        }
      } else {
        _end = picked;
      }
      _timeError = null;
    });
  }

  Future<void> _openAttendees() async {
    final result = await Navigator.of(context).push<List<Contact>>(
      MaterialPageRoute(
        builder: (_) => AttendeePickerScreen(
          repository: widget.contactsRepository,
          initialSelected: _attendees,
        ),
      ),
    );
    if (result != null) setState(() => _attendees = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allDay && _toMin(_end) <= _toMin(_start)) {
      setState(() => _timeError = 'End time must be after the start time');
      return;
    }
    setState(() => _saving = true);

    final draft = Event(
      id: widget.existing?.id ?? '',
      title: _title.text,
      date: _date,
      allDay: _allDay,
      startMin: _allDay ? null : _toMin(_start),
      endMin: _allDay ? null : _toMin(_end),
      location: _location.text,
      notes: _notes.text,
      attendees: _attendees,
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final saved = _isEditing
          ? await widget.eventsRepository.update(draft)
          : await widget.eventsRepository.create(draft);
      if (!mounted) return;
      navigator.pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — please try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit event' : 'New event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_isEditing,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),
              _AllDayRow(
                value: _allDay,
                onChanged: (v) => setState(() {
                  _allDay = v;
                  if (v) _timeError = null;
                }),
              ),
              const SizedBox(height: 16),
              _ValueField(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: _dateLabel(_date),
                onTap: _pickDate,
              ),
              // Time fields collapse when the event is all-day.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _allDay
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ValueField(
                                    icon: Icons.schedule_outlined,
                                    label: 'Starts',
                                    value: hhmm(_toMin(_start)),
                                    onTap: () => _pickTime(isStart: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ValueField(
                                    icon: Icons.schedule_outlined,
                                    label: 'Ends',
                                    value: hhmm(_toMin(_end)),
                                    onTap: () => _pickTime(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                            if (_timeError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 12,
                                ),
                                child: Text(
                                  _timeError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _location,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'A place or a video link',
                  prefixIcon: Icon(Icons.place_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _AttendeesSection(
                attendees: _attendees,
                onAdd: _openAttendees,
                onRemove: (c) =>
                    setState(() => _attendees.removeWhere((x) => x.id == c.id)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _notes,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Add event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) =>
      '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]} ${d.year}';
}

/// The all-day toggle row (label + mono Switch), styled to line up with the fields.
class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('All day')),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A read-only, tappable field that opens a picker (poka-yoke: no free-text dates/times),
/// mirroring the Contacts form's date field.
class _ValueField extends StatelessWidget {
  const _ValueField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// The attendees block: a label, the selected contacts as removable chips, and an
/// "Add contacts" button that opens the picker.
class _AttendeesSection extends StatelessWidget {
  const _AttendeesSection({
    required this.attendees,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Contact> attendees;
  final VoidCallback onAdd;
  final ValueChanged<Contact> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTENDEES', style: theme.textTheme.labelMedium),
        const SizedBox(height: 10),
        if (attendees.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in attendees)
                InputChip(
                  avatar: InitialsAvatar(name: c.name, radius: 11),
                  label: Text(c.name),
                  onDeleted: () => onRemove(c),
                ),
            ],
          ),
        if (attendees.isNotEmpty) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_outlined),
          label: const Text('Add contacts'),
        ),
      ],
    );
  }
}
