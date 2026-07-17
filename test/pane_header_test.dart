import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/pane_header.dart';

// PaneHeader is the AppBar-less desktop pane's Edit-carrying strip (Decision 49). It's covered
// indirectly through the contact/task detail panes, but its two branch flags — showEdit (drop
// the button) and a null onEdit (disable it, mid-mutation) — deserve a direct standalone mount:
// the disabled state in particular is exercised by no screen test.

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

// The strip's Edit affordance: the shared SubtleButton, which renders a FilledButton labelled
// 'Edit' (Decision 49 kept Edit a chip, not a bare icon).
FilledButton _editButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byType(PaneHeader),
    matching: find.widgetWithText(FilledButton, 'Edit'),
  ),
);

void main() {
  testWidgets('renders the title and, by default, an enabled Edit', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(PaneHeader(title: 'Task', onEdit: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Task'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    // A non-null onEdit → the button is enabled.
    expect(_editButton(tester).onPressed, isNotNull);
  });

  testWidgets('showEdit: false keeps the title but drops the Edit button', (
    tester,
  ) async {
    // The archived-task case: a read-only strip.
    await tester.pumpWidget(
      _wrap(PaneHeader(title: 'Archived task', onEdit: () {}, showEdit: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archived task'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
  });

  testWidgets('a null onEdit disables the Edit button (mid-mutation)', (
    tester,
  ) async {
    // showEdit true but onEdit null: the button is present but greyed out — the busy state
    // the detail panes pass while a write is in flight.
    await tester.pumpWidget(_wrap(const PaneHeader(title: 'Task')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    expect(_editButton(tester).onPressed, isNull);
  });

  testWidgets('the title is set to ellipsize so a long title cannot overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        PaneHeader(
          title: 'A very very very very very long task title that must clip',
          onEdit: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(PaneHeader),
        matching: find.textContaining('A very'),
      ),
    );
    // Both are load-bearing: ellipsis alone still wraps; maxLines:1 forces the single line
    // that the ellipsis then truncates (two lines of titleMedium would fit the strip height).
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    // No overflow error was thrown during layout (the test would have failed otherwise).
  });
}
