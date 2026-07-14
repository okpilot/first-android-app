import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../data/tasks_repository.dart';
import '../models/contact.dart';
import '../models/task.dart';
import '../widgets/initials_avatar.dart';
import 'contact_picker_screen.dart';

/// Add (when [existing] is null) or edit a task — the title-only form. A thin `Scaffold`
/// wrapper around [TaskEditView]: it pops the saved [Task] on success (or nothing on
/// cancel/back), so the caller can apply it in place. Reached by "New task" and by the
/// detail view's **Edit** (Decision 29). Mirrors [ContactFormScreen].
///
/// Completion and archive/restore are **not** here — they live on [TaskDetailView] as
/// buttons. Editing is title-only, so an archived task (read-only) never reaches this form.
class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({
    super.key,
    required this.repository,
    required this.contactsRepository,
    this.existing,
  });

  final TasksRepository repository;
  final ContactsRepository contactsRepository;
  final Task? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New task' : 'Edit task')),
      body: TaskEditView(
        repository: repository,
        contactsRepository: contactsRepository,
        existing: existing,
        onChanged: (saved) => Navigator.of(context).pop(saved),
      ),
    );
  }
}

/// The shared editor *body* for a task's **title + notes + People** — create or edit. It has no
/// `Scaffold`/`AppBar` and NEVER pops — it reports the saved task up via [onChanged] and
/// lets the host ([TaskFormScreen]) decide navigation. Completion is NOT here (it's the
/// detail view's Complete button): `copyWith(title:, notes:, contacts:)` preserves `isDone` /
/// `deletedAt` on an edit so a save can't clobber the completion state. Notes are optional —
/// a blank box is normalized to NULL by the server. People are linked contacts (like an event's
/// attendees), edited via the shared [ContactPickerScreen].
class TaskEditView extends StatefulWidget {
  const TaskEditView({
    super.key,
    required this.repository,
    required this.contactsRepository,
    this.existing,
    this.onChanged,
  });

  final TasksRepository repository;
  final ContactsRepository contactsRepository;
  final Task? existing;

  /// Called with the resulting task after a successful create / rename.
  final ValueChanged<Task>? onChanged;

  @override
  State<TaskEditView> createState() => _TaskEditViewState();
}

class _TaskEditViewState extends State<TaskEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  // The linked People — seeded from the existing task, edited via the picker.
  late List<Contact> _contacts;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _contacts = widget.existing?.contacts ?? const [];
  }

  /// Open the shared contact picker to edit the linked People. Guard the setState with `mounted`
  /// (StatefulWidget + await); a system-back cancel returns null → keep the current selection.
  Future<void> _openPeople() async {
    final result = await Navigator.of(context).push<List<Contact>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          repository: widget.contactsRepository,
          initialSelected: _contacts,
          title: 'people',
        ),
      ),
    );
    if (result != null && mounted) setState(() => _contacts = result);
  }

  void _removeContact(Contact c) => setState(
    () => _contacts = [..._contacts]..removeWhere((x) => x.id == c.id),
  );

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      // copyWith preserves isDone / deletedAt so an edit can't clobber the completion the
      // detail's Complete button owns. notes go through unchanged — a cleared box sends '',
      // which the server normalizes to NULL.
      final Task saved = _isEditing
          ? await widget.repository.update(
              widget.existing!.copyWith(
                title: _title.text,
                notes: _notes.text,
                contacts: _contacts,
              ),
            )
          : await widget.repository.create(
              Task.draft(
                title: _title.text,
                notes: _notes.text,
                contacts: _contacts,
              ),
            );
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onChanged?.call(saved);
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
    return AbsorbPointer(
      absorbing: _saving,
      child: Form(
        key: _formKey,
        // Cap the measure and LEFT-align so the field/button don't stretch edge-to-edge
        // in a wide surface — hug the divider (mirrors ContactDetailView). Harmless on a
        // phone (its width is already < 560).
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                TextFormField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !_isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 22),
                // Notes: a single optional freeform description. Multi-line; no validator —
                // an empty box is fine (the server stores NULL). Grows with content.
                TextFormField(
                  controller: _notes,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 4,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                // People — linked contacts, like an event's attendees. Chips + picker.
                _PeopleSection(
                  contacts: _contacts,
                  onAdd: _openPeople,
                  onRemove: _removeContact,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The People block on the task form: a label, the linked contacts as removable chips, and an
/// "Add people" button that opens the shared picker. Mirrors the event form's `_AttendeesSection`.
class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.contacts,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Contact> contacts;
  final VoidCallback onAdd;
  final ValueChanged<Contact> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PEOPLE', style: theme.textTheme.labelMedium),
        const SizedBox(height: 10),
        if (contacts.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in contacts)
                InputChip(
                  avatar: InitialsAvatar(name: c.name, radius: 11),
                  label: Text(c.name),
                  onDeleted: () => onRemove(c),
                ),
            ],
          ),
        if (contacts.isNotEmpty) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_outlined),
          label: const Text('Add people'),
        ),
      ],
    );
  }
}
