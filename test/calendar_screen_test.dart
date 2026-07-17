import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/screens/calendar_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/type_label.dart';

import 'support/fakes.dart';

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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Widget _calendar({
  DateTime? initialDate,
  List<Event> events = const [],
  List<Contact> contacts = const [],
}) => _wrap(
  CalendarScreen(
    initialDate: initialDate,
    eventsRepository: FakeEventsRepo(events),
    contactsRepository: FakeContactsRepo(contacts),
    eventTypesRepository: FakeEventTypesRepo(),
    commentsRepository: FakeCommentsRepo(),
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
    expect(find.text('PEOPLE · 1'), findsOneWidget);
    expect(find.text('No type'), findsOneWidget);
  });

  testWidgets('an event with nobody invited shows the People empty state', (
    tester,
  ) async {
    final event = Event(
      id: 'e4',
      title: 'Solo focus block',
      date: DateTime(2026, 7, 8),
      allDay: true,
    );
    await tester.pumpWidget(
      _calendar(initialDate: DateTime(2026, 7, 8), events: [event]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Solo focus block'));
    await tester.pumpAndSettle();

    // The roster's empty branch. "people" is the one user-facing noun (Decision 47) — the
    // domain's `attendees` survives only in Event.attendees and the event_attendees table.
    expect(find.text('PEOPLE · 0'), findsOneWidget);
    expect(find.text('No people'), findsOneWidget);
    expect(find.textContaining('attendee'), findsNothing);
  });

  testWidgets('a timed event tells a screen reader who is coming', (
    tester,
  ) async {
    // Disposed explicitly at the end, not via addTearDown — the framework verifies no
    // SemanticsHandle is live BEFORE tear-downs run, so a tear-down dispose fails the test.
    final handle = tester.ensureSemantics();
    final solo = Event(
      id: 'e5',
      title: 'Standup',
      date: DateTime(2026, 7, 9),
      allDay: false,
      startMin: 9 * 60,
      endMin: 9 * 60 + 15,
      attendees: const [Contact(id: 'c1', name: 'Ada Lovelace')],
    );
    final crowd = Event(
      id: 'e6',
      title: 'Retro',
      date: DateTime(2026, 7, 9),
      allDay: false,
      startMin: 14 * 60,
      endMin: 14 * 60 + 30,
      attendees: const [
        Contact(id: 'c1', name: 'Ada Lovelace'),
        Contact(id: 'c2', name: 'Bo Zhang'),
      ],
    );
    await tester.pumpWidget(
      _calendar(initialDate: DateTime(2026, 7, 8), events: [solo, crowd]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('3-day'));
    await tester.pumpAndSettle();

    // RegExp, not an exact string: the block's Semantics carries an explicit `label` AND
    // merges its children's, so the node's full label has the child Texts newline-appended
    // after this prefix. The prefix is the part the screen reader leads with.
    //
    // A screen reader must hear the noun a sighted user reads — "person"/"people", never the
    // domain's "attendee" (Decision 47) — and the count switches on 1 vs many. The type is
    // spoken because the block carries it as a tint only (colour is never the sole signal).
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Standup, No type, 09:00 – 09:15, 1 person'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Retro, No type, 14:00 – 14:30, 2 people'),
      ),
      findsOneWidget,
    );
    handle.dispose();
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
          contactsRepository: FakeContactsRepo(),
          eventTypesRepository: FakeEventTypesRepo(),
          commentsRepository: FakeCommentsRepo(),
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
        repository: FakeContactsRepo(),
        eventsRepository: FakeEventsRepo(),
        eventTypesRepository: FakeEventTypesRepo(),
        commentsRepository: FakeCommentsRepo(),
        taskCommentsRepository: FakeCommentsRepo(),
        tasksRepository: FakeTasksRepo(),
        taskCategoriesRepository: FakeTaskCategoriesRepo(),
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
