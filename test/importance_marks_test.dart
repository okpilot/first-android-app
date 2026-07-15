import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/importance_marks.dart';

/// Standalone tests for the shared [ImportanceMarks] primitive (Decision 38). It's mounted only
/// through its hosts (the task list rows + the detail), so the list/detail tests exercise it
/// indirectly — but its own branches (nothing at level 0, the a11y label that keeps colour from
/// riding alone, and the `muted` dimming for done/archived rows) deserve a direct mount.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets(
    'renders nothing at level 0 (callers can drop it in unconditionally)',
    (tester) async {
      await tester.pumpWidget(_wrap(const ImportanceMarks(level: 0)));
      await tester.pumpAndSettle();

      // No glyphs and no a11y label — an empty SizedBox, nothing for the eye or screen reader.
      expect(find.text('!'), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Importance')), findsNothing);
    },
  );

  testWidgets('renders the marks AND a screen-reader label for each level', (
    tester,
  ) async {
    // The '!' glyph carries the signal; the Semantics label spells the level out so colour never
    // rides alone (design-principles a11y).
    for (final (level, marks, name) in const [
      (1, '!', 'Low'),
      (2, '!!', 'Medium'),
      (3, '!!!', 'High'),
    ]) {
      await tester.pumpWidget(_wrap(ImportanceMarks(level: level)));
      await tester.pumpAndSettle();

      expect(find.text(marks), findsOneWidget);
      // The Semantics label merges with the child glyphs, so match on the level name substring.
      expect(find.bySemanticsLabel(RegExp('Importance $name')), findsOneWidget);
    }
  });

  testWidgets('muted dims the marker to half strength (done / archived rows)', (
    tester,
  ) async {
    // The list mutes the marker on a done/archived row (`muted: isDone || isArchived`) so active
    // urgent tasks stay the loudest thing. Assert the muted glyph is the same hue at half alpha.
    await tester.pumpWidget(
      _wrap(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImportanceMarks(level: 3, key: ValueKey('loud')),
            ImportanceMarks(level: 3, muted: true, key: ValueKey('dim')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final loud = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('loud')),
            matching: find.byType(Text),
          ),
        )
        .style!
        .color!;
    final dim = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('dim')),
            matching: find.byType(Text),
          ),
        )
        .style!
        .color!;

    // Same hue, halved opacity: active is full strength, muted is ~0.5 alpha.
    expect(loud.a, closeTo(1.0, 0.001));
    expect(dim.a, closeTo(0.5, 0.01));
    expect(
      dim.r,
      closeTo(loud.r, 0.001),
    ); // same red channel → same hue, only alpha changed
    expect(dim.g, closeTo(loud.g, 0.001));
    expect(dim.b, closeTo(loud.b, 0.001));
  });
}
