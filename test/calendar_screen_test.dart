import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/calendar_screen.dart';
import 'package:first_android_app/theme.dart';

class _FakeRepo implements ContactsRepository {
  @override
  Future<List<Contact>> fetchAll() async => const [];
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('shows all four view tabs', (tester) async {
    await tester.pumpWidget(
      _wrap(CalendarScreen(initialDate: DateTime(2026, 7, 8))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('3-day'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget); // period label
  });

  testWidgets('tapping a month day updates the selected-day panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(CalendarScreen(initialDate: DateTime(2026, 7, 8))),
    );
    await tester.pumpAndSettle();

    // Jul 15 is unique in the July 2026 grid (Jun 29 … Aug 9).
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.textContaining('15 JUL'), findsOneWidget);
    expect(find.text('No events'), findsOneWidget);
  });

  testWidgets('each view renders its empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(CalendarScreen(initialDate: DateTime(2026, 7, 8))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('No events yet'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing scheduled'), findsOneWidget);
  });

  testWidgets('navigates from Contacts to Calendar via the shell', (
    tester,
  ) async {
    await tester.pumpWidget(ContactsApp(repository: _FakeRepo()));
    await tester.pumpAndSettle();

    // Starts on Contacts.
    expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);

    // Tap the Calendar destination (nav label).
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Calendar is now the visible destination.
    expect(find.text('Month'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Contacts'), findsNothing);
  });
}
