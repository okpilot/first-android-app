import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';

// The chip theme is asserted through a REAL rendered InputChip, never by reading
// `AppTheme.light.chipTheme` back — that would only restate theme.dart to itself and would
// still pass after the regression below.
//
// The regression these guard is specific and counter-intuitive: `side: BorderSide.none` in
// theme.dart's ChipThemeData reads as redundant (StadiumBorder's OWN default side is already
// none), so it is exactly the line a future "cleanup" deletes. But deleting it doesn't leave
// the default — it makes `Chip._getShape` fall through to
// `resolvedShape.copyWith(side: chipDefaults.side)` and the M3 outlineVariant hairline comes
// back, un-doing the flat look. Only the RESOLVED shape shows that, so these assert the
// ShapeDecoration that Chip actually paints (theme + Chip defaults, already merged).

ShapeDecoration _chipDecoration(WidgetTester tester) =>
    tester
            .widget<Ink>(
              find.descendant(
                of: find.byType(InputChip),
                matching: find.byType(Ink),
              ),
            )
            .decoration!
        as ShapeDecoration;

Future<void> _pumpChip(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: InputChip(label: const Text('Ada'), onDeleted: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('chipTheme', () {
    testWidgets('light: a chip paints as a flat filled pill with no outline', (
      tester,
    ) async {
      await _pumpChip(tester, AppTheme.light);
      final deco = _chipDecoration(tester);

      // A true pill (not M3's 8px-radius rounded rect) — matches the task rows' _CategoryChip.
      expect(deco.shape, isA<StadiumBorder>());
      // The load-bearing line: no hairline may survive the Chip default merge.
      expect((deco.shape as StadiumBorder).side, BorderSide.none);
      // The neutral chip fill (Decision 13 — nothing ships with M3's tonal default).
      expect(deco.color, AppTheme.light.colorScheme.secondaryContainer);
    });

    testWidgets('dark: a chip paints as a flat filled pill with no outline', (
      tester,
    ) async {
      await _pumpChip(tester, AppTheme.dark);
      final deco = _chipDecoration(tester);

      expect(deco.shape, isA<StadiumBorder>());
      expect((deco.shape as StadiumBorder).side, BorderSide.none);
      expect(deco.color, AppTheme.dark.colorScheme.secondaryContainer);
    });
  });
}
