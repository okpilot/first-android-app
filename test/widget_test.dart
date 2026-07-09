import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/models/contact.dart';

/// In-memory repository so widget tests never touch the network/Supabase.
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

void main() {
  testWidgets('renders contacts from the repository', (tester) async {
    await tester.pumpWidget(
      ContactsApp(
        repository: _FakeRepo(const [
          Contact(
            id: '1',
            name: 'Ada Lovelace',
            company: 'Analytical Engine Co.',
          ),
          Contact(id: '2', name: 'Alan Turing'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // "Contacts" now appears twice (AppBar title + nav destination label), so
    // scope the finder to the AppBar title.
    expect(find.widgetWithText(AppBar, 'Contacts'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Alan Turing'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no contacts', (
    tester,
  ) async {
    await tester.pumpWidget(ContactsApp(repository: _FakeRepo(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No contacts yet'), findsOneWidget);
    expect(find.text('New contact'), findsWidgets); // FAB + empty-state CTA
  });
}
