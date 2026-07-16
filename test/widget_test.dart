import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/models/contact.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('renders contacts from the repository', (tester) async {
    await tester.pumpWidget(
      ContactsApp(
        repository: FakeContactsRepo(const [
          Contact(
            id: '1',
            name: 'Ada Lovelace',
            company: 'Analytical Engine Co.',
          ),
          Contact(id: '2', name: 'Alan Turing'),
        ]),
        eventsRepository: FakeEventsRepo(),
        eventTypesRepository: FakeEventTypesRepo(),
        commentsRepository: FakeCommentsRepo(),
        taskCommentsRepository: FakeCommentsRepo(),
        tasksRepository: FakeTasksRepo(),
        taskCategoriesRepository: FakeTaskCategoriesRepo(),
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
    await tester.pumpWidget(
      ContactsApp(
        repository: FakeContactsRepo(const []),
        eventsRepository: FakeEventsRepo(),
        eventTypesRepository: FakeEventTypesRepo(),
        commentsRepository: FakeCommentsRepo(),
        taskCommentsRepository: FakeCommentsRepo(),
        tasksRepository: FakeTasksRepo(),
        taskCategoriesRepository: FakeTaskCategoriesRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No contacts yet'), findsOneWidget);
    expect(find.text('New contact'), findsWidgets); // FAB + empty-state CTA
  });
}
