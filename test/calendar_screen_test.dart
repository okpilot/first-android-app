import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/screens/calendar_screen.dart';
import 'package:first_android_app/theme.dart';

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
    eventsRepository: _FakeEventsRepo(events),
    contactsRepository: _FakeContactsRepo(contacts),
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

    // Now on the detail screen.
    expect(find.text('Delete event'), findsOneWidget);
    expect(find.text('ATTENDEES · 1'), findsOneWidget);
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
