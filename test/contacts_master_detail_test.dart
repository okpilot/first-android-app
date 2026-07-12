import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/contact_detail_screen.dart';
import 'package:first_android_app/screens/contacts_list_screen.dart';

/// In-memory fake — hand-written private-fake convention (no mockito).
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
    MaterialApp(home: ContactsListScreen(repository: _FakeRepo(people)));

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
}
