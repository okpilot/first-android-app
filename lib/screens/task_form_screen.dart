import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';

/// Add (when [existing] is null) or edit a task. Pops `true` on any successful mutation
/// (save / archive / restore) so the list reloads; pops nothing on cancel.
///
/// Editing a **live** task shows a "Mark complete" toggle + an **Archive** action. Editing an
/// **archived** task hides the toggle and offers **Restore** instead — an archived task is
/// read-only history until it's brought back. Mirrors [ContactFormScreen].
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.repository, this.existing});

  final TasksRepository repository;
  final Task? existing;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
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
    final navigator = Navigator.of(context);
    try {
      if (_isEditing) {
        await widget.repository.update(
          widget.existing!.copyWith(title: _title.text, isDone: _isDone),
        );
      } else {
        await widget.repository.create(Task.draft(title: _title.text));
      }
      if (!mounted) return;
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — please try again")),
      );
    }
  }

  Future<void> _runMutation(
    Future<void> Function() action,
    String failure,
  ) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action();
      if (!mounted) return;
      navigator.pop(true);
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
    final title = !_isEditing
        ? 'New task'
        : (_isArchived ? 'Archived task' : 'Edit task');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // An archived task is read-only history — no Save; only Restore brings it back.
          if (!_isArchived)
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
                // Read-only when archived: an archived task is history until restored, and
                // update_task refuses an archived row (deleted_at guard). Restore first to edit.
                readOnly: _isArchived,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_isEditing,
                onFieldSubmitted: _isArchived ? null : (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              // "Mark complete" only for live tasks — an archived task is history until restored.
              if (_isEditing && !_isArchived) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark complete'),
                  value: _isDone,
                  onChanged: (v) => setState(() => _isDone = v),
                ),
              ],
              // Primary Save — live tasks only (archived is read-only).
              if (!_isArchived) ...[
                const SizedBox(height: 24),
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
                SizedBox(height: _isArchived ? 24 : 12),
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
    );
  }
}
