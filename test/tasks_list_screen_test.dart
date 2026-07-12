import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/task.dart';
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

void main() {
  testWidgets('renders active tasks', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
      Task(id: 't2', title: 'Prep demo'),
    ]);
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);
    expect(find.text('Call Nadia'), findsOneWidget);
    expect(find.text('Prep demo'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no tasks', (tester) async {
    await tester.pumpWidget(_screen(_StatefulTasksRepo(const [])));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

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
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      // The quiet inline note, not the full-screen "No tasks yet".
      expect(find.text('All clear — no active tasks.'), findsOneWidget);
      expect(find.text('No tasks yet'), findsNothing);
      expect(find.text('COMPLETED'), findsOneWidget);
    },
  );

  testWidgets('tapping a live task row opens the edit form', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call Nadia'));
    await tester.pumpAndSettle();

    // Navigated to the edit form (live task → "Edit task" + the complete toggle).
    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
  });

  testWidgets('tapping an archived task row opens the form in Restore mode', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo([
      Task(id: 't9', title: 'Old checklist', deletedAt: DateTime(2026, 7, 11)),
    ]);
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // Expand the collapsed Archived section, then tap the row.
    await tester.tap(find.text('ARCHIVED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old checklist'));
    await tester.pumpAndSettle();

    // Archived → read-only history: Restore, not the toggle/archive.
    expect(find.text('Archived task'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restore task'), findsOneWidget);
    expect(find.text('Mark complete'), findsNothing);
  });

  testWidgets('a failed complete-toggle surfaces the update snackbar', (
    tester,
  ) async {
    final repo = _UpdateFailsRepo(const [Task(id: 't1', title: 'Buy milk')]);
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('check_t1')));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't update — please try again"), findsOneWidget);
    // The row stays put (nothing moved, because the write failed).
    expect(find.text('Buy milk'), findsOneWidget);
  });
}
