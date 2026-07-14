import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';
import '../widgets/meta_line.dart';
import '../widgets/subtle_button.dart';
import 'task_form_screen.dart';

/// Full-screen read view for one task — the phone / narrow layout. A thin `Scaffold`
/// wrapper around [TaskDetailView]: it owns the "something changed" back-signal (pops
/// `true` on any back-out if the task changed while we were here). The detail body
/// itself lives in [TaskDetailView] so the desktop master-detail pane renders exactly
/// the same thing. Mirrors [ContactDetailScreen]/[ContactDetailView] (Decision 29).
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.repository,
    required this.task,
  });

  final TasksRepository repository;
  final Task task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _dirty = false; // did anything change while we were here?
  // The live task, lifted so an in-place archive/restore retitles the AppBar (the body's
  // own copy flips its controls; the bar tracks the same state here).
  late Task _task = widget.task;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Feed the "something changed" signal back to the list on any back-out.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Defer the pop out of the PopScope callback to avoid re-entering the
        // navigator (which can trip _debugLocked) during system/app-bar back.
        final navigator = Navigator.of(context);
        unawaited(Future.microtask(() => navigator.pop(_dirty)));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_task.isArchived ? 'Archived task' : 'Task'),
        ),
        body: TaskDetailView(
          repository: widget.repository,
          task: widget.task,
          onChanged: (t) => setState(() {
            _dirty = true;
            _task = t;
          }),
        ),
      ),
    );
  }
}

/// The shared detail *body* for one task. Rendered full-screen on phones (inside
/// [TaskDetailScreen]) and embedded in the desktop master-detail pane. It has no
/// `Scaffold`/`AppBar` and NEVER pops — it reports up via [onChanged] and lets the host
/// decide navigation. Read-first: the title, a status pill, the dates, and — as **subtle
/// tonal buttons** distinct from the filled-ink primary (New task / Save) — **Edit**
/// (top-right), **Complete**/**Reopen**, and **Archive**. An **archived** task is
/// read-only history: it drops Edit + completion and offers only **Restore**.
///
/// Completion is a **button** here (not the list's check circle — the circle stays on the
/// list rows). Editing is title-only and lives in [TaskFormScreen]; this view pushes it.
///
/// **Key it so a selection swap remounts** it — the desktop host uses
/// `ValueKey('${task.id}:${task.isArchived}:${task.isDone}')`: `_task` is seeded once in
/// [initState], so a different task AND a list-circle toggle of the *same* task (which
/// changes `isDone` without a rebuild of this view) must each remount to reseed.
class TaskDetailView extends StatefulWidget {
  const TaskDetailView({
    super.key,
    required this.repository,
    required this.task,
    this.onChanged,
  });

  final TasksRepository repository;
  final Task task;

  /// Called with the resulting task after any successful edit / complete / reopen /
  /// archive / restore. The host reloads its list and (on desktop) keeps the selection.
  final ValueChanged<Task>? onChanged;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  late Task _task;
  bool _busy = false; // an in-flight mutation — disables the actions

  bool get _isArchived => _task.isArchived;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  /// Open the title-only editor (a pushed route in both layouts, like Contacts). Applies
  /// the returned task in place and reports up. Only offered for a live task.
  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(repository: widget.repository, existing: _task),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _task = updated);
    widget.onChanged?.call(updated);
  }

  /// Complete ↔ Reopen. Reuses the one update path (title re-sent unchanged via
  /// `copyWith`, which preserves it) — matches the list circle's [_toggleDone].
  void _toggleDone() => _run(
    () => widget.repository.update(_task.copyWith(isDone: !_task.isDone)),
    "Couldn't update — please try again",
  );

  void _archive() => _run(
    () => widget.repository.archive(_task.id),
    "Couldn't archive — please try again",
  );

  void _restore() => _run(
    () => widget.repository.restore(_task.id),
    "Couldn't restore — please try again",
  );

  /// Run a repository mutation that returns the new task: flip [_busy], apply the result
  /// in place (so an archive/restore swaps the control set immediately), report up.
  Future<void> _run(Future<Task> Function() action, String failure) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _task = result;
        _busy = false;
      });
      widget.onChanged?.call(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AbsorbPointer(
      absorbing: _busy,
      // Cap the measure and LEFT-align so the content hugs the list divider in the wide
      // desktop pane rather than floating mid-pane (mirrors ContactDetailView /
      // TaskEditView). Harmless on a phone (its width is already < 560).
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              // Title + top-right Edit (subtle). Edit sits in the body — not the AppBar —
              // so the phone screen and the AppBar-less desktop pane share one control set.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _task.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: (_task.isDone || _isArchived) ? muted : null,
                        decoration: _task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: muted,
                      ),
                    ),
                  ),
                  if (!_isArchived) ...[
                    const SizedBox(width: 12),
                    SubtleButton(
                      onPressed: _busy ? null : _edit,
                      label: 'Edit',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _StatusPill(task: _task),
              if (_isArchived) ...[
                const SizedBox(height: 12),
                Text(
                  'Read-only history — restore to edit.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 22),
              MetaLine(created: _task.createdAt, updated: _task.updatedAt),
              const SizedBox(height: 30),
              // Actions — subtle tonal buttons. Live: Complete/Reopen + Archive.
              // Archived: Restore only.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _isArchived
                    ? [
                        SubtleButton(
                          onPressed: _busy ? null : _restore,
                          icon: Icons.unarchive_outlined,
                          label: 'Restore',
                        ),
                      ]
                    : [
                        SubtleButton(
                          onPressed: _busy ? null : _toggleDone,
                          icon: _task.isDone ? Icons.refresh : Icons.check,
                          label: _task.isDone ? 'Reopen' : 'Complete',
                        ),
                        SubtleButton(
                          onPressed: _busy ? null : _archive,
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small status chip — Active / Completed / Archived. Uses the mono theme's tonal
/// container (`secondaryContainer`); Active gets full-ink text, the rest the muted tone.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, active) = task.isArchived
        ? ('Archived', false)
        : task.isDone
        ? ('Completed', false)
        : ('Active', true);
    final fg = active ? scheme.onSurface : scheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
