import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/main.dart';

void main() {
  testWidgets('Contacts screen renders the list', (tester) async {
    await tester.pumpWidget(const ContactsApp());

    // AppBar title (MaterialApp.title does not render a Text node).
    expect(find.text('Contacts'), findsOneWidget);

    // At least one contact card is shown.
    expect(find.byType(Card), findsWidgets);

    // A known sample contact is visible.
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}
