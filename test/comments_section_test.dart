import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/event_types_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/screens/event_detail_screen.dart';
import 'package:first_android_app/theme.dart';

// The Comments section is private to event_detail_screen.dart, so it's exercised through
// its public host, EventDetailScreen. Only the comments repo does anything here; the other
// three are inert fakes.

/// In-memory comments repo: add/edit/archive/unarchive mutate the list and fetch re-reads
/// it (newest first), so the widget round-trips like the real direct-CRUD repository.
class _FakeCommentsRepo implements CommentsRepository {
  _FakeCommentsRepo([List<Comment>? seed]) : _items = seed ?? [];

  final List<Comment> _items;
  int _seq = 0;
  bool throwOnFetch = false;

  @override
  Future<List<Comment>> fetchForEvent(String eventId) async {
    if (throwOnFetch) throw Exception('offline');
    return _items.where((c) => c.eventId == eventId).toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // newest first
  }

  @override
  Future<Comment> add(Comment draft) async {
    final saved = Comment(
      id: 'c${_seq++}',
      eventId: draft.eventId,
      body: draft.body.trim(),
    );
    _items.add(saved);
    return saved;
  }

  @override
  Future<Comment> edit(Comment comment) async {
    final i = _items.indexWhere((c) => c.id == comment.id);
    _items[i] = _items[i].copyWith(body: comment.body);
    return _items[i];
  }

  @override
  Future<Comment> archive(String id) async =>
      _setDeleted(id, DateTime(2026, 7, 11));

  @override
  Future<Comment> unarchive(String id) async => _setDeleted(id, null);

  Comment _setDeleted(String id, DateTime? when) {
    final i = _items.indexWhere((c) => c.id == id);
    final c = _items[i];
    final next = Comment(
      id: c.id,
      eventId: c.eventId,
      body: c.body,
      createdAt: c.createdAt,
      deletedAt: when,
    );
    _items[i] = next;
    return next;
  }
}

class _InertEventsRepo implements EventsRepository {
  @override
  Future<List<Event>> fetchAll() async => const [];
  @override
  Future<Event> create(Event draft) async => draft;
  @override
  Future<Event> update(Event event) async => event;
  @override
  Future<void> softDelete(String id) async {}
}

