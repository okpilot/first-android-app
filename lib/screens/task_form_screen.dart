import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';

/// Add (when [existing] is null) or edit a task — the title-only form. A thin `Scaffold`
/// wrapper around [TaskEditView]: it pops the saved [Task] on success (or nothing on
/// cancel/back), so the caller can apply it in place. Reached by "New task" and by the
/// detail view's **Edit** (Decision 29). Mirrors [ContactFormScreen].
///
/// Completion and archive/restore are **not** here — they live on [TaskDetailView] as
/// buttons. Editing is title-only, so an archived task (read-only) never reaches this form.
class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({super.key, required this.repository, this.existing});

  final TasksRepository repository;
  final Task? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New task' : 'Edit task')),
      body: TaskEditView(
        repository: repository,
        existing: existing,
        onChanged: (saved) => Navigator.of(context).pop(saved),
      ),
    );
  }
}

/// The shared editor *body* for a task's **title** — create or rename. It has no
/// `Scaffold`/`AppBar` and NEVER pops — it reports the saved task up via [onChanged] and
/// lets the host ([TaskFormScreen]) decide navigation. Title-only by design: completion
/// is the detail view's Complete button, and `copyWith(title: …)` preserves `isDone` /
/// `deletedAt` on an edit so a rename can't clobber the completion state.
class TaskEditView extends StatefulWidget {
  const TaskEditView({
    super.key,
    required this.repository,
    this.existing,
    this.onChanged,
  });

  final TasksRepository repository;
  final Task? existing;

  /// Called with the resulting task after a successful create / rename.
  final ValueChanged<Task>? onChanged;

  @override
  State<TaskEditView> createState() => _TaskEditViewState();
}

class _TaskEditViewState extends State<TaskEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
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
      // Edit is title-only: copyWith preserves isDone / deletedAt so a rename can't
      // clobber the completion the detail's Complete button owns.
      final Task saved = _isEditing
          ? await widget.repository.update(
              widget.existing!.copyWith(title: _title.text),
            )
          : await widget.repository.create(Task.draft(title: _title.text));
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
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !_isEditing,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
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
