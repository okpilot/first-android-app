import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/contact_picker_screen.dart';
import 'package:first_android_app/theme.dart';

/// A minimal fake contacts repo — the picker only reads the roster via fetchAll; writes unused.
class _FakeContactsRepo implements ContactsRepository {
  _FakeContactsRepo([this._all = const []]);
  final List<Contact> _all;

  @override
  Future<List<Contact>> fetchAll() async => _all;
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

/// fetchAll throws — drives the picker's "Couldn't load contacts" error state.
class _FailingContactsRepo implements ContactsRepository {
  @override
  Future<List<Contact>> fetchAll() async => throw Exception('offline');
  @override
  Future<Contact> create(Contact draft) => throw UnimplementedError();
  @override
  Future<Contact> update(Contact contact) => throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

const _roster = [
  Contact(id: 'c1', name: 'Nadia', company: 'Acme'),
  Contact(id: 'c2', name: 'Bo'),
];

Widget _picker({
  required String title,
  List<Contact> initialSelected = const [],
  ContactsRepository? repo,
}) => MaterialApp(
  theme: AppTheme.light,
  home: ContactPickerScreen(
    repository: repo ?? _FakeContactsRepo(_roster),
    initialSelected: initialSelected,
    title: title,
  ),
);

void main() {
  testWidgets('empty selection shows the "Add <noun>" AppBar for its role', (
    tester,
  ) async {
    await tester.pumpWidget(_picker(title: 'people'));
    await tester.pumpAndSettle();

    // n == 0 branch: the lowercase role noun, no count.
    expect(find.widgetWithText(AppBar, 'Add people'), findsOneWidget);
  });

  testWidgets(
    'a pre-selected roster shows the Capitalized noun with a live count',
    (tester) async {
      await tester.pumpWidget(
        _picker(
          title: 'attendees',
          initialSelected: const [Contact(id: 'c1', name: 'Nadia')],
        ),
      );
      await tester.pumpAndSettle();

      // n > 0 branch: the noun is capitalized and the count is appended.
      expect(find.widgetWithText(AppBar, 'Attendees · 1'), findsOneWidget);

      // Selecting the second contact updates the count live (1 → 2).
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Attendees · 2'), findsOneWidget);

      // Un-selecting the seeded contact drops back through the count to the "Add" copy.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Nadia'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Attendees · 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add attendees'), findsOneWidget);
    },
  );

  testWidgets('a pre-selected contact renders as a checked box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        title: 'people',
        initialSelected: const [Contact(id: 'c1', name: 'Nadia')],
      ),
    );
    await tester.pumpAndSettle();

    final nadia = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Nadia'),
    );
    final bo = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Bo'),
    );
    expect(nadia.value, isTrue);
    expect(bo.value, isFalse);
  });

  testWidgets('Done pops the committed selection to the caller', (
    tester,
  ) async {
    List<Contact>? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<List<Contact>>(
                    MaterialPageRoute(
                      builder: (_) => ContactPickerScreen(
                        repository: _FakeContactsRepo(_roster),
                        initialSelected: const [],
                        title: 'people',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    // The back arrow and Done both commit the current selection (a system-back cancels).
    expect(popped, isNotNull);
    expect(popped!.map((c) => c.id), ['c2']);
  });

  testWidgets(
    'an empty roster shows the role-aware "link them as <noun>" empty state',
    (tester) async {
      // Attendees (event path) and people (task path) each get their own noun.
      await tester.pumpWidget(
        _picker(title: 'attendees', repo: _FakeContactsRepo()),
      );
      await tester.pumpAndSettle();
      expect(find.text('No contacts yet'), findsOneWidget);
      expect(
        find.text('Add contacts first, then link them as attendees.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _picker(title: 'people', repo: _FakeContactsRepo()),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Add contacts first, then link them as people.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed roster load shows the contacts error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _picker(title: 'people', repo: _FailingContactsRepo()),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load contacts"), findsOneWidget);
  });
}