class _InertContactsRepo implements ContactsRepository {
  @override
  Future<List<Contact>> fetchAll() async => const [];
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

class _InertTypesRepo implements EventTypesRepository {
  @override
  Future<List<EventType>> fetchAll() async => const [];
  @override
  Future<EventType> create(EventType draft) async => draft;
  @override
  Future<EventType> update(EventType type) async => type;
  @override
  Future<void> softDelete(String id) async {}
}

final _event = Event(
  id: 'e1',
  title: 'Design review',
  date: DateTime(2026, 7, 11),
  allDay: true, // all-day → no stray time digits to collide with the count chip
);

Widget _detail(_FakeCommentsRepo comments) => MaterialApp(
  theme: AppTheme.light,
  home: EventDetailScreen(
    eventsRepository: _InertEventsRepo(),
    contactsRepository: _InertContactsRepo(),
    eventTypesRepository: _InertTypesRepo(),
    commentsRepository: comments,
    event: _event,
  ),
);

Comment _live(String id, String body) =>
    Comment(id: id, eventId: 'e1', body: body);

void main() {
  testWidgets('empty state when there are no comments', (tester) async {
    await tester.pumpWidget(_detail(_FakeCommentsRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('No comments yet.'), findsOneWidget);
  });

  testWidgets('lists live comments and hides archived behind the toggle', (
    tester,
  ) async {
    final repo = _FakeCommentsRepo([
      _live('c1', 'Sent the agenda round.'),
      Comment(
        id: 'c0',
        eventId: 'e1',
        body: 'Rescheduled to the afternoon.',
        deletedAt: DateTime(2026, 7, 10),
      ),
    ]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    expect(find.text('Sent the agenda round.'), findsOneWidget);
    // Archived one is hidden until the toggle is opened.
    expect(find.text('Rescheduled to the afternoon.'), findsNothing);
    expect(find.text('Show archived (1)'), findsOneWidget);

    await tester.ensureVisible(find.text('Show archived (1)'));
    await tester.tap(find.text('Show archived (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Rescheduled to the afternoon.'), findsOneWidget);
    expect(find.text('Hide archived (1)'), findsOneWidget);
    expect(find.text('Unarchive'), findsOneWidget);
  });

  testWidgets('adds a comment and clears the composer', (tester) async {
    final repo = _FakeCommentsRepo();
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  New note  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Comment'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget); // trimmed + persisted
    expect(find.text('No comments yet.'), findsNothing);
  });

  testWidgets('edits a comment inline', (tester) async {
    final repo = _FakeCommentsRepo([_live('c1', 'Draft wording')]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Two TextFields now exist (composer + inline editor); the editor is built last.
    await tester.enterText(find.byType(TextField).last, 'Final wording');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Final wording'), findsOneWidget);
    expect(find.text('Draft wording'), findsNothing);
  });

  testWidgets('archive removes from live; unarchive restores it', (
    tester,
  ) async {
    final repo = _FakeCommentsRepo([_live('c1', 'Tentative — confirming.')]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    // Archive → drops out of the live list, count reflects it.
    await tester.ensureVisible(find.text('Archive'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Tentative — confirming.'), findsNothing);
    expect(find.text('No comments yet.'), findsOneWidget);
    expect(find.text('Show archived (1)'), findsOneWidget);

    // Reveal archived, then unarchive → back in the live list.
    await tester.ensureVisible(find.text('Show archived (1)'));
    await tester.tap(find.text('Show archived (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unarchive'));
    await tester.tap(find.text('Unarchive'));
    await tester.pumpAndSettle();

    expect(find.text('Tentative — confirming.'), findsOneWidget);
    expect(find.text('No comments yet.'), findsNothing);
  });

  testWidgets(
    'a failed initial load shows the inline error and Retry recovers',
    (tester) async {
      final repo = _FakeCommentsRepo([_live('c1', 'Loaded on retry.')])
        ..throwOnFetch = true;
      await tester.pumpWidget(_detail(repo));
      await tester.pumpAndSettle();

      // No cached data yet → the inline error + Retry, not a silent empty list.
      expect(find.text("Couldn't load comments."), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.text('Loaded on retry.'), findsNothing);

      // The next fetch succeeds; Retry loads the comment.
      repo.throwOnFetch = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load comments."), findsNothing);
      expect(find.text('Loaded on retry.'), findsOneWidget);
    },
  );

  testWidgets('a refresh that throws keeps cached comments and surfaces it', (
    tester,
  ) async {
    final repo = _FakeCommentsRepo([_live('c1', 'Still here.')]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();
    expect(find.text('Still here.'), findsOneWidget);

    // Archive succeeds, but the reload it triggers throws. The cached list must
    // stay on screen (not crash, not blank) and the failure must be surfaced.
    repo.throwOnFetch = true;
    await tester.ensureVisible(find.text('Archive'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Still here.'), findsOneWidget);
    expect(
      find.text("Couldn't refresh comments — showing saved data"),
      findsOneWidget,
    );
  });

  testWidgets(
    'Comment is disabled until the composer has non-whitespace text',
    (tester) async {
      await tester.pumpWidget(_detail(_FakeCommentsRepo()));
      await tester.pumpAndSettle();

      FilledButton commentButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Comment'),
      );

      // Empty composer → disabled.
      expect(commentButton().onPressed, isNull);

      // Whitespace only → still disabled (body would be empty after trim).
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(commentButton().onPressed, isNull);

      // Real text → enabled.
      await tester.enterText(find.byType(TextField).first, 'Ready');
      await tester.pump();
      expect(commentButton().onPressed, isNotNull);
    },
  );

  testWidgets('Save is disabled when the inline editor is emptied', (
    tester,
  ) async {
    final repo = _FakeCommentsRepo([_live('c1', 'Original')]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

    // Prefilled with the body → enabled.
    expect(saveButton().onPressed, isNotNull);

    // Cleared / whitespace only → disabled.
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.pump();
    expect(saveButton().onPressed, isNull);

    // Text again → enabled.
    await tester.enterText(find.byType(TextField).last, 'Revised');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });
}
