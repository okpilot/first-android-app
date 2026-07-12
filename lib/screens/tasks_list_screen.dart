import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';
import '../widgets/empty_state.dart';
import 'task_form_screen.dart';

/// The Tasks screen: active tasks up top, then collapsible **Completed** and **Archived**
/// sections. Owns loading / empty / error states and the entry points to add, complete, edit,
/// and archive a task. Mirrors [ContactsListScreen]'s Future + `_lastData` stale-guard.
class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key, required this.repository});

  final TasksRepository repository;

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  late Future<List<Task>> _future;
  // Last successful data — kept so a refresh/reload shows the current list instead of flashing
  // back to a full-screen spinner while the new fetch is in flight.
  List<Task>? _lastData;

  // Section expansion (collapsed by default — active tasks are the focus).
  bool _showCompleted = false;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Reload. Async so `RefreshIndicator` keeps spinning until the fetch resolves.
  Future<void> _load() async {
    final future = widget.repository.fetchAll();
    setState(() {
      _future = future;
    });
    try {
      _lastData = await future;
    } catch (_) {
      // The error is surfaced by the FutureBuilder's error branch.
    }
  }

  Future<void> _openForm({Task? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(repository: widget.repository, existing: existing),
      ),
    );
    if (changed == true && mounted) _load();
  }

  /// Toggle a task's done state from the list (the circle tap). Reuses the one update path
  /// (title re-sent unchanged — a stated v0 skip). Reloads to reflect the section move.
  Future<void> _toggleDone(Task task) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.update(task.copyWith(isDone: !task.isDone));
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't update — please try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: FutureBuilder<List<Task>>(
          future: _future,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                // Keep showing the current list while refreshing; only show a full-screen
                // spinner on the very first load.
                if (_lastData != null) return _buildBody(_lastData!);
                return const Center(child: CircularProgressIndicator());
              default:
                if (snapshot.hasError) {
                  debugPrint('TASKS_LOAD_FAILED: ${snapshot.error}');
                  return _ErrorState(error: snapshot.error!, onRetry: _load);
                }
                return _buildBody(snapshot.data ?? const <Task>[]);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody(List<Task> tasks) {
    final active = tasks.where((t) => !t.isDone && !t.isArchived).toList();
    final completed = tasks.where((t) => t.isDone && !t.isArchived).toList();
    final archived = tasks.where((t) => t.isArchived).toList();

    // Nothing at all → the inviting full-screen empty state (with a New task action).
    if (active.isEmpty && completed.isEmpty && archived.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No tasks yet',
        message: 'Add your first task to get started.',
        action: FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('New task'),
        ),
      );
    }

    // AlwaysScrollable so pull-to-refresh works even when the content is short.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        for (final t in active)
          _TaskTile(
            task: t,
            onToggle: () => _toggleDone(t),
            onTap: () => _openForm(existing: t),
          ),
        // Active is empty but there's history below — a quiet inline note (not the big empty state).
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'All clear — no active tasks.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (completed.isNotEmpty)
          _Section(
            label: 'Completed',
            count: completed.length,
            expanded: _showCompleted,
            onToggle: () => setState(() => _showCompleted = !_showCompleted),
            children: [
              for (final t in completed)
                _TaskTile(
                  task: t,
                  onToggle: () => _toggleDone(t),
                  onTap: () => _openForm(existing: t),
                ),
            ],
          ),
        if (archived.isNotEmpty)
          _Section(
            label: 'Archived',
            count: archived.length,
            expanded: _showArchived,
            onToggle: () => setState(() => _showArchived = !_showArchived),
            children: [
              for (final t in archived)
                _TaskTile(
                  task: t,
                  onToggle:
                      null, // archived rows aren't completable — tap opens Restore
                  onTap: () => _openForm(existing: t),
                ),
            ],
          ),
      ],
    );
  }
}

/// A collapsible section (Completed / Archived) with an uppercase header, a count, and a
/// rotating chevron. Header style matches the mono theme's `labelMedium`.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}

/// One task row: a circular checkbox (or an archive glyph for archived tasks) + the title.
/// Tapping the circle toggles done; tapping the title opens the edit form.
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  final Task task;
  final VoidCallback? onToggle; // null for archived rows (not completable)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = task.isArchived
        ? Icon(
            Icons.inventory_2_outlined,
            size: 22,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : _CheckCircle(
            key: ValueKey('check_${task.id}'),
            done: task.isDone,
            onTap: onToggle,
          );

    final titleColor = (task.isDone || task.isArchived)
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                task.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: titleColor,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular checkbox: a hairline ring that fills with ink and shows a check when done.
/// Mono — the accent IS the ink (theme.dart).
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({super.key, required this.done, required this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: done ? scheme.primary : scheme.outline,
            width: 1.5,
          ),
        ),
        child: done
            ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
        Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Couldn't load tasks",
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Check that the backend is running, then try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
