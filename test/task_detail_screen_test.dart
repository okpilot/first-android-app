import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_detail_screen.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/comments_section.dart';

/// In-memory comments repo — seed via the constructor; fetchFor filters by parentId so the
/// section loads a task's own comments. Add round-trips (newest-first by id) so the composer
/// path works; edit/archive/unarchive are inert (these tests don't drive them).
class _FakeCommentsRepo implements CommentsRepository {
  _FakeCommentsRepo([List<Comment>? seed]) : _items = seed ?? [];
  final List<Comment> _items;
  int _seq = 0;

  @override
  Future<List<Comment>> fetchFor(String parentId) async =>
      _items.where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
  @override
  Future<Comment> add(Comment draft) async {
    final saved = Comment(
      id: 'c${_seq++}',
      parentId: draft.parentId,
      body: draft.body.trim(),
    );
    _items.add(saved);
    return saved;
  }

  @override
  Future<Comment> edit(Comment comment) async => comment;
  @override
  Future<Comment> archive(String id) async =>
      Comment.draft(parentId: '', body: '');
  @override
  Future<Comment> unarchive(String id) async =>
      Comment.draft(parentId: '', body: '');
}

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
    final t = Task(
      id: 'new-${_tasks.length}',
      title: draft.title.trim(),
      notes: draft.notes,
    );
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
    // Archive changes only deleted_at server-side — notes (and title/is_done) survive.
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
      deletedAt: DateTime(2026, 7, 12),
    );
    return _tasks[i];
  }

  @override
  Future<Task> restore(String id) async {
    restoredId = id;
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
    );
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

Widget _detail(
  TasksRepository repo,
  Task task, {
  CommentsRepository? comments,
}) => MaterialApp(
  theme: AppTheme.light,
  home: TaskDetailScreen(
    repository: repo,
    commentsRepository: comments ?? _FakeCommentsRepo(),
    task: task,
  ),
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

  testWidgets('completing a task keeps its notes visible', (tester) async {
    // The toggle re-sends the task via copyWith(isDone:) — which preserves notes —
    // and re-seeds _task from the result. Guard the whole chain end-to-end: a
    // Complete must not drop the notes block from the re-rendered detail.
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia', notes: 'Prefers a call after 15:00.'),
    ]);
    await tester.pumpWidget(
      _detail(
        repo,
        const Task(
          id: 't1',
          title: 'Call Nadia',
          notes: 'Prefers a call after 15:00.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated!.isDone, isTrue);
    expect(repo.lastUpdated!.notes, 'Prefers a call after 15:00.');
    // The notes survived the toggle and still render read-only.
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Prefers a call after 15:00.'), findsOneWidget);
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
    expect(find.byType(TextFormField), findsNWidgets(2)); // title + notes
  });

  testWidgets('notes render (read-only) under the pill when present', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia', notes: 'Prefers a call after 15:00.'),
    ]);
    await tester.pumpWidget(
      _detail(
        repo,
        const Task(
          id: 't1',
          title: 'Call Nadia',
          notes: 'Prefers a call after 15:00.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget); // the section label
    expect(find.text('Prefers a call after 15:00.'), findsOneWidget);
    // Read-only: the notes are plain text, not an editable field.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('no Notes section when the task has none', (tester) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await tester.pumpWidget(
      _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('an archived task still shows its notes (read-only history)', (
    tester,
  ) async {
    final archived = Task(
      id: 't9',
      title: 'Old checklist',
      notes: 'Superseded by the new onboarding flow.',
      deletedAt: DateTime(2026, 7, 11),
    );
    await tester.pumpWidget(_detail(_StatefulTasksRepo([archived]), archived));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Superseded by the new onboarding flow.'), findsOneWidget);
    // Archived → no Edit, notes are history.
    expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
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

  // ---- the TaskDetailScreen WRAPPER: its "something changed" back-signal + AppBar retitle.
  // The phone list only reloads when this pop returns true, so the dirty signal is load-bearing.

  testWidgets('archiving in place retitles the AppBar to "Archived task"', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await tester.pumpWidget(
      _detail(repo, const Task(id: 't1', title: 'Call Nadia')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Task'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    // The wrapper lifts `_task` purely so the bar tracks the in-place archive.
    expect(find.widgetWithText(AppBar, 'Archived task'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Task'), findsNothing);
  });

  testWidgets('backing out after a change pops true (so the list reloads)', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    Object? popResult;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(
                        repository: repo,
                        commentsRepository: _FakeCommentsRepo(),
                        task: const Task(id: 't1', title: 'Call Nadia'),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Change the task, then back out via the AppBar back button.
    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(popResult, isTrue);
  });

  testWidgets('backing out without a change pops false (no needless reload)', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    Object? popResult;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(
                        repository: repo,
                        commentsRepository: _FakeCommentsRepo(),
                        task: const Task(id: 't1', title: 'Call Nadia'),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Straight back out, nothing touched.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(popResult, isFalse);
  });

  // ---- the Comments section is wired onto the task detail (Slice 2b): live tasks get the
  // composer; an archived task's log is read-only (frozen history).

  testWidgets('a live task shows the Comments section with a composer', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    final comments = _FakeCommentsRepo([
      const Comment(id: 'c1', parentId: 't1', body: 'Left a voicemail.'),
    ]);
    await tester.pumpWidget(
      _detail(
        repo,
        const Task(id: 't1', title: 'Call Nadia'),
        comments: comments,
      ),
    );
    await tester.pumpAndSettle();

    // The section is present, loaded this task's comment, and — being live — offers the composer.
    expect(find.byType(CommentsSection), findsOneWidget);
    expect(find.text('Left a voicemail.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Comment'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // the composer field
  });

  testWidgets(
    'a completed (but not archived) task STILL shows the Comments composer',
    (tester) async {
      // readOnly keys only off _isArchived, not isDone — a done-but-live task is still
      // commentable (design intent: live/completed tasks get the composer).
      final repo = _StatefulTasksRepo(const [
        Task(id: 't1', title: 'Ship the deck', isDone: true),
      ]);
      final comments = _FakeCommentsRepo([
        const Comment(id: 'c1', parentId: 't1', body: 'Sent for review.'),
      ]);
      await tester.pumpWidget(
        _detail(
          repo,
          const Task(id: 't1', title: 'Ship the deck', isDone: true),
          comments: comments,
        ),
      );
      await tester.pumpAndSettle();

      // Completed, not archived → the log is still writable.
      expect(
        find.text('Completed'),
        findsOneWidget,
      ); // status pill confirms done
      expect(find.byType(CommentsSection), findsOneWidget);
      expect(find.text('Sent for review.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Comment'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // the composer field
    },
  );

  testWidgets(
    'an archived task shows the Comments section read-only (no composer)',
    (tester) async {
      final archived = Task(
        id: 't9',
        title: 'Old checklist',
        deletedAt: DateTime(2026, 7, 11),
      );
      final comments = _FakeCommentsRepo([
        const Comment(id: 'c1', parentId: 't9', body: 'Closed out last week.'),
      ]);
      await tester.pumpWidget(
        _detail(_StatefulTasksRepo([archived]), archived, comments: comments),
      );
      await tester.pumpAndSettle();

      // Section present and the frozen log still renders, but read-only → no composer / Comment button.
      expect(find.byType(CommentsSection), findsOneWidget);
      expect(find.text('Closed out last week.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Comment'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
