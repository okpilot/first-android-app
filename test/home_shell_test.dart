import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/screens/home_shell.dart';

import 'support/fakes.dart';

Widget _shell() => MaterialApp(
  home: HomeShell(
    // One contact so the Contacts screen shows its list (not the empty state,
    // whose button would duplicate the FAB's "New contact" text).
    repository: FakeContactsRepo(const [
      Contact(id: '1', name: 'Ada Lovelace'),
    ]),
    eventsRepository: FakeEventsRepo(),
    eventTypesRepository: FakeEventTypesRepo(),
    commentsRepository: FakeCommentsRepo(),
    taskCommentsRepository: FakeCommentsRepo(),
    tasksRepository: FakeTasksRepo(),
    taskCategoriesRepository: FakeTaskCategoriesRepo(),
  ),
);

void main() {
  testWidgets('wide screen shows the labelled sidebar and switches destination', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // Sidebar present (brand only exists in the sidebar); bottom bar absent.
    expect(find.text('CRM+'), findsOneWidget);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Contacts is the initial destination — the seeded contact shows in the wide
    // master-detail (list row + detail pane). (On wide there's no "New contact" FAB;
    // that's the header "New" button now — Decision 28 Slice C.)
    expect(find.text('Ada Lovelace'), findsWidgets);

    // Tapping the sidebar's Tasks item switches the visible screen. Target the sidebar
    // row (an InkWell) directly so the tap doesn't depend on the identically-titled
    // TasksListScreen AppBar being offstage.
    await tester.tap(find.widgetWithText(InkWell, 'Tasks'));
    await tester.pumpAndSettle();

    // The Tasks destination is actually the visible one, not merely "something other than
    // Contacts". On this wide surface Tasks has no AppBar (Decision 28 Slice D), so assert the
    // Tasks empty state instead — layout-agnostic, and the fake Tasks repo returns no tasks.
    expect(find.text('No tasks yet'), findsOneWidget);
    // …and the Contacts screen is no longer visible.
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('wide screen: the bottom-pinned Settings item selects the '
      'Settings destination', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // Settings is rendered by a separate code path from the looped items (after a
    // Spacer, wired to `lastIndex`), so its index math needs its own coverage.
    // Before selection the Settings screen is offstage, so its "Event types" row
    // is absent and "Settings" unambiguously names the sidebar item.
    expect(find.text('Event types'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'Settings'));
    await tester.pumpAndSettle();

    // The Settings screen is now the visible destination.
    expect(find.text('Event types'), findsOneWidget);
  });

  testWidgets('narrow screen shows the bottom NavigationBar, not the sidebar', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('CRM+'), findsNothing);
  });
}
