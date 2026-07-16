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

import 'support/fakes.dart';

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

/// Models issue #9's exact hazard: the FIRST create COMMITS server-side but the response is lost
/// (persist, THEN throw), so the form shows a failure and the user retries. Because the form holds
/// one stable `_pendingId`, the retry carries the SAME id — and `create_task`'s
/// `on conflict (id) do nothing` collapses it onto the existing row instead of inserting a second.
/// This fake mimics that: it dedupes on id and records the draft id seen on EACH attempt, so a test
/// can assert both the id reuse AND that no duplicate row was created.
class _FlakyRecordingTasksRepo implements TasksRepository {
  final List<String> createIds = [];
  final List<Task> tasks =
      []; // persisted rows — deduped by id, like the real table's PK
  bool _firstResponseLost = false;

  @override
  Future<List<Task>> fetchAll() async => List.of(tasks);
  @override
  Future<Task> create(Task draft) async {
    createIds.add(draft.id);
    // Idempotent insert: a row with this id lands at most once (mimics `on conflict (id) do nothing`).
    final existing = tasks.where((t) => t.id == draft.id).toList();
    final saved = existing.isEmpty ? draft : existing.first;
    if (existing.isEmpty) tasks.add(saved);
    // First attempt: the row committed but the response never arrived → surface as a failed save.
    if (!_firstResponseLost) {
      _firstResponseLost = true;
      throw Exception('offline');
    }
    return saved;
  }

  @override
  Future<Task> update(Task task) async => task;
  @override
  Future<Task> archive(String id) async => const Task(id: '', title: 'x');
  @override
  Future<Task> restore(String id) async => const Task(id: '', title: 'x');
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
    contactsRepository: contactsRepo ?? FakeContactsRepo(),
    taskCategoriesRepository: categoriesRepo ?? FakeTaskCategoriesRepo(),
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
        contactsRepo: FakeContactsRepo(const [
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

  testWidgets('removing a seeded category chip drops it from the save', (
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
            TaskCategory(id: 'k2', name: 'Home', colorHex: '#22A06B'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both seeded categories show as chips.
    expect(find.widgetWithText(InputChip, 'Work'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Home'), findsOneWidget);

    // Tap Work's delete affordance (the InputChip's onDeleted → _removeCategory). The
    // Categories section sits low on the form — scroll it in before hit-testing.
    final workDelete = find.descendant(
      of: find.widgetWithText(InputChip, 'Work'),
      matching: find.byIcon(Icons.clear),
    );
    await tester.ensureVisible(workDelete);
    await tester.pumpAndSettle();
    await tester.tap(workDelete);
    await tester.pumpAndSettle();

    // Work's chip is gone; Home's remains, and the save carries only the survivor.
    expect(find.widgetWithText(InputChip, 'Work'), findsNothing);
    expect(find.widgetWithText(InputChip, 'Home'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdated!.categories.map((c) => c.id), ['k2']);
  });

  testWidgets('adding categories via the picker round-trips into create', (
    tester,
  ) async {
    final repo = _RecordingTasksRepo();
    await _pump(
      tester,
      _form(
        repo,
        categoriesRepo: FakeTaskCategoriesRepo(const [
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
    await _pump(tester, _form(ThrowingTasksRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Prep demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save — please try again"), findsOneWidget);
    // Still on the form (didn't pop) and re-enabled for another try.
    expect(find.text('New task'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
  });

  testWidgets(
    'a failed create then a retry reuses the same client-minted id (idempotency, issue #9)',
    (tester) async {
      final repo = _FlakyRecordingTasksRepo();
      await _pump(tester, _form(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Prep demo');
      // First tap: create throws → snackbar, form stays.
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save — please try again"), findsOneWidget);

      // Second tap: retry succeeds.
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      // The form held ONE stable _pendingId across both attempts, so the DB's
      // `on conflict (id) do nothing` collapses the retry into the same row — no duplicate task.
      expect(repo.createIds, hasLength(2));
      expect(repo.createIds.first, isNotEmpty);
      expect(repo.createIds[0], repo.createIds[1]);
      // The retry did NOT create a second row — the whole point of #9 (the first attempt committed
      // before its response was lost; the same-id retry is a no-op).
      expect(repo.tasks, hasLength(1));
    },
  );

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
              contactsRepository: FakeContactsRepo(),
              taskCategoriesRepository: FakeTaskCategoriesRepo(),
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
