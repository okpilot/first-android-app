import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_detail_screen.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/screens/tasks_list_screen.dart';
import 'package:first_android_app/theme.dart';

/// A stateful in-memory repo so a complete-toggle actually moves the row between sections.
class _StatefulTasksRepo implements TasksRepository {
  _StatefulTasksRepo(List<Task> initial) : _tasks = [...initial];
  final List<Task> _tasks;
  Task? lastUpdated;

  @override
  Future<List<Task>> fetchAll() async => List.of(_tasks);

  @override
  Future<Task> create(Task draft) async {
    final t = Task(id: 'new-${_tasks.length}', title: draft.title.trim());
    _tasks.add(t);
    return t;
  }

  @override
  Future<Task> update(Task task) async {
    lastUpdated = task;
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i >= 0) _tasks[i] = task;
    return task;
  }

  @override
  Future<Task> archive(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      deletedAt: DateTime(2026, 7, 12),
    );
    return _tasks[i];
  }

  @override
  Future<Task> restore(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(id: t.id, title: t.title, isDone: t.isDone);
    return _tasks[i];
  }
}

/// fetchAll throws while [fail] is true — drives the load-error state, then flip
/// [fail] to false to prove Retry recovers.
class _FailingRepo implements TasksRepository {
  _FailingRepo({this.tasks = const []});
  bool fail = true;
  final List<Task> tasks;

  @override
  Future<List<Task>> fetchAll() async {
    if (fail) throw Exception('offline');
    return List.of(tasks);
  }

  @override
  Future<Task> create(Task draft) => throw UnimplementedError();
  @override
  Future<Task> update(Task task) => throw UnimplementedError();
  @override
  Future<Task> archive(String id) => throw UnimplementedError();
  @override
  Future<Task> restore(String id) => throw UnimplementedError();
}

/// Loads fine, but a complete-toggle write throws — to exercise the list's
/// "Couldn't update" snackbar path.
class _UpdateFailsRepo implements TasksRepository {
  _UpdateFailsRepo(this.tasks);
  final List<Task> tasks;

  @override
  Future<List<Task>> fetchAll() async => List.of(tasks);
  @override
  Future<Task> update(Task task) => throw Exception('offline');
  @override
  Future<Task> create(Task draft) => throw UnimplementedError();
  @override
  Future<Task> archive(String id) => throw UnimplementedError();
  @override
  Future<Task> restore(String id) => throw UnimplementedError();
}

Widget _screen(TasksRepository repo) => MaterialApp(
  theme: AppTheme.light,
  home: TasksListScreen(repository: repo),
);

/// Pump the screen pinned to a **phone-width** surface. The default test surface is 800px, which
/// is ≥ [kTasksWideBreakpoint] (640) and would trip the wide desktop layout — so the phone-chrome
/// tests must pin a narrow surface (mirrors `contacts_master_detail_test.dart`).
Future<void> _pumpNarrow(WidgetTester tester, TasksRepository repo) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(360, 800));
  await tester.pumpWidget(_screen(repo));
  await tester.pumpAndSettle();
}

