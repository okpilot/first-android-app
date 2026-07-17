import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';
import 'package:first_android_app/util/calendar.dart';
import 'package:first_android_app/widgets/meta_line.dart';

// MetaLine takes plain DateTimes — no repository, so no fakes and no screen host.
//
// It looks like a presenter atom but isn't: it owns two real branches (which of the two
// parts render, and the render-nothing case), and it is the app's only RENDERED
// [displayDate] site. `calendar_test.dart` proves displayDate's string in isolation;
// these prove the widget actually calls it — the pairing that catches a regression to
// `ymd()`'s wire format ("1974-04-13") leaking back onto a user-facing surface, which is
// the exact leak Decision 47 closed.

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders both dates in the display format, created first', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MetaLine(created: DateTime(1974, 4, 13), updated: DateTime(2026, 7, 9)),
      ),
    );

    // Day-month-year with a short month name, joined by a spaced middot. NOT ymd()'s
    // "1974-04-13", and not a zero-padded or month-first order.
    expect(
      find.text('Added 13 Apr 1974  ·  Updated 9 Jul 2026'),
      findsOneWidget,
    );
  });

  testWidgets('a record that was never updated shows only the added date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MetaLine(created: DateTime(1974, 4, 13), updated: null)),
    );

    expect(find.text('Added 13 Apr 1974'), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
  });

  testWidgets('an updated date alone renders without an empty Added part', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MetaLine(created: null, updated: DateTime(2026, 7, 9))),
    );

    expect(find.text('Updated 9 Jul 2026'), findsOneWidget);
    expect(find.textContaining('Added'), findsNothing);
  });

  testWidgets('a UTC timestamptz renders on the LOCAL day, not the raw UTC day', (
    tester,
  ) async {
    // created_at/updated_at come from timestamptz columns → parsed UTC. An instant late in
    // the UTC day lands on a *different local day* east of UTC — so a date-only render must
    // convert first (this widget's whole bug class; cloud-CR caught it). Adversarial input
    // per docs/design-principles: near-midnight UTC, not a convenient local noon.
    final utc = DateTime.utc(2026, 7, 9, 23, 30);
    await tester.pumpWidget(_wrap(MetaLine(created: utc, updated: null)));

    // Asserts the contract (renders the local day); on a non-UTC host it also discriminates
    // the raw-UTC regression, since displayDate(utc) and displayDate(utc.toLocal()) diverge.
    expect(find.text('Added ${displayDate(utc.toLocal())}'), findsOneWidget);
  });

  testWidgets('renders nothing at all when both dates are null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const MetaLine(created: null, updated: null)),
    );

    // Not a bare separator, not an empty Text taking up vertical space.
    expect(find.byType(Text), findsNothing);
  });
}
