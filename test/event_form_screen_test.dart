import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/screens/event_form_screen.dart';
import 'package:first_android_app/theme.dart';

import 'support/fakes.dart';

Widget _form({
  FakeEventsRepo? events,
  List<EventType> types = const [],
  Event? existing,
}) => MaterialApp(
  theme: AppTheme.light,
  home: EventFormScreen(
    eventsRepository: events ?? FakeEventsRepo(),
    contactsRepository: FakeContactsRepo(),
    eventTypesRepository: FakeEventTypesRepo(types),
    existing: existing,
  ),
);

/// Pin a TALL surface before pumping. Decision 47 removed the AppBar's `Save` (one save per form),
/// so these tests now drive the submit button at the BOTTOM of the form's ListView — which the
/// default 800×600 viewport never even builds (it sits past the lazy list's cache extent, so the
/// finder returns nothing at all, not merely an un-hittable widget). Mirrors the same helper in
/// `task_form_screen_test.dart`, added when that form outgrew the viewport (Decision 40).
Future<void> _pump(WidgetTester tester, Widget app) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title is required', (tester) async {
    await _pump(tester, _form());

    await tester.tap(find.widgetWithText(FilledButton, 'Add event'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('a People chip renders its avatar initials at the chip size', (
    tester,
  ) async {
    await _pump(
      tester,
      _form(
        existing: Event(
          id: 'e1',
          title: 'Q3 kickoff',
          date: DateTime(2026, 7, 9),
          allDay: true,
          attendees: const [Contact(id: 'c1', name: 'Ada Lovelace')],
        ),
      ),
    );

    final initials = find.descendant(
      of: find.widgetWithText(InputChip, 'Ada Lovelace'),
      matching: find.text('AL'),
    );
    await tester.ensureVisible(initials);

    // `radius: 11` → fontSize 7.7. This asserts the SITE, not the widget contract
    // (initials_avatar_test owns that): a Chip pins the avatar's BOX via
    // tightFor(contentSize), so deleting `radius: 11` here leaves the disc byte-identical
    // and only the initials jump 7.7 → 14 — no analyzer complaint, no layout error.
    expect(
      tester.widget<Text>(initials).style?.fontSize,
      moreOrLessEquals(7.7, epsilon: 0.01),
    );
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
    await _pump(tester, _form(events: events));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      '  Coffee with Sam  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add event'));
    await tester.pumpAndSettle();

    expect(events.lastCreated?.title, 'Coffee with Sam');
  });

  testWidgets('type defaults to No type and a picked type reaches the draft', (
    tester,
  ) async {
    final events = FakeEventsRepo();
    const type = EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9');
    await _pump(tester, _form(events: events, types: const [type]));

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
    await tester.tap(find.widgetWithText(FilledButton, 'Add event'));
    await tester.pumpAndSettle();

    expect(events.lastCreated?.type?.id, 't1');
  });
}
