import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/detail_field.dart';

/// Standalone tests for the shared [DetailField] primitive (extracted from `ContactDetailScreen`
/// and `EventDetailScreen`). It's mounted only through those two hosts, so the detail-screen tests
/// exercise it indirectly — but only the "Not added" branch is asserted transitively today, and the
/// selectable branch plus the value-XOR-child assert have no coverage at all. Its four render
/// branches (child slot, empty placeholder, selectable, plain) and its mutual-exclusion guard each
/// deserve a direct mount.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('always renders the label (icon + label header)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DetailField(
          icon: Icons.email_outlined,
          label: 'Email',
          value: 'a@b.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
  });

  testWidgets('a null value renders the muted "Not added" placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DetailField(icon: Icons.cake_outlined, label: 'Date of birth'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not added'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('an empty-string value also renders "Not added"', (tester) async {
    // The empty check is `value == null || value!.isEmpty` — a blank string is a missing value too.
    await tester.pumpWidget(
      _wrap(
        const DetailField(
          icon: Icons.business_outlined,
          label: 'Company',
          value: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not added'), findsOneWidget);
  });

  testWidgets('a plain value renders as Text, not SelectableText', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DetailField(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: '+123456',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+123456'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Not added'), findsNothing);
  });

  testWidgets('selectable wraps the value in a SelectableText (copyable link)', (
    tester,
  ) async {
    // Used for link-like locations the user can select + copy (event_detail `_locationIsLink`).
    await tester.pumpWidget(
      _wrap(
        const DetailField(
          icon: Icons.link_outlined,
          label: 'Location',
          value: 'https://example.com',
          selectable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectable = find.byType(SelectableText);
    expect(selectable, findsOneWidget);
    expect(
      tester.widget<SelectableText>(selectable).data,
      'https://example.com',
    );
  });

  testWidgets('a child is rendered in place of the value text', (tester) async {
    // The custom-widget slot (e.g. a type dot + name on the event detail); no "Not added" even
    // though value is null, because the child branch wins.
    await tester.pumpWidget(
      _wrap(
        const DetailField(
          icon: Icons.category_outlined,
          label: 'Type',
          child: Text('custom-value-widget'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('custom-value-widget'), findsOneWidget);
    expect(find.text('Not added'), findsNothing);
  });

  test('passing both value and child trips the mutual-exclusion assert', () {
    // The doc-comment promises "either value or child, never both" — the assert enforces it.
    expect(
      () => DetailField(
        icon: Icons.category_outlined,
        label: 'Type',
        value: 'x',
        child: const Text('y'),
      ),
      throwsAssertionError,
    );
  });
}
