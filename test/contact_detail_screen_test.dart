import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/contact_detail_screen.dart';
import 'package:first_android_app/screens/contact_form_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/pane_header.dart';

import 'support/fakes.dart';

// Edit was untested on the contact side before Decision 49 moved it top-right. These lock
// both layouts: the phone AppBar action and the desktop pane's own header strip, each
// opening the form. The affordance is the shared SubtleButton (a FilledButton labelled
// 'Edit'); the comment editor's 'Edit' is a TextButton, so widgetWithText(FilledButton,…)
// won't collide.

const _nadia = Contact(id: 'c1', name: 'Nadia', company: 'Acme');

/// A contacts repo whose softDelete never resolves — pins the view in its _deleting state so a
/// test can prove Edit no-ops mid-delete. The phone AppBar action is NOT disabled by the body's
/// state (it sits above it), so the only guard on that path is edit()'s `if (_deleting) return`.
class _HangingDeleteRepo implements ContactsRepository {
  final _never = Completer<void>();

  @override
  Future<List<Contact>> fetchAll() async => const [];
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) => _never.future;
}

void main() {
  testWidgets('phone: Edit is a top-right AppBar action, no in-pane strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContactDetailScreen(
          repository: FakeContactsRepo(),
          contact: _nadia,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Edit lives in the real AppBar → no in-pane header strip on the phone.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(FilledButton, 'Edit'),
      ),
      findsOneWidget,
    );
    expect(find.byType(PaneHeader), findsNothing);
  });

  testWidgets('phone: tapping the AppBar Edit opens the contact form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContactDetailScreen(
          repository: FakeContactsRepo(),
          contact: _nadia,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactFormScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Edit contact'), findsOneWidget);
  });

  testWidgets('desktop pane: Edit lives in the header strip and opens the form', (
    tester,
  ) async {
    // The wide master-detail pane embeds ContactDetailView with showPaneHeader: true and no
    // AppBar of its own — so Edit must read from the strip.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ContactDetailView(
            repository: FakeContactsRepo(),
            contact: _nadia,
            showPaneHeader: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaneHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PaneHeader),
        matching: find.widgetWithText(FilledButton, 'Edit'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactFormScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Edit contact'), findsOneWidget);
  });

  testWidgets('the AppBar Edit no-ops while a delete is in flight', (
    tester,
  ) async {
    // The phone AppBar Edit stays tappable during a delete (it's above the body's disabled
    // state), so edit()'s own `if (_deleting) return` is the guard. With softDelete hung, tap
    // Edit and prove no form is pushed. Uses pump() not pumpAndSettle() — the delete spinner
    // animates forever, so settle would time out.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContactDetailScreen(
          repository: _HangingDeleteRepo(),
          contact: _nadia,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Start a delete: tap the body button, confirm in the dialog.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(); // dialog closes, _deleting = true, softDelete() hangs

    // Now tap the still-present AppBar Edit — it must be swallowed by the busy guard.
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pump();

    expect(find.byType(ContactFormScreen), findsNothing);
  });
}
