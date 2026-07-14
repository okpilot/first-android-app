import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/event_types_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/screens/home_shell.dart';

// Fakes copied verbatim from widget_test.dart — the project's hand-written
// private-fake-repository convention (no mockito). Each repo's method set differs,
// so they are NOT interchangeable.
class _FakeRepo implements ContactsRepository {
  _FakeRepo(this.contacts);
  final List<Contact> contacts;

  @override
  Future<List<Contact>> fetchAll() async => contacts;
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeEventsRepo implements EventsRepository {
  @override
  Future<List<Event>> fetchAll() async => const [];
  @override
  Future<Event> create(Event draft) async => draft;
  @override
  Future<Event> update(Event event) async => event;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeEventTypesRepo implements EventTypesRepository {
  @override
  Future<List<EventType>> fetchAll() async => const [];
  @override
  Future<EventType> create(EventType draft) async => draft;
  @override
  Future<EventType> update(EventType type) async => type;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeCommentsRepo implements CommentsRepository {
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

class _FakeTasksRepo implements TasksRepository {
  @override
  Future<List<Task>> fetchAll() async => const [];
  @override
  Future<Task> create(Task draft) async => draft;
  @override
  Future<Task> update(Task task) async => task;
  @override
  Future<Task> archive(String id) async => const Task(id: '', title: 'x');
  @override
  Future<Task> restore(String id) async => const Task(id: '', title: 'x');
}

Widget _shell() => MaterialApp(
  home: HomeShell(
    // One contact so the Contacts screen shows its list (not the empty state,
    // whose button would duplicate the FAB's "New contact" text).
    repository: _FakeRepo(const [Contact(id: '1', name: 'Ada Lovelace')]),
    eventsRepository: _FakeEventsRepo(),
    eventTypesRepository: _FakeEventTypesRepo(),
    commentsRepository: _FakeCommentsRepo(),
    tasksRepository: _FakeTasksRepo(),
  ),
);

void main() {
  testWidgets('wide screen shows the labelled sidebar and switches destination', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // Sidebar present (brand only exists in the sidebar); bottom bar absent.
    expect(find.text('CRM+'), findsOneWidget);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Contacts is the initial destination — the seeded contact shows in the wide
    // master-detail (list row + detail pane). (On wide there's no "New contact" FAB;
    // that's the header "New" button now — Decision 28 Slice C.)
    expect(find.text('Ada Lovelace'), findsWidgets);

    // Tapping the sidebar's Tasks item switches the visible screen. Target the sidebar
    // row (an InkWell) directly so the tap doesn't depend on the identically-titled
    // TasksListScreen AppBar being offstage.
    await tester.tap(find.widgetWithText(InkWell, 'Tasks'));
    await tester.pumpAndSettle();

    // The Tasks destination is actually the visible one, not merely "something other than
    // Contacts". On this wide surface Tasks has no AppBar (Decision 28 Slice D), so assert the
    // Tasks empty state instead — layout-agnostic, and the fake Tasks repo returns no tasks.
    expect(find.text('No tasks yet'), findsOneWidget);
    // …and the Contacts screen is no longer visible.
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('wide screen: the bottom-pinned Settings item selects the '
      'Settings destination', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // Settings is rendered by a separate code path from the looped items (after a
    // Spacer, wired to `lastIndex`), so its index math needs its own coverage.
    // Before selection the Settings screen is offstage, so its "Event types" row
    // is absent and "Settings" unambiguously names the sidebar item.
    expect(find.text('Event types'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'Settings'));
    await tester.pumpAndSettle();

    // The Settings screen is now the visible destination.
    expect(find.text('Event types'), findsOneWidget);
  });

  testWidgets('narrow screen shows the bottom NavigationBar, not the sidebar', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('CRM+'), findsNothing);
  });
}
