import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../data/task_categories_repository.dart';
import '../data/tasks_repository.dart';
import '../models/contact.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../util/ids.dart';
import '../util/importance.dart';
import '../widgets/initials_avatar.dart';
import 'category_picker_screen.dart';
import 'contact_picker_screen.dart';
import 'event_types_screen.dart' show TypeSwatch;

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
    required this.taskCategoriesRepository,
    this.existing,
  });

  final TasksRepository repository;
  final ContactsRepository contactsRepository;
  final TaskCategoriesRepository taskCategoriesRepository;
  final Task? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New task' : 'Edit task')),
      body: TaskEditView(
        repository: repository,
        contactsRepository: contactsRepository,
        taskCategoriesRepository: taskCategoriesRepository,
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
    required this.taskCategoriesRepository,
    this.existing,
    this.onChanged,
  });

  final TasksRepository repository;
  final ContactsRepository contactsRepository;
  final TaskCategoriesRepository taskCategoriesRepository;
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
  // Priority 0..3 — seeded from the existing task, set via the segmented picker.
  late int _importance;
  // The linked categories — seeded from the existing task, edited via the picker.
  late List<TaskCategory> _categories;
  bool _saving = false;

  // A stable client-minted id for the new task, reused across save re-taps so a retry after a hung
  // create is idempotent (create_task does `on conflict (id) do nothing`, issue #9). The form pops
  // on success, so a later "New task" gets a fresh State → fresh id. Unused when editing.
  late final String _pendingId = newEntityId();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _contacts = widget.existing?.contacts ?? const [];
    _importance = widget.existing?.importance ?? 0;
    _categories = widget.existing?.categories ?? const [];
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

  /// Open the category picker to edit the linked categories. Same `mounted`-guard + cancel-keeps
  /// semantics as [_openPeople].
  Future<void> _openCategories() async {
    final result = await Navigator.of(context).push<List<TaskCategory>>(
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          repository: widget.taskCategoriesRepository,
          initialSelected: _categories,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _categories = result);
  }

  void _removeCategory(TaskCategory c) => setState(
    () => _categories = [..._categories]..removeWhere((x) => x.id == c.id),
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
                importance: _importance,
                categories: _categories,
              ),
            )
          : await widget.repository.create(
              Task.draft(
                id: _pendingId,
                title: _title.text,
                notes: _notes.text,
                contacts: _contacts,
                importance: _importance,
                categories: _categories,
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
                // Importance — a fixed 0..3 priority. Segmented None / ! / !! / !!! picker.
                _ImportanceSection(
                  value: _importance,
                  onChanged: (v) => setState(() => _importance = v),
                ),
                const SizedBox(height: 28),
                // People — linked contacts, like an event's People. Chips + picker.
                _PeopleSection(
                  contacts: _contacts,
                  onAdd: _openPeople,
                  onRemove: _removeContact,
                ),
                const SizedBox(height: 28),
                // Categories — user-owned colour tags (Decision 40). Chips + picker, mirroring People.
                _CategoriesSection(
                  categories: _categories,
                  onAdd: _openCategories,
                  onRemove: _removeCategory,
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

/// The Importance block on the task form: a label + a segmented None / `!` / `!!` / `!!!` picker
/// (Decision 38). A custom control (not M3 `SegmentedButton`, whose tonal fill fights the mono
/// theme) — one selected segment fills with the neutral chip; a marked level colours its glyphs.
class _ImportanceSection extends StatelessWidget {
  const _ImportanceSection({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IMPORTANCE', style: theme.textTheme.labelMedium),
        const SizedBox(height: 10),
        // Clip so a selected end segment's fill follows the rounded corners.
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var level = 0; level <= 3; level++)
                  _ImportanceSegment(
                    level: level,
                    selected: level == value,
                    first: level == 0,
                    onTap: () => onChanged(level),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One segment of the importance picker. Level 0 shows "None"; 1–3 show the coloured marks. The
/// selected segment fills with the neutral chip and its label takes the level colour (ink for None).
class _ImportanceSegment extends StatelessWidget {
  const _ImportanceSegment({
    required this.level,
    required this.selected,
    required this.first,
    required this.onTap,
  });

  final int level;
  final bool selected;
  final bool first; // no left divider on the first segment
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isNone = level == 0;
    final label = isNone ? 'None' : importanceMarks(level);

    // Selected: level colour for a marked level, ink for None. Unselected: muted.
    final Color fg = !selected
        ? scheme.onSurfaceVariant
        : (importanceColor(level, theme.brightness) ?? scheme.onSurface);

    return Semantics(
      button: true,
      selected: selected,
      label: isNone ? 'None' : 'Importance ${importanceName(level)}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 54),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            border: first
                ? null
                : Border(left: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: isNone ? 0 : 1,
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
                  // ring: the avatar fills with secondaryContainer — the SAME token the
                  // chip now fills with (the mono scheme aliases all three container roles
                  // onto one colour), so without the ring the disc dissolves into the chip
                  // and only bare initials survive.
                  // radius: KEEP it. A Chip pins the avatar's BOX (tightFor(contentSize)),
                  // so radius can't change the disc size here — but `initials_avatar` also
                  // derives `fontSize: radius * 0.7`, and no box constraint reaches a
                  // TextStyle. Drop it and the initials silently jump 7.7px → 14px.
                  avatar: InitialsAvatar(name: c.name, radius: 11, ring: true),
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

/// The Categories block on the task form: a label, the linked categories as removable colour chips,
/// and an "Add categories" button that opens the shared picker. Mirrors [_PeopleSection]; the chip
/// avatar is the category's [TypeSwatch] instead of an initials avatar.
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.categories,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TaskCategory> categories;
  final VoidCallback onAdd;
  final ValueChanged<TaskCategory> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORIES', style: theme.textTheme.labelMedium),
        const SizedBox(height: 10),
        if (categories.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                InputChip(
                  avatar: TypeSwatch(hex: c.colorHex),
                  label: Text(c.name),
                  onDeleted: () => onRemove(c),
                ),
            ],
          ),
        if (categories.isNotEmpty) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.label_outline),
          label: const Text('Add categories'),
        ),
      ],
    );
  }
}
