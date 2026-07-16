import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/contact_detail_screen.dart';
import 'package:first_android_app/screens/contacts_list_screen.dart';

import 'support/fakes.dart';

final _people = [
  const Contact(
    id: '1',
    name: 'Ada Lovelace',
    company: 'Analytical Engine Co.',
  ),
  const Contact(
    id: '2',
    name: 'Alan Turing',
    email: 'alan@bletchley.uk',
    remarks: 'Bombe.',
  ),
];

Widget _app(List<Contact> people) =>
    MaterialApp(home: ContactsListScreen(repository: FakeContactsRepo(people)));

void main() {
  testWidgets(
    'wide: selecting a contact updates the pane in place, no route push',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1100, 800));

      await tester.pumpWidget(_app(_people));
      await tester.pumpAndSettle();

      // Two-pane: the embedded body is a ContactDetailView, NOT a pushed
      // ContactDetailScreen. Auto-select-first shows Ada's detail.
      expect(find.byType(ContactDetailView), findsOneWidget);
      expect(find.byType(ContactDetailScreen), findsNothing);

      // Tap the second contact — assert on a detail-only field (Alan's remark), not
      // the name (Ada's name renders in both the list tile and the pane).
      await tester.tap(find.text('Alan Turing'));
      await tester.pumpAndSettle();

      expect(find.byType(ContactDetailScreen), findsNothing); // still no push
      expect(find.text('Bombe.'), findsOneWidget); // Alan's pane is shown
    },
  );

  testWidgets('wide: auto-selects the first contact on load', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    // Selection defaults to contacts.first (Ada), not another row. Alan's
    // detail-only remark ("Bombe.") would only render if HE were the auto-
    // selected pane — its absence pins the choice to the first contact.
    expect(find.byType(ContactDetailView), findsOneWidget);
    expect(find.text('Bombe.'), findsNothing);
  });

  testWidgets('wide: an empty field shows "Not added"', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    // Ada (auto-selected) has no email/phone/dob/remarks → muted placeholders.
    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    expect(find.text('Not added'), findsWidgets);
  });

  testWidgets('narrow: tapping a contact pushes the full detail screen', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    // Single pane: no embedded detail until a tap.
    expect(find.byType(ContactDetailView), findsNothing);

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    // The push flow is preserved — a full ContactDetailScreen route.
    expect(find.byType(ContactDetailScreen), findsOneWidget);
  });

  testWidgets('wide: the list header replaces the AppBar + FAB', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    // No phone chrome on wide.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    // The list pane owns the header: a search field + an inline "New" button.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New'), findsOneWidget);
  });

  testWidgets('wide: search filters the list rows, not the detail', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    // Alan's email renders only in his list-row subtitle (he isn't the selection).
    expect(find.text('alan@bletchley.uk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pumpAndSettle();

    // Alan's row is filtered out; Ada (auto-selected) stays in list + detail.
    expect(find.text('alan@bletchley.uk'), findsNothing);
    expect(find.text('Ada Lovelace'), findsWidgets);
  });

  testWidgets('wide: the ✕ clear button restores the full list', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    // Filter down to Ada — Alan's row (and his email) drop out.
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pumpAndSettle();
    expect(find.text('alan@bletchley.uk'), findsNothing);

    // The ✕ suffix (tooltip 'Clear') runs onClear → clears the box → full list back.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(
      find.text('alan@bletchley.uk'),
      findsOneWidget,
    ); // Alan's row restored
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'wide: a query matching nothing shows "No matches" but the detail keeps '
    'its selection',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1100, 800));

      await tester.pumpWidget(_app(_people));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nobodyhere');
      await tester.pumpAndSettle();

      // The master pane shows the _NoMatches state (distinct from zero-contacts).
      expect(find.text('No matches'), findsOneWidget);
      // The detail pane still holds its selection (Ada, auto-selected). With the
      // list filtered empty, her name renders only in the pane.
      expect(find.byType(ContactDetailView), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    },
  );

  testWidgets('narrow: keeps the AppBar + FAB and has no search', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));

    await tester.pumpWidget(_app(_people));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
