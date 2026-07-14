import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tasks_repository.dart';
import '../models/task.dart';
import '../widgets/empty_state.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

/// Fixed width of the master (list) pane in the desktop two-pane layout.
const double kTaskListPaneWidth = 320;

/// Content-area width at/above which Tasks becomes a two-pane master-detail (list + an
/// in-place [TaskDetailView]) instead of the phone's push-to-detail flow (Decision 28
/// Slice D; view-first per Decision 29). = [kTaskListPaneWidth] beside a ≥320dp pane. Measured on the
/// [LayoutBuilder] content area (not the whole window), so it composes with the nav
/// sidebar. == `kTwoPaneBreakpoint` (contacts_list_screen.dart) today, so the whole app
/// changes shape at one window width.
const double kTasksWideBreakpoint = kTaskListPaneWidth + 320;

/// The Tasks screen: active tasks up top, then collapsible **Completed** and **Archived**
/// sections. Owns loading / empty / error states and the entry points to add and open a task.
/// Mirrors [ContactsListScreen]'s Future + `_lastData` stale-guard. On a wide content area it
/// becomes a master-detail: the list on the left, an in-place read-only [TaskDetailView] on the
/// right (narrow pushes [TaskDetailScreen]). Tapping a row opens the task read-first (Decision 29);
/// tapping the row's circle still quick-completes it.
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

  // Desktop master-detail state. The task shown in the detail pane, tracked by id so a list
  // reload can't strand a stale object. Unused in the narrow (push) layout.
  String? _selectedId;

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
      final data = await future;
      // Ignore a stale fetch a newer _load() has superseded, so an older in-flight
      // request can't roll the list back to outdated data (matches event_types_screen).
      if (identical(future, _future)) _lastData = data;
    } catch (_) {
      // The error is surfaced by the FutureBuilder's error branch.
    }
  }

  /// Add a task: push the title-only form (both layouts, like Contacts). On save, select
  /// the new task (so the desktop pane shows its detail) and reload.
  Future<void> _openForm() async {
    final saved = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      setState(() => _selectedId = saved.id);
      unawaited(_load());
    }
  }

  /// Narrow layout: push the read-only detail. Reloads if anything changed while there.
  Future<void> _openDetail(Task task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailScreen(repository: widget.repository, task: task),
      ),
    );
    if (changed == true && mounted) unawaited(_load());
  }

  /// Wide layout: select a task into the detail pane (no navigation).
  void _selectTask(Task task) => setState(() => _selectedId = task.id);

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
    // Decide the layout from the content-area width (the screen sits in HomeShell's Expanded
    // beside the sidebar). Wide is a two-pane master-detail (list + in-place detail); narrow
    // keeps the phone AppBar + FAB + push-to-detail flow untouched.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kTasksWideBreakpoint;
        return Scaffold(
          appBar: wide ? null : AppBar(title: const Text('Tasks')),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
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
                    if (_lastData != null) return _buildBody(wide, _lastData!);
                    return const Center(child: CircularProgressIndicator());
                  default:
                    if (snapshot.hasError) {
                      debugPrint('TASKS_LOAD_FAILED: ${snapshot.error}');
                      return _ErrorState(
                        error: snapshot.error!,
                        onRetry: _load,
                      );
                    }
                    return _buildBody(wide, snapshot.data ?? const <Task>[]);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(bool wide, List<Task> tasks) {
    final active = tasks.where((t) => !t.isDone && !t.isArchived).toList();
    final completed = tasks.where((t) => t.isDone && !t.isArchived).toList();
    final archived = tasks.where((t) => t.isArchived).toList();

    // Nothing at all → the inviting full-screen empty state (with a New task action), in both
    // layouts (no pane) — mirrors Contacts. "New task" pushes the form in both layouts.
    if (active.isEmpty && completed.isEmpty && archived.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No tasks yet',
        message: 'Add your first task to get started.',
        action: FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text('New task'),
        ),
      );
    }

    if (wide) return _twoPane(active, completed, archived);

    // Narrow (phone): tap a row to open its read-only detail. AlwaysScrollable so pull-to-refresh
    // works when content is short.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: _sectionChildren(
        active,
        completed,
        archived,
        onTap: _openDetail,
      ),
    );
  }

  /// The desktop master-detail: the list on the left, an in-place read-only [TaskDetailView] on
  /// the right (Edit pushes the form; New pushes the form too).
  Widget _twoPane(
    List<Task> active,
    List<Task> completed,
    List<Task> archived,
  ) {
    // Selection precedence: the selected id if still present; else the first ACTIVE task; else the
    // empty prompt. (Never auto-open a completed/archived task.)
    final Task? selected = _resolveSelected(active, completed, archived);

    final Widget pane = selected != null
        ? TaskDetailView(
            // Key on archived + done state too: archive/restore keeps the id but flips the control
            // set, and toggling done from the list keeps the id but changes completion — both must
            // remount (id-only would strand the detail's `_task` on stale state).
            key: ValueKey(
              '${selected.id}:${selected.isArchived}:${selected.isDone}',
            ),
            repository: widget.repository,
            task: selected,
            onChanged: (_) => unawaited(_load()),
          )
        : const _SelectPrompt();

    return Row(
      children: [
        SizedBox(
          width: kTaskListPaneWidth,
          child: Column(
            children: [
              _TasksHeader(activeCount: active.length, onNew: _openForm),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                  children: _sectionChildren(
                    active,
                    completed,
                    archived,
                    onTap: _selectTask,
                    selectedId: selected?.id,
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: pane),
      ],
    );
  }

  /// Resolve which task the detail pane shows: the selected id if it's still in the list,
  /// otherwise the first active task, otherwise none (empty prompt).
  Task? _resolveSelected(
    List<Task> active,
    List<Task> completed,
    List<Task> archived,
  ) {
    if (_selectedId != null) {
      for (final t in [...active, ...completed, ...archived]) {
        if (t.id == _selectedId) return t;
      }
    }
    return active.isNotEmpty ? active.first : null;
  }

  /// The active rows + "All clear" note + Completed / Archived sections — one source of truth
  /// shared by the narrow ListView and the wide list pane. [onTap] fires per row (push on narrow,
  /// select on wide); [selectedId] highlights the matching row (two-pane only).
  List<Widget> _sectionChildren(
    List<Task> active,
    List<Task> completed,
    List<Task> archived, {
    required void Function(Task) onTap,
    String? selectedId,
  }) {
    return [
      for (final t in active)
        _TaskTile(
          task: t,
          selected: t.id == selectedId,
          onToggle: () => _toggleDone(t),
          onTap: () => onTap(t),
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
                selected: t.id == selectedId,
                onToggle: () => _toggleDone(t),
                onTap: () => onTap(t),
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
                selected: t.id == selectedId,
                onToggle:
                    null, // archived rows aren't completable — tap opens the read-only detail
                onTap: () => onTap(t),
              ),
          ],
        ),
    ];
  }
}

/// The wide list header: the "Tasks" title + a live active count + an inline "New" button.
/// Sits atop the master (list) pane on wide screens (Decision 28, Slice D). Mirrors Contacts'
/// `_MasterHeader` (title + bare count + short "New") so it fits the 320dp pane without truncating;
/// no search — the active list is short. The count is active-only (completed / archived sit in
/// collapsed sections below).
class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.activeCount, required this.onNew});

  final int activeCount;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          // Flexible title + count group (both ellipsise under pressure) so the fixed-width
          // pane never overflows; the "New" button keeps its natural size on the right.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Tasks',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$activeCount',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in the desktop detail pane when nothing is selected (there are tasks, but none active
/// and none picked). Distinct from the zero-tasks [EmptyState].
class _SelectPrompt extends StatelessWidget {
  const _SelectPrompt();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.check_circle_outline,
      title: 'No task selected',
      message: 'Select a task to view, or add one.',
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
/// Tapping the circle toggles done; tapping the row opens it (push on narrow, select on wide).
/// [selected] tints the row for the desktop two-pane selection.
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.selected = false,
  });

  final Task task;
  final VoidCallback? onToggle; // null for archived rows (not completable)
  final VoidCallback onTap;
  final bool selected;

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

    return ColoredBox(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
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
