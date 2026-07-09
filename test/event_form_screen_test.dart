import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/screens/event_form_screen.dart';
import 'package:first_android_app/theme.dart';

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

Widget _form() => MaterialApp(
  theme: AppTheme.light,
  home: EventFormScreen(
    eventsRepository: _FakeEventsRepo(),
    contactsRepository: _FakeContactsRepo(),
  ),
);

void main() {
  testWidgets('title is required', (tester) async {
    await tester.pumpWidget(_form());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('the all-day toggle hides the time fields', (tester) async {
    await tester.pumpWidget(_form());
    await tester.pumpAndSettle();

    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Ends'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Starts'), findsNothing);
    expect(find.text('Ends'), findsNothing);
  });
}
