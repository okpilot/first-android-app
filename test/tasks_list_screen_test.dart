import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/task_detail_screen.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/screens/tasks_list_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/comments_section.dart';
import 'package:first_android_app/widgets/importance_marks.dart';

/// Inert comments repo — the tasks list threads it to the detail, but none of these tests
/// exercise comments. fetchFor returns nothing; the mutators are never reached.
class _InertCommentsRepo implements CommentsRepository {
  @override
  Future<List<Comment>> fetchFor(String parentId) async => const [];
  @override
  Future<Comment> add(Comment draft) async => draft;
  @override
  Future<Comment> edit(Comment comment) async => comment;
  @override
  Future<Comment> archive(String id) async =>
      Comment.draft(parentId: '', body: '');
  @override
  Future<Comment> unarchive(String id) async =>
      Comment.draft(parentId: '', body: '');
}

/// A seedable comments repo — like [_InertCommentsRepo] but its [fetchFor] returns the seeded
/// comments (filtered by parentId), so a wide-pane test can prove the detail pane's embedded
/// [CommentsSection] actually loads the selected task's comments.
class _SeededCommentsRepo implements CommentsRepository {
  _SeededCommentsRepo([List<Comment>? seed]) : _items = seed ?? [];
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

/// A stateful in-memory repo so a complete-toggle actually moves the row between sections.
class _StatefulTasksRepo implements TasksRepository {
  _StatefulTasksRepo(List<Task> initial) : _tasks = [...initial];
  final List<Task> _tasks;
  Task? lastUpdated;

  @override
  Future<List<Task>> fetchAll() async => List.of(_tasks);

  @override
  Future<Task> create(Task draft) async {
    final t = Task(
      id: 'new-${_tasks.length}',
      title: draft.title.trim(),
      notes: draft.notes,
      contacts: draft.contacts,
      importance: draft.importance,
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
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    // Only deleted_at changes server-side — notes/People/title/is_done/importance survive.
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
      contacts: t.contacts,
      importance: t.importance,
      deletedAt: DateTime(2026, 7, 12),
    );
    return _tasks[i];
  }

  @override
  Future<Task> restore(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
      contacts: t.contacts,
      importance: t.importance,
    );
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

/// Minimal fake contacts repo — the list threads it to the form/detail for the People picker,
/// but these tests don't drive the picker (People are seeded on the Task directly).
class _FakeContactsRepo implements ContactsRepository {
  @override
  Future<List<Contact>> fetchAll() async => const [];
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

Widget _screen(
  TasksRepository repo, {
  CommentsRepository? comments,
  ContactsRepository? contacts,
}) => MaterialApp(
  theme: AppTheme.light,
  home: TasksListScreen(
    repository: repo,
    commentsRepository: comments ?? _InertCommentsRepo(),
    contactsRepository: contacts ?? _FakeContactsRepo(),
  ),
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
Future<void> _pumpWide(
  WidgetTester tester,
  TasksRepository repo, {
  CommentsRepository? comments,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1100, 800));
  await tester.pumpWidget(_screen(repo, comments: comments));
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

  testWidgets(
    'completing a task from the list circle preserves its linked People',
    (tester) async {
      // The list's own _toggleDone path (distinct from the detail Complete button) must not
      // clobber People — copyWith(isDone:) has to carry contacts through.
      final repo = _StatefulTasksRepo(const [
        Task(
          id: 't1',
          title: 'Buy milk',
          contacts: [Contact(id: 'c1', name: 'Nadia')],
        ),
      ]);
      await _pumpNarrow(tester, repo);

      await tester.tap(find.byKey(const ValueKey('check_t1')));
      await tester.pumpAndSettle();

      expect(repo.lastUpdated!.isDone, isTrue);
      expect(repo.lastUpdated!.contacts.map((c) => c.id), ['c1']);
    },
  );

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

  testWidgets('wide: New opens the title form IN THE PANE (no push)', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await _pumpWide(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();

    // In-pane title form, no full-screen push (Decision 29: desktop New is in-pane so a single
    // field doesn't float in an empty window).
    expect(find.byType(TaskFormScreen), findsNothing);
    expect(find.byType(TaskEditView), findsOneWidget);
    expect(find.byType(TaskDetailView), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
  });

  testWidgets('wide: the in-pane New form saves and shows the new task', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo(const [
      Task(id: 't1', title: 'Call Nadia'),
    ]);
    await _pumpWide(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Book the venue');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    // The form closed and the new task's read-only detail now fills the pane.
    expect(find.byType(TaskEditView), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TaskDetailView),
        matching: find.text('Book the venue'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'wide: New task from the empty state opens the in-pane form (not a dead-end)',
    (tester) async {
      await _pumpWide(tester, _StatefulTasksRepo(const []));

      // Wide + totally empty → the full-screen empty state (no pane yet).
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.byType(TaskEditView), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();

      // The blank in-pane form renders (button doesn't dead-end); no push.
      expect(find.text('No tasks yet'), findsNothing);
      expect(find.byType(TaskFormScreen), findsNothing);
      expect(find.byType(TaskEditView), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    },
  );

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

  testWidgets(
    'wide: the detail pane embeds the Comments section — live gets the composer, archived is read-only',
    (tester) async {
      final repo = _StatefulTasksRepo([
        const Task(id: 't1', title: 'Call Nadia'),
        Task(
          id: 't9',
          title: 'Old checklist',
          deletedAt: DateTime(2026, 7, 11),
        ),
      ]);
      final comments = _SeededCommentsRepo([
        const Comment(id: 'c1', parentId: 't1', body: 'Left a voicemail.'),
        const Comment(id: 'c9', parentId: 't9', body: 'Closed out last week.'),
      ]);
      await _pumpWide(tester, repo, comments: comments);

      // The first ACTIVE task is auto-selected → its pane loads its own comment and,
      // being live, offers the composer.
      expect(find.byType(TaskDetailView), findsOneWidget);
      expect(find.byType(CommentsSection), findsOneWidget);
      expect(find.text('Left a voicemail.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Comment'), findsOneWidget);

      // Select the archived task (its ValueKey includes isArchived → the pane remounts
      // read-only): its frozen log still renders, but the composer is gone.
      await tester.tap(find.text('ARCHIVED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old checklist'));
      await tester.pumpAndSettle();

      expect(find.byType(CommentsSection), findsOneWidget);
      expect(find.text('Closed out last week.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Comment'), findsNothing);
    },
  );

  testWidgets('a task row shows its importance marks (none for level 0)', (
    tester,
  ) async {
    final repo = _StatefulTasksRepo([
      const Task(id: 't1', title: 'Ship it', importance: 3),
      const Task(id: 't2', title: 'Reply to Dana', importance: 1),
      const Task(id: 't3', title: 'Water plants'), // level 0 → no marks
    ]);
    await _pumpNarrow(tester, repo);

    expect(
      find.byType(ImportanceMarks),
      findsNWidgets(2),
    ); // only the two marked rows
    expect(find.text('!!!'), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
  });
}
