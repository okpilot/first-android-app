import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';

/// Full-screen add/edit for a task — the phone / narrow layout. A thin `Scaffold`
/// wrapper around [TaskEditView]: it pops `true` on any successful mutation (save /
/// archive / restore) so the list reloads. The editor body itself lives in
/// [TaskEditView] so the desktop master-detail pane renders exactly the same thing
/// (Decision 28, Slice D). Mirrors [ContactDetailScreen]/[ContactDetailView].
class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({super.key, required this.repository, this.existing});

  final TasksRepository repository;
  final Task? existing;

  @override
  Widget build(BuildContext context) {
    final title = existing == null
        ? 'New task'
        : (existing!.isArchived ? 'Archived task' : 'Edit task');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // Save/Add lives in the body button (no AppBar action) so the pushed form and
      // the desktop pane share one control set. Any mutation pops `true`.
      body: TaskEditView(
        repository: repository,
        existing: existing,
        onChanged: (_) => Navigator.of(context).pop(true),
      ),
    );
  }
}

/// The shared editor *body* for one task. Rendered full-screen on phones (inside
/// [TaskFormScreen]) and embedded in the desktop master-detail pane. It has no
/// `Scaffold`/`AppBar` and NEVER pops — it reports up via [onChanged] and lets the host
/// decide navigation. Title field + "Mark complete" toggle + the Save/Add and
/// Archive/Restore buttons all live here so both layouts share one control set.
///
/// Editing a **live** task shows the toggle + an **Archive** action; editing an
/// **archived** task hides the toggle and offers **Restore** instead — an archived task
/// is read-only history until it's brought back.
///
/// **Key it so a selection swap remounts** it — the host uses
/// `ValueKey('${task.id}:${task.isArchived}')` (its controller / `_isDone` / `_isArchived`
/// branch are seeded once in [initState], so both a different task AND an archive/restore
/// of the same task must remount to pick up the new control set).
class TaskEditView extends StatefulWidget {
  const TaskEditView({
    super.key,
    required this.repository,
    this.existing,
    this.onChanged,
    this.showHeader = false,
  });

  final TasksRepository repository;
  final Task? existing;

  /// Called with the resulting task after any successful create / update / archive /
  /// restore. The host reloads its list and (on desktop) keeps the row selected.
  final ValueChanged<Task>? onChanged;

  /// When embedded in the desktop pane (no `AppBar`), render the in-body heading so the pane
  /// has a clear focal point. Left `false` for the narrow wrapper, whose `AppBar` titles it.
  final bool showHeader;

  @override
  State<TaskEditView> createState() => _TaskEditViewState();
}

class _TaskEditViewState extends State<TaskEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late bool _isDone;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isArchived => widget.existing?.isArchived ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _isDone = e?.isDone ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final Task saved = _isEditing
          ? await widget.repository.update(
              widget.existing!.copyWith(title: _title.text, isDone: _isDone),
            )
          : await widget.repository.create(Task.draft(title: _title.text));
      if (!mounted) return;
      // Reset _saving BEFORE reporting up: unlike the old pop-on-save screen, the
      // desktop pane stays mounted after onChanged, so a stuck `_saving` would freeze
      // the editor (AbsorbPointer + spinner). The narrow wrapper pops right after.
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

  Future<void> _runMutation(
    Future<Task> Function() action,
    String failure,
  ) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Task result = await action();
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onChanged?.call(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  void _archive() => _runMutation(
    () => widget.repository.archive(widget.existing!.id),
    "Couldn't archive — please try again",
  );

  void _restore() => _runMutation(
    () => widget.repository.restore(widget.existing!.id),
    "Couldn't restore — please try again",
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = !_isEditing
        ? 'New task'
        : (_isArchived ? 'Archived task' : 'Edit task');

    return AbsorbPointer(
      absorbing: _saving,
      child: Form(
        key: _formKey,
        // Cap the measure and LEFT-align so the field/buttons don't stretch edge-to-edge in
        // the wide desktop pane — hug the divider, the empty space belongs on the far right
        // (mirrors ContactDetailView). Harmless on a phone (its width is already < 560).
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                // In-pane heading (the AppBar titles the narrow wrapper instead) — gives the
                // pane one clear focal point / hierarchy.
                if (widget.showHeader) ...[
                  Text(heading, style: theme.textTheme.titleLarge),
                  if (_isArchived) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Read-only history — restore to edit.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
                TextFormField(
                  controller: _title,
                  // Read-only when archived: an archived task is history until restored, and
                  // update_task refuses an archived row (deleted_at guard). Restore first to edit.
                  readOnly: _isArchived,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !_isEditing,
                  onFieldSubmitted: _isArchived ? null : (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                // "Mark complete" only for live tasks — a compact left-grouped toggle (not a
                // full-width spread SwitchListTile) so it reads as one intentional control.
                if (_isEditing && !_isArchived) ...[
                  const SizedBox(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isDone = !_isDone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _isDone,
                            onChanged: (v) => setState(() => _isDone = v),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Mark complete',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Primary Save — live tasks only (archived is read-only).
                if (!_isArchived) ...[
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
                // Archive (live) / Restore (archived) — only when editing an existing task.
                if (_isEditing) ...[
                  SizedBox(height: _isArchived ? 0 : 12),
                  if (_isArchived)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _restore,
                      icon: const Icon(Icons.unarchive_outlined),
                      label: const Text('Restore task'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _archive,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive task'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
