import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/screens/event_form_screen.dart';
import 'package:first_android_app/theme.dart';

import 'support/fakes.dart';

Widget _form({FakeEventsRepo? events, List<EventType> types = const []}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: EventFormScreen(
        eventsRepository: events ?? FakeEventsRepo(),
        contactsRepository: FakeContactsRepo(),
        eventTypesRepository: FakeEventTypesRepo(types),
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

  testWidgets('the title is trimmed before save', (tester) async {
    final events = FakeEventsRepo();
    await tester.pumpWidget(_form(events: events));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      '  Coffee with Sam  ',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.lastCreated?.title, 'Coffee with Sam');
  });

  testWidgets('type defaults to No type and a picked type reaches the draft', (
    tester,
  ) async {
    final events = FakeEventsRepo();
    const type = EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9');
    await tester.pumpWidget(_form(events: events, types: const [type]));
    await tester.pumpAndSettle();

    // The Type field starts on "No type".
    expect(find.text('No type'), findsOneWidget);

    // Open the picker and choose the one existing type.
    await tester.tap(find.text('No type'));
    await tester.pumpAndSettle();
    expect(find.text('Manage types…'), findsOneWidget);
    await tester.tap(find.text('Meeting'));
    await tester.pumpAndSettle();

    // The field now shows the type; "No type" is gone.
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('No type'), findsNothing);

    // Saving carries the type through to the draft.
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Sync');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.lastCreated?.type?.id, 't1');
  });
}
