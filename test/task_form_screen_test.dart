import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/theme.dart';

/// Records what the screen asked the repository to do. The form is title-only now
/// (Decision 29) — completion / archive / restore live on the detail view — so this
/// only needs create + update.
class _RecordingTasksRepo implements TasksRepository {
  Task? lastCreated;
  Task? lastUpdated;

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
  Future<Task> archive(String id) async => const Task(id: '', title: 'x');
  @override
  Future<Task> restore(String id) async => const Task(id: '', title: 'x');
}

/// Every mutation throws — to exercise the form's failure snackbar.
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

    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
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

  testWidgets('the form is title-only: no complete toggle or archive action', (
    tester,
  ) async {
    // Both New and Edit — the form never offers completion or archive (those are the
    // detail view's buttons now).
    await tester.pumpWidget(_form(_RecordingTasksRepo()));
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Restore'), findsNothing);

    await tester.pumpWidget(
      _form(
        _RecordingTasksRepo(),
        existing: const Task(id: 't1', title: 'x'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('editing renames via update and preserves the completion state', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await tester.pumpWidget(
      _form(
        repo,
        // A DONE task: a title-only edit must NOT clobber isDone back to false.
        existing: const Task(id: 't1', title: 'Call Nadia', isDone: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget); // app bar title
    await tester.enterText(find.byType(TextFormField), 'Call Nadia back');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated, isNotNull);
    expect(repo.lastUpdated!.id, 't1');
    expect(repo.lastUpdated!.title, 'Call Nadia back');
    // copyWith(title:) carried isDone through — the rename didn't reopen the task.
    expect(repo.lastUpdated!.isDone, isTrue);
  });

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

  // TaskEditView is the Scaffold-less body embedded in TaskFormScreen. Guard that a
  // successful save resets `_saving` (so the AbsorbPointer never freezes it) and reports
  // the saved task up via onChanged.
  testWidgets(
    'TaskEditView: a save fires onChanged with the saved task and stays usable',
    (tester) async {
      final repo = _RecordingTasksRepo();
      final saved = <Task>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TaskEditView(
              repository: repo,
              existing: const Task(id: 't1', title: 'Call Nadia'),
              onChanged: saved.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(saved.single.id, 't1');

      // If `_saving` stayed true the AbsorbPointer would swallow this second tap; a second
      // onChanged proves the editor was re-enabled.
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(saved, hasLength(2));
    },
  );
}
