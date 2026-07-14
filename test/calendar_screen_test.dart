import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
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
import 'package:first_android_app/screens/calendar_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/type_label.dart';

class _FakeContactsRepo implements ContactsRepository {
  _FakeContactsRepo([this.contacts = const []]);
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
  _FakeEventsRepo([this.events = const []]);
  final List<Event> events;
  @override
  Future<List<Event>> fetchAll() async => events;
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

class _FailingEventsRepo implements EventsRepository {
  @override
  Future<List<Event>> fetchAll() async => throw Exception('network error');
  @override
  Future<Event> create(Event draft) async => draft;
  @override
  Future<Event> update(Event event) async => event;
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Widget _calendar({
  DateTime? initialDate,
  List<Event> events = const [],
  List<Contact> contacts = const [],
}) => _wrap(
  CalendarScreen(
    initialDate: initialDate,
    eventsRepository: _FakeEventsRepo(events),
    contactsRepository: _FakeContactsRepo(contacts),
    eventTypesRepository: _FakeEventTypesRepo(),
    commentsRepository: _FakeCommentsRepo(),
  ),
);

void main() {
  testWidgets('shows all four view tabs', (tester) async {
    await tester.pumpWidget(_calendar(initialDate: DateTime(2026, 7, 8)));
    await tester.pumpAndSettle();

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('3-day'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('tapping a month day updates the selected-day panel', (
    tester,
  ) async {
    await tester.pumpWidget(_calendar(initialDate: DateTime(2026, 7, 8)));
    await tester.pumpAndSettle();

    // Jul 15 is unique in the July 2026 grid (Jun 29 … Aug 9).
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.textContaining('15 JUL'), findsOneWidget);
    expect(find.text('No events'), findsOneWidget);
  });

  testWidgets('empty timeline + agenda render their empty states', (
    tester,
  ) async {
    await tester.pumpWidget(_calendar(initialDate: DateTime(2026, 7, 8)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('No events yet'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing scheduled'), findsOneWidget);
  });

  testWidgets('the month panel lists a day\'s events and opens detail', (
    tester,
  ) async {
    final event = Event(
      id: 'e1',
      title: 'Coffee with Ada',
      date: DateTime(2026, 7, 8),
      allDay: false,
      startMin: 9 * 60,
      endMin: 9 * 60 + 45,
      attendees: const [Contact(id: 'c1', name: 'Ada Lovelace')],
    );
    await tester.pumpWidget(
      _calendar(initialDate: DateTime(2026, 7, 8), events: [event]),
    );
    await tester.pumpAndSettle();

    // The selected day == focused day, so the panel lists it right away.
    expect(find.text('Coffee with Ada'), findsOneWidget);

    await tester.ensureVisible(find.text('Coffee with Ada'));
    await tester.tap(find.text('Coffee with Ada'));
    await tester.pumpAndSettle();

    // Now on the detail screen — the Type row shows "No type" for an untyped event.
    expect(find.text('Delete event'), findsOneWidget);
    expect(find.text('ATTENDEES · 1'), findsOneWidget);
    expect(find.text('No type'), findsOneWidget);
  });

  testWidgets('a typed event shows its dot and name in the month panel', (
    tester,
  ) async {
    final event = Event(
      id: 'e3',
      title: 'Standup',
      date: DateTime(2026, 7, 8),
      allDay: false,
      startMin: 9 * 60,
      endMin: 9 * 60 + 15,
      type: const EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9'),
    );
    await tester.pumpWidget(
      _calendar(initialDate: DateTime(2026, 7, 8), events: [event]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsOneWidget);
    // TypeLabel renders the name; at least one coloured dot is present (panel + month grid).
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.byType(TypeDot), findsWidgets);
  });

  testWidgets('an all-day event shows in the timeline all-day band', (
    tester,
  ) async {
    // Event on the 9th while focused on the 8th → not in the Month panel (selected
    // day 8), but the 3-day span (8–10) shows it in the band.
    final event = Event(
      id: 'e2',
      title: 'Q3 kickoff',
      date: DateTime(2026, 7, 9),
      allDay: true,
    );
    await tester.pumpWidget(
      _calendar(initialDate: DateTime(2026, 7, 8), events: [event]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('3-day'));
    await tester.pumpAndSettle();

    expect(find.text('Q3 kickoff'), findsOneWidget);
  });

  testWidgets('the FAB opens the new-event form', (tester) async {
    await tester.pumpWidget(_calendar(initialDate: DateTime(2026, 7, 8)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'New event'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
  });

  testWidgets('shows the error state when the initial load fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CalendarScreen(
          initialDate: DateTime(2026, 7, 8),
          eventsRepository: _FailingEventsRepo(),
          contactsRepository: _FakeContactsRepo(),
          eventTypesRepository: _FakeEventTypesRepo(),
          commentsRepository: _FakeCommentsRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load events"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('navigates from Contacts to Calendar via the shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ContactsApp(
        repository: _FakeContactsRepo(),
        eventsRepository: _FakeEventsRepo(),
        eventTypesRepository: _FakeEventTypesRepo(),
        commentsRepository: _FakeCommentsRepo(),
        taskCommentsRepository: _FakeCommentsRepo(),
        tasksRepository: _FakeTasksRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Month'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Contacts'), findsNothing);
  });
}
