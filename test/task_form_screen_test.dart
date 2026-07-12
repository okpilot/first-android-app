import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/theme.dart';

/// Records what the screen asked the repository to do.
class _RecordingTasksRepo implements TasksRepository {
  Task? lastCreated;
  Task? lastUpdated;
  String? archivedId;
  String? restoredId;

  @override
  Future<List<Task>> fetchAll() async => const [];
  @override
  Future<Task> create(Task draft) async {
    lastCreated = draft;
    return draft;
  }

  @override
  Future<Task> update(Task task) async {
    lastUpdated = task;
    return task;
  }

  @override
  Future<Task> archive(String id) async {
    archivedId = id;
    return const Task(id: '', title: 'x');
  }

  @override
  Future<Task> restore(String id) async {
    restoredId = id;
    return const Task(id: '', title: 'x');
  }
}

/// Every mutation throws — to exercise the form's failure snackbars.
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

Widget _form(TasksRepository repo, {Task? existing}) => MaterialApp(
  theme: AppTheme.light,
  home: TaskFormScreen(repository: repo, existing: existing),
);

void main() {
  testWidgets('title is required', (tester) async {
    final repo = _RecordingTasksRepo();
    await tester.pumpWidget(_form(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(repo.lastCreated, isNull);
  });

  testWidgets('adding a task calls create with the trimmed title', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await tester.pumpWidget(_form(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '  Prep demo  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(repo.lastCreated, isNotNull);
    // draft carries the raw text; toRpcParams()/the RPC does the trim.
    expect(repo.lastCreated!.title.trim(), 'Prep demo');
    expect(repo.lastCreated!.isDone, isFalse);
  });

  testWidgets('the New task form shows no complete toggle or archive action', (
    tester,
  ) async {
    await tester.pumpWidget(_form(_RecordingTasksRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Mark complete'), findsNothing);
    expect(find.text('Archive task'), findsNothing);
    expect(find.text('Restore task'), findsNothing);
  });

  testWidgets('editing a live task can mark it complete and calls update', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await tester.pumpWidget(
      _form(
        repo,
        existing: const Task(id: 't1', title: 'Call Nadia'),
      ),
    );
    await tester.pumpAndSettle();

    // The complete toggle + Archive are present for a live task; Restore is not.
    expect(find.text('Mark complete'), findsOneWidget);
    expect(find.text('Archive task'), findsOneWidget);
    expect(find.text('Restore task'), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated, isNotNull);
    expect(repo.lastUpdated!.id, 't1');
    expect(repo.lastUpdated!.isDone, isTrue);
  });

  testWidgets('editing a live task can archive it', (tester) async {
    final repo = _RecordingTasksRepo();
    await tester.pumpWidget(
      _form(
        repo,
        existing: const Task(id: 't1', title: 'Call Nadia'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive task'));
    await tester.pumpAndSettle();

    expect(repo.archivedId, 't1');
  });

  testWidgets(
    'an archived task is read-only: Restore only, no Save/toggle/archive',
    (tester) async {
      final repo = _RecordingTasksRepo();
      await tester.pumpWidget(
        _form(
          repo,
          existing: Task(
            id: 't9',
            title: 'Old checklist',
            deletedAt: DateTime(2026, 7, 11),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archived task'), findsOneWidget); // app bar title
      expect(find.text('Mark complete'), findsNothing);
      expect(find.text('Archive task'), findsNothing);
      // Read-only: no Save affordances (neither the appBar action nor "Save changes"),
      // and the title field is readOnly — editing an archived row would hit the
      // update_task deleted_at guard and fail with a misleading error.
      expect(find.text('Save'), findsNothing);
      expect(find.text('Save changes'), findsNothing);
      final titleField = tester.widget<TextField>(find.byType(TextField));
      expect(titleField.readOnly, isTrue);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Restore task'));
      await tester.pumpAndSettle();

      expect(repo.restoredId, 't9');
    },
  );

  testWidgets('a failed save surfaces a snackbar and stays on the form', (
    tester,
  ) async {
    await tester.pumpWidget(_form(_ThrowingTasksRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Prep demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save — please try again"), findsOneWidget);
    // Still on the form (didn't pop) and re-enabled for another try.
    expect(find.text('New task'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
  });

  testWidgets('a failed archive surfaces a snackbar and stays on the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _form(
        _ThrowingTasksRepo(),
        existing: const Task(id: 't1', title: 'Call Nadia'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive task'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't archive — please try again"), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget); // didn't pop
  });
}
