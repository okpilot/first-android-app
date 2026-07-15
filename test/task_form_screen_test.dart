import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/task_categories_repository.dart';
import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/models/task_category.dart';
import 'package:first_android_app/screens/task_form_screen.dart';
import 'package:first_android_app/theme.dart';

/// Records what the screen asked the repository to do. The form edits title + notes
/// (Decision 29 view-first; notes added later) — completion / archive / restore live on
/// the detail view — so this only needs create + update.
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

/// A minimal fake contacts repo for the People picker. Returns a fixed roster; writes unused.
class _FakeContactsRepo implements ContactsRepository {
  _FakeContactsRepo([this._all = const []]);
  final List<Contact> _all;

  @override
  Future<List<Contact>> fetchAll() async => _all;
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

/// A minimal fake categories repo for the category picker. Returns a fixed list; writes unused.
class _FakeTaskCategoriesRepo implements TaskCategoriesRepository {
  _FakeTaskCategoriesRepo([this._all = const []]);
  final List<TaskCategory> _all;

  @override
  Future<List<TaskCategory>> fetchAll() async => _all;
  @override
  Future<TaskCategory> create(TaskCategory draft) async => draft;
  @override
  Future<TaskCategory> update(TaskCategory category) async => category;
  @override
  Future<void> softDelete(String id) async {}
}

Widget _form(
  TasksRepository repo, {
  Task? existing,
  ContactsRepository? contactsRepo,
  TaskCategoriesRepository? categoriesRepo,
}) => MaterialApp(
  theme: AppTheme.light,
  home: TaskFormScreen(
    repository: repo,
    contactsRepository: contactsRepo ?? _FakeContactsRepo(),
    taskCategoriesRepository: categoriesRepo ?? _FakeTaskCategoriesRepo(),
    existing: existing,
  ),
);

/// Pin a TALL surface before pumping. The form grew a Categories section (Decision 40) and no
/// longer fits the default 800×600 test viewport, so bottom submit buttons fell off-screen and
/// couldn't be hit-tested. A taller surface keeps every field + button reachable (mirrors how the
/// list tests pin surface sizes via `tester.binding.setSurfaceSize`).
Future<void> _pump(WidgetTester tester, Widget app) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title is required', (tester) async {
    final repo = _RecordingTasksRepo();
    await _pump(tester, _form(repo));
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
    await _pump(tester, _form(repo));
    await tester.pumpAndSettle();

