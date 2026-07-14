import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_detail_screen.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/theme.dart';

/// A stateful fake so archive/restore return a genuinely (un)archived Task — the detail
/// view applies the *returned* task in place, so `archive()` must set `deletedAt` and
/// `restore()` must clear it for the control set to flip (mirrors the list test's repo).
class _StatefulTasksRepo implements TasksRepository {
  _StatefulTasksRepo(List<Task> initial) : _tasks = [...initial];
  final List<Task> _tasks;
  Task? lastUpdated;
  String? archivedId;
  String? restoredId;

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
    archivedId = id;
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
    restoredId = id;
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(id: t.id, title: t.title, isDone: t.isDone);
    return _tasks[i];
  }
}

/// Every mutation throws — to exercise the detail's failure snackbars.
class _ThrowingTasksRepo implements TasksRepository {
  @override
  Future<List<Task>> fetchAll() async => const [];
  @override
  Future<Task> create(Task draft) => throw Exception('offline');
  @override
  Future<Task> update(Task task) => throw Exception('offline');
  @override
  Future<Task> archive(String id) => throw Exception('offline');
  @override
  Future<Task> restore(String id) => throw Exception('offline');
}

Widget _detail(TasksRepository repo, Task task) => MaterialApp(
  theme: AppTheme.light,
  home: TaskDetailScreen(repository: repo, task: task),
);

void main() {
  testWidgets(
    'a live task reads: title, Active pill, Edit + Complete + Archive',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
      ]);
      await tester.pumpWidget(
        _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Task'), findsOneWidget);
      expect(find.text('Call Nadia'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      // Read-first: no editable field on the detail; Edit is a button.
      expect(find.byType(TextFormField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Archive'), findsOneWidget);
    },
  );

  testWidgets('Complete marks it done and flips the button to Reopen', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await tester.pumpWidget(
      _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated, isNotNull);
    expect(repo.lastUpdated!.id, 't1');
    expect(repo.lastUpdated!.isDone, isTrue);
    // In-place: the control set now reads as a completed task.
    expect(find.text('Completed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reopen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
  });

  testWidgets('Reopen re-opens a completed task', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Done one', isDone: true),
    ]);
    await tester.pumpWidget(
      _detail(repo, const Task(id: 't1', title: 'Done one', isDone: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reopen'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated!.isDone, isFalse);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets(
    'Archive archives the task and swaps to a read-only Restore view',
    (tester) async {
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Call Nadia'),
      ]);
      await tester.pumpWidget(
        _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(repo.archivedId, 't1');
      // Now read-only history: Restore only, no Edit/Complete/Archive.
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Read-only history — restore to edit.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
    },
  );

  testWidgets(
    'an archived task reads Restore-only, and Restore brings it back',
    (tester) async {
      final repo = _StatefulTasksRepo([
        Task(
          id: 't9',
          title: 'Old checklist',
          deletedAt: DateTime(2026, 7, 11),
        ),
      ]);
      await tester.pumpWidget(
        _detail(
          repo,
          Task(
            id: 't9',
            title: 'Old checklist',
            deletedAt: DateTime(2026, 7, 11),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Archived task'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(repo.restoredId, 't9');
      // Back to a live task: Edit + Complete return.
      expect(find.text('Active'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
    },
  );

  testWidgets('Edit pushes the title-only form', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await tester.pumpWidget(
      _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskFormScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Edit task'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget); // the title field
  });

  testWidgets('a failed complete surfaces a snackbar and stays put', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detail(_ThrowingTasksRepo(), const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't update — please try again"), findsOneWidget);
    // Still a live task (the write failed).
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('a failed archive surfaces a snackbar and stays put', (
    tester,
  ) async {
    await tester.pumpWidget(
      _detail(_ThrowingTasksRepo(), const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't archive — please try again"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Archive'), findsOneWidget);
  });
}
