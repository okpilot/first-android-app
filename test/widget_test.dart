import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/app.dart';
import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/event_types_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';

/// In-memory repository so widget tests never touch the network/Supabase.
class _FakeRepo implements ContactsRepository {
  _FakeRepo(this.contacts);
  final List<Contact> contacts;

  @override
  Future<List<Contact>> fetchAll() async => contacts;
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeEventsRepo implements EventsRepository {
  @override
  Future<List<Event>> fetchAll() async => const [];
  @override
  Future<Event> create(Event draft) async => draft;
  @override
  Future<Event> update(Event event) async => event;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeEventTypesRepo implements EventTypesRepository {
  @override
  Future<List<EventType>> fetchAll() async => const [];
  @override
  Future<EventType> create(EventType draft) async => draft;
  @override
  Future<EventType> update(EventType type) async => type;
  @override
  Future<void> softDelete(String id) async {}
}

class _FakeCommentsRepo implements CommentsRepository {
  @override
  Future<List<Comment>> fetchForEvent(String eventId) async => const [];
  @override
  Future<Comment> add(Comment draft) async => draft;
  @override
  Future<Comment> edit(Comment comment) async => comment;
  @override
  Future<Comment> archive(String id) async =>
      Comment.draft(eventId: '', body: '');
  @override
  Future<Comment> unarchive(String id) async =>
      Comment.draft(eventId: '', body: '');
}

void main() {
  testWidgets('renders contacts from the repository', (tester) async {
    await tester.pumpWidget(
      ContactsApp(
        repository: _FakeRepo(const [
          Contact(
            id: '1',
            name: 'Ada Lovelace',
            company: 'Analytical Engine Co.',
          ),
          Contact(id: '2', name: 'Alan Turing'),
        ]),
        eventsRepository: _FakeEventsRepo(),
        eventTypesRepository: _FakeEventTypesRepo(),
        commentsRepository: _FakeCommentsRepo(),
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
        repository: _FakeRepo(const []),
        eventsRepository: _FakeEventsRepo(),
        eventTypesRepository: _FakeEventTypesRepo(),
        commentsRepository: _FakeCommentsRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No contacts yet'), findsOneWidget);
    expect(find.text('New contact'), findsWidgets); // FAB + empty-state CTA
  });
}