    // The Title field is the first TextFormField; Notes is the second.
    await tester.enterText(find.byType(TextFormField).first, '  Prep demo  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(repo.lastCreated, isNotNull);
    // draft carries the raw text; toRpcParams()/the RPC does the trim.
    expect(repo.lastCreated!.title.trim(), 'Prep demo');
    expect(repo.lastCreated!.isDone, isFalse);
    expect(repo.lastCreated!.notes, ''); // empty notes box → '' (server → NULL)
  });

  testWidgets('adding a task with notes passes them to create', (tester) async {
    final repo = _RecordingTasksRepo();
    await _pump(tester, _form(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Call Nadia');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Prefers a call after 15:00.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(repo.lastCreated!.notes, 'Prefers a call after 15:00.');
  });

  testWidgets('editing seeds the notes field and saves the edited notes', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        existing: const Task(id: 't1', title: 'Call Nadia', notes: 'old note'),
      ),
    );
    await tester.pumpAndSettle();

    // The existing notes are seeded into the field...
    expect(find.text('old note'), findsOneWidget);
    // ...and an edit round-trips the new value.
    await tester.enterText(find.byType(TextFormField).last, 'new note');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated!.notes, 'new note');
    expect(repo.lastUpdated!.title, 'Call Nadia'); // untouched title preserved
  });

  testWidgets('importance defaults to None and a picked level reaches create', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(tester, _form(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Ship it');
    // Untouched → level 0. Pick !!! then add.
    await tester.tap(find.text('!!!'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(repo.lastCreated!.importance, 3);
  });

  testWidgets(
    'editing seeds the current importance (untouched save keeps it)',
    (tester) async {
      final repo = _RecordingTasksRepo();
      await _pump(
        tester,
        _form(
          repo,
          existing: const Task(id: 't1', title: 'Call Nadia', importance: 2),
        ),
      );
      await tester.pumpAndSettle();

      // Save untouched — the picker seeded to 2, so update carries it through.
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(repo.lastUpdated!.importance, 2);
    },
  );

  testWidgets('lowering the importance on an edit round-trips', (tester) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        existing: const Task(id: 't1', title: 'Call Nadia', importance: 2),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('!')); // drop 2 → 1
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdated!.importance, 1);
  });

  testWidgets('the form offers no complete toggle or archive action', (
    tester,
  ) async {
    // Both New and Edit — the form never offers completion or archive (those are the
    // detail view's buttons now).
    await _pump(tester, _form(_RecordingTasksRepo()));
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Restore'), findsNothing);

    await _pump(
      tester,
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
    await _pump(
      tester,
      _form(
        repo,
        // A DONE task: a title-only edit must NOT clobber isDone back to false.
        existing: const Task(id: 't1', title: 'Call Nadia', isDone: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget); // app bar title
    await tester.enterText(find.byType(TextFormField).first, 'Call Nadia back');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated, isNotNull);
    expect(repo.lastUpdated!.id, 't1');
    expect(repo.lastUpdated!.title, 'Call Nadia back');
    // copyWith(title:) carried isDone through — the rename didn't reopen the task.
    expect(repo.lastUpdated!.isDone, isTrue);
  });

  testWidgets('editing seeds existing People as chips and saves them through', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        existing: const Task(
          id: 't1',
          title: 'Prep the pitch',
          contacts: [Contact(id: 'c1', name: 'Nadia')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The People section shows the seeded contact as a chip.
    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Nadia'), findsOneWidget);

    // A title-only edit preserves the People through copyWith(contacts:).
    await tester.enterText(find.byType(TextFormField).first, 'Prep the deck');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdated!.contacts.map((c) => c.id), ['c1']);
  });

  testWidgets('removing a seeded chip drops that person from the save', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        existing: const Task(
          id: 't1',
          title: 'Prep the pitch',
          contacts: [
            Contact(id: 'c1', name: 'Nadia'),
            Contact(id: 'c2', name: 'Bo'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both seeded People show as chips.
    expect(find.widgetWithText(InputChip, 'Nadia'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Bo'), findsOneWidget);

    // Tap Nadia's delete affordance (the InputChip's onDeleted → _removeContact).
    // The People section sits low on the form — scroll it into view before hit-testing.
    final nadiaDelete = find.descendant(
      of: find.widgetWithText(InputChip, 'Nadia'),
      matching: find.byIcon(Icons.clear),
    );
    await tester.ensureVisible(nadiaDelete);
    await tester.pumpAndSettle();
    await tester.tap(nadiaDelete);
    await tester.pumpAndSettle();

    // Her chip is gone; Bo's remains, and the save carries only the survivor.
    expect(find.widgetWithText(InputChip, 'Nadia'), findsNothing);
    expect(find.widgetWithText(InputChip, 'Bo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdated!.contacts.map((c) => c.id), ['c2']);
  });

  testWidgets('adding People via the picker round-trips into create', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        contactsRepo: _FakeContactsRepo(const [
          Contact(id: 'c1', name: 'Nadia'),
          Contact(id: 'c2', name: 'Bo'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Prep');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add people'));
    await tester.pumpAndSettle();

    // The picker AppBar uses the 'people' role noun.
    expect(find.text('Add people'), findsWidgets);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Nadia'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    // Back on the form, the picked contact is now a chip; saving carries it into create.
    expect(find.widgetWithText(InputChip, 'Nadia'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    expect(repo.lastCreated!.contacts.map((c) => c.id), ['c1']);
  });

  testWidgets('editing seeds existing categories as chips and saves them', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        existing: const Task(
          id: 't1',
          title: 'Prep the pitch',
          categories: [
            TaskCategory(id: 'k1', name: 'Work', colorHex: '#4E7BC9'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Categories section shows the seeded category as a chip.
    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Work'), findsOneWidget);

    // A title-only edit preserves the categories through copyWith(categories:).
    await tester.enterText(find.byType(TextFormField).first, 'Prep the deck');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdated!.categories.map((c) => c.id), ['k1']);
  });

  testWidgets('adding categories via the picker round-trips into create', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        categoriesRepo: _FakeTaskCategoriesRepo(const [
          TaskCategory(id: 'k1', name: 'Work', colorHex: '#4E7BC9'),
          TaskCategory(id: 'k2', name: 'Home', colorHex: '#22A06B'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Prep');
    final addBtn = find.widgetWithText(OutlinedButton, 'Add categories');
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // In the picker, tick 'Work' and confirm.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    // Back on the form, the picked category is a chip; saving carries it into create.
    expect(find.widgetWithText(InputChip, 'Work'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();
    expect(repo.lastCreated!.categories.map((c) => c.id), ['k1']);
  });

  testWidgets('a failed save surfaces a snackbar and stays on the form', (
    tester,
  ) async {
    await _pump(tester, _form(_ThrowingTasksRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Prep demo');
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
      await _pump(
        tester,
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TaskEditView(
              repository: repo,
              contactsRepository: _FakeContactsRepo(),
              taskCategoriesRepository: _FakeTaskCategoriesRepo(),
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