/// Pump the screen pinned to a **wide** (desktop) surface → the list-header layout.
Future<void> _pumpWide(WidgetTester tester, TasksRepository repo) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1100, 800));
  await tester.pumpWidget(_screen(repo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders active tasks', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
      Task(id: 't2', title: 'Prep demo'),
    ]);
    await _pumpNarrow(tester, repo);

    expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);
    expect(find.text('Call Nadia'), findsOneWidget);
    expect(find.text('Prep demo'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no tasks', (tester) async {
    await _pumpNarrow(tester, _StatefulTasksRepo(const []));

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('New task'), findsWidgets); // FAB + empty-state CTA
  });

  testWidgets('a completed task lives in a collapsed Completed section', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Active one'),
      Task(id: 't2', title: 'Done one', isDone: true),
    ]);
    await _pumpNarrow(tester, repo);

    // Header present with a count; the done title is hidden until expanded.
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('Done one'), findsNothing);

    await tester.tap(find.text('COMPLETED'));
    await tester.pumpAndSettle();
    expect(find.text('Done one'), findsOneWidget);
  });

  testWidgets('archived tasks live in a collapsed Archived section', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo([
      const Task(id: 't1', title: 'Active one'),
      Task(id: 't9', title: 'Old checklist', deletedAt: DateTime(2026, 7, 11)),
    ]);
    await _pumpNarrow(tester, repo);

    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.text('Old checklist'), findsNothing);

    await tester.tap(find.text('ARCHIVED'));
    await tester.pumpAndSettle();
    expect(find.text('Old checklist'), findsOneWidget);
  });

  testWidgets('tapping the circle completes a task and moves it out of active', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [Task(id: 't1', title: 'Buy milk')]);
    await _pumpNarrow(tester, repo);

    expect(find.text('Buy milk'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('check_t1')));
    await tester.pumpAndSettle();

    // update() was called with is_done flipped to true...
    expect(repo.lastUpdated, isNotNull);
    expect(repo.lastUpdated!.id, 't1');
    expect(repo.lastUpdated!.isDone, isTrue);
    // ...and the row left the (visible) active list — it's now under collapsed Completed.
    expect(find.text('Buy milk'), findsNothing);
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state, and Retry recovers', (
    tester,
  ) async {
    final repo = _FailingRepo(
      tasks: const [Task(id: 't1', title: 'Buy milk')],
    );
    await _pumpNarrow(tester, repo);

    expect(find.text("Couldn't load tasks"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    expect(find.text('Buy milk'), findsNothing);

    // Backend comes back; Retry re-fetches and the list renders.
    repo.fail = false;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load tasks"), findsNothing);
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets(
    'with only history, active shows the "All clear" note (not the big empty state)',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Done one', isDone: true),
      ]);
      await _pumpNarrow(tester, repo);

      // The quiet inline note, not the full-screen "No tasks yet".
      expect(find.text('All clear — no active tasks.'), findsOneWidget);
      expect(find.text('No tasks yet'), findsNothing);
      expect(find.text('COMPLETED'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a live task row opens the read-only detail (not the form)',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
      ]);
      await _pumpNarrow(tester, repo);

      await tester.tap(find.text('Call Nadia'));
      await tester.pumpAndSettle();

      // Navigated to the read-only detail: the "Task" bar, the Complete/Edit buttons, and
      // NO editable title field (that only appears once you press Edit).
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Task'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Mark complete'), findsNothing);
    },
  );

  testWidgets(
    'tapping an archived task row opens the read-only detail with Restore',
    (tester) async {
      final repo = _StatefulTasksRepo([
        Task(
          id: 't9',
          title: 'Old checklist',
          deletedAt: DateTime(2026, 7, 11),
        ),
      ]);
      await _pumpNarrow(tester, repo);

      // Expand the collapsed Archived section, then tap the row.
      await tester.tap(find.text('ARCHIVED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old checklist'));
      await tester.pumpAndSettle();

      // Archived → read-only history: Restore, not Complete/Edit.
      expect(find.widgetWithText(AppBar, 'Archived task'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
    },
  );

  testWidgets('a failed complete-toggle surfaces the update snackbar', (
    tester,
  ) async {
    final repo = _UpdateFailsRepo(const [Task(id: 't1', title: 'Buy milk')]);
    await _pumpNarrow(tester, repo);

    await tester.tap(find.byKey(const ValueKey('check_t1')));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't update — please try again"), findsOneWidget);
    // The row stays put (nothing moved, because the write failed).
    expect(find.text('Buy milk'), findsOneWidget);
  });

  // ---- wide (desktop) master-detail — Decision 28 Slice D; view-first per Decision 29 ----

  testWidgets(
    'wide: selecting a task opens its DETAIL in place, no push (+ no AppBar/FAB)',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
        Task(id: 't2', title: 'Prep demo'),
      ]);
      await _pumpWide(tester, repo);

      // No phone chrome; the header (title + inline New) + an in-place read-only detail pane
      // instead of a pushed screen.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.widgetWithText(FilledButton, 'New'), findsOneWidget);
      expect(find.byType(TaskDetailView), findsOneWidget);
      expect(find.byType(TaskDetailScreen), findsNothing); // no push
      expect(find.byType(TaskFormScreen), findsNothing);
      // First active task auto-selected → its title shows in the detail pane (not just the row).
      expect(
        find.descendant(
          of: find.byType(TaskDetailView),
          matching: find.text('Call Nadia'),
        ),
        findsOneWidget,
      );

      // Selecting the second row swaps the pane in place — still no route push.
      await tester.tap(find.text('Prep demo'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TaskDetailView),
          matching: find.text('Prep demo'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('wide: auto-selects the first ACTIVE task (not a done one)', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
      Task(id: 't2', title: 'Done one', isDone: true),
    ]);
    await _pumpWide(tester, repo);

    expect(find.byType(TaskDetailView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskDetailView),
        matching: find.text('Call Nadia'),
      ),
      findsOneWidget,
    );
    // The live-task Complete button confirms the pane is showing the active task's detail.
    expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
  });

  testWidgets(
    'wide: New task pushes the title-only form (not an in-pane draft)',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
      ]);
      await _pumpWide(tester, repo);

      await tester.tap(find.widgetWithText(FilledButton, 'New'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskFormScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'New task'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    },
  );

  testWidgets('wide: New task from the empty state pushes the form', (
    tester,
  ) async {
    await _pumpWide(tester, _StatefulTasksRepo(const []));

    // Wide + totally empty → the full-screen empty state (no pane yet).
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.byType(TaskDetailView), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'New task'));
    await tester.pumpAndSettle();

    // Pushes the title-only form (no in-pane draft anymore).
    expect(find.byType(TaskFormScreen), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
  });

  testWidgets(
    'wide: toggling the selected task done from the list remounts the pane with the new state',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
        Task(id: 't2', title: 'Prep demo'),
      ]);
      await _pumpWide(tester, repo);

      // Select t2 (its row title is unique — t1 is the auto-selected one already in the pane).
      await tester.tap(find.text('Prep demo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);

      // Toggle t2 done from the LEFT list circle — not the pane.
      await tester.tap(find.byKey(const ValueKey('check_t2')));
      await tester.pumpAndSettle();

      // The pane remounted (its key includes isDone) so the detail now reads as completed:
      // Complete flipped to Reopen, and the selected task is still shown.
      expect(find.widgetWithText(FilledButton, 'Reopen'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TaskDetailView),
          matching: find.text('Prep demo'),
        ),
        findsOneWidget,
      );
    },
  );
}
