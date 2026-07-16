import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/screens/event_detail_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/comments_section.dart';

import 'support/fakes.dart';

// The Comments section is private to event_detail_screen.dart, so it's exercised through
// its public host, EventDetailScreen. Only the comments repo does anything here; the other
// three are inert fakes.

/// In-memory comments repo: add/edit/archive/unarchive mutate the list and fetch re-reads
/// it (newest first), so the widget round-trips like the real direct-CRUD repository.
class _GatedCommentsRepo implements CommentsRepository {
  _GatedCommentsRepo([List<Comment>? seed]) : _items = seed ?? [];

  final List<Comment> _items;
  int _seq = 0;
  bool throwOnFetch = false;
  // The client-minted draft id seen on each add() — lets a test prove the composer retires its
  // _pendingId after a successful add so back-to-back comments don't collide (issue #9).
  final List<String> addedDraftIds = [];
  // When set, archive() awaits this before mutating — holds a write in flight so a test
  // can observe the `_busy` re-entrancy guard mid-write. Complete it to let the write finish.
  Completer<void>? archiveGate;

  @override
  Future<List<Comment>> fetchFor(String parentId) async {
    if (throwOnFetch) throw Exception('offline');
    return _items.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // newest first
  }

  @override
  Future<Comment> add(Comment draft) async {
    addedDraftIds.add(draft.id);
    final saved = Comment(
      id: 'c${_seq++}',
      parentId: draft.parentId,
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
  Future<Comment> archive(String id) async {
    if (archiveGate != null) await archiveGate!.future;
    return _setDeleted(id, DateTime(2026, 7, 11));
  }

  @override
  Future<Comment> unarchive(String id) async => _setDeleted(id, null);

  Comment _setDeleted(String id, DateTime? when) {
    final i = _items.indexWhere((c) => c.id == id);
    final c = _items[i];
    final next = Comment(
      id: c.id,
      parentId: c.parentId,
      body: c.body,
      createdAt: c.createdAt,
      deletedAt: when,
    );
    _items[i] = next;
    return next;
  }
}

final _event = Event(
  id: 'e1',
  title: 'Design review',
  date: DateTime(2026, 7, 11),
  allDay: true, // all-day → no stray time digits to collide with the count chip
);

Widget _detail(_GatedCommentsRepo comments) => MaterialApp(
  theme: AppTheme.light,
  home: EventDetailScreen(
    eventsRepository: FakeEventsRepo(),
    contactsRepository: FakeContactsRepo(),
    eventTypesRepository: FakeEventTypesRepo(),
    commentsRepository: comments,
    event: _event,
  ),
);

Comment _live(String id, String body) =>
    Comment(id: id, parentId: 'e1', body: body);

// A tiny host that holds `readOnly` in its OWN State and rebuilds the SAME CommentsSection
// in place when flipped — no remount, so the section's State survives and `didUpdateWidget`
// fires. This is the in-place archive flip on the phone path (a task archived while its
// comment editor is open), which no key-swap remount would reproduce.
class _ReadOnlyFlipHost extends StatefulWidget {
  const _ReadOnlyFlipHost({required this.repository, required this.parentId});

  final CommentsRepository repository;
  final String parentId;

  @override
  State<_ReadOnlyFlipHost> createState() => _ReadOnlyFlipHostState();
}

class _ReadOnlyFlipHostState extends State<_ReadOnlyFlipHost> {
  bool _readOnly = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () => setState(() => _readOnly = true),
              child: const Text('archive-in-place'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: CommentsSection(
                  repository: widget.repository,
                  parentId: widget.parentId,
                  readOnly: _readOnly,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mounts the widget on its own — no EventDetailScreen host — with an arbitrary parentId,
// the way Slice 2b will wire it onto a task. Proves CommentsSection is genuinely
// parent-agnostic and doesn't depend on any event-specific plumbing.
Widget _standalone(
  _GatedCommentsRepo comments,
  String parentId, {
  bool readOnly = false,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      child: CommentsSection(
        repository: comments,
        parentId: parentId,
        readOnly: readOnly,
      ),
    ),
  ),
);

void main() {
  testWidgets('empty state when there are no comments', (tester) async {
    await tester.pumpWidget(_detail(_GatedCommentsRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('No comments yet.'), findsOneWidget);
  });

  testWidgets('lists live comments and hides archived behind the toggle', (
    tester,
  ) async {
    final repo = _GatedCommentsRepo([
      _live('c1', 'Sent the agenda round.'),
      Comment(
        id: 'c0',
        parentId: 'e1',
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
    final repo = _GatedCommentsRepo();
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  New note  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Comment'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget); // trimmed + persisted
    expect(find.text('No comments yet.'), findsNothing);
  });

  testWidgets(
    'back-to-back adds use different client-minted ids (the composer resets _pendingId, issue #9)',
    (tester) async {
      // The composer stays mounted after a successful send (unlike the pop-on-success forms), so its
      // client-minted id is MUTABLE and must be retired after each add — else the second comment would
      // reuse the first id and the DB's `on conflict (id) do nothing` would silently drop it.
      final repo = _GatedCommentsRepo();
      await tester.pumpWidget(_detail(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'First');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Comment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Second');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Comment'));
      await tester.pumpAndSettle();

      expect(repo.addedDraftIds, hasLength(2));
      expect(repo.addedDraftIds.first, isNotEmpty);
      expect(repo.addedDraftIds[1], isNotEmpty);
      expect(repo.addedDraftIds[0], isNot(repo.addedDraftIds[1]));
      // Both comments actually persisted — the second wasn't conflict-skipped.
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    },
  );

  testWidgets('edits a comment inline', (tester) async {
    final repo = _GatedCommentsRepo([_live('c1', 'Draft wording')]);
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
    final repo = _GatedCommentsRepo([_live('c1', 'Tentative — confirming.')]);
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
      final repo = _GatedCommentsRepo([_live('c1', 'Loaded on retry.')])
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
    final repo = _GatedCommentsRepo([_live('c1', 'Still here.')]);
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
      await tester.pumpWidget(_detail(_GatedCommentsRepo()));
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
    final repo = _GatedCommentsRepo([_live('c1', 'Original')]);
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

  testWidgets(
    'actions are disabled while a write is in flight, then re-enable when it resolves',
    (tester) async {
      // Gate the archive write so it stays pending — `_busy` is true across the await,
      // which is exactly the re-entrancy window the doc-comment on `_run` promises.
      final gate = Completer<void>();
      final repo = _GatedCommentsRepo([_live('c1', 'Still around.')])
        ..archiveGate = gate;
      await tester.pumpWidget(_detail(repo));
      await tester.pumpAndSettle();

      // Give the composer real text so its Comment button is enabled *before* the write —
      // that way disabling it mid-flight can only be `_busy`, not the empty-text gate.
      await tester.enterText(find.byType(TextField).first, 'A pending note');
      await tester.pump();

      FilledButton commentButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Comment'),
      );
      TextButton editAction() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Edit'));
      TextButton archiveAction() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Archive'));

      expect(commentButton().onPressed, isNotNull); // enabled before the write

      // Start the archive; the gated repo call keeps it pending, so `_busy` stays true.
      await tester.ensureVisible(find.text('Archive'));
      await tester.tap(find.text('Archive'));
      await tester
          .pump(); // flush setState(_busy = true); write still in flight

      // Mid-flight: every action is disabled — the composer's Comment despite its text,
      // and the tile's Edit / Archive.
      expect(commentButton().onPressed, isNull);
      expect(editAction().onPressed, isNull);
      expect(archiveAction().onPressed, isNull);

      // Let the write complete → reload runs, `_busy` clears.
      gate.complete();
      await tester.pumpAndSettle();

      // The archive landed (dropped from live) and the composer is interactive again.
      expect(find.text('Still around.'), findsNothing);
      expect(find.text('No comments yet.'), findsOneWidget);
      expect(commentButton().onPressed, isNotNull);
    },
  );

  testWidgets('Cancel discards inline edits and keeps the original body', (
    tester,
  ) async {
    final repo = _GatedCommentsRepo([_live('c1', 'Original body')]);
    await tester.pumpWidget(_detail(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Type a change into the inline editor but abandon it with Cancel.
    await tester.enterText(find.byType(TextField).last, 'Discarded change');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Reverted to view mode: the editor and Save are gone, the original body is intact,
    // and the typed-but-cancelled text was never persisted.
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.text('Discarded change'), findsNothing);
    expect(find.text('Original body'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget); // action row back in view mode
  });

  // The whole point of the extraction (Slice 2a): the widget is a standalone, public,
  // parent-agnostic section ready to hang off a task in Slice 2b. These mount it directly
  // — no EventDetailScreen — with a task-shaped parentId to prove that contract.
  group('standalone / parent-agnostic', () {
    testWidgets('mounts on its own and lists only the given parent\'s comments', (
      tester,
    ) async {
      // Two parents in one repo; the widget must show only 'task-42' and never leak 'e1'.
      final repo = _GatedCommentsRepo([
        Comment(id: 'c9', parentId: 'task-42', body: 'Task-scoped note.'),
        _live('c1', 'Event-scoped note.'),
      ]);
      await tester.pumpWidget(_standalone(repo, 'task-42'));
      await tester.pumpAndSettle();

      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Task-scoped note.'), findsOneWidget);
      expect(find.text('Event-scoped note.'), findsNothing);
    });

    testWidgets(
      'a comment added standalone is created under the given parentId',
      (tester) async {
        final repo = _GatedCommentsRepo();
        await tester.pumpWidget(_standalone(repo, 'task-42'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'From the task view',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Comment'));
        await tester.pumpAndSettle();

        expect(find.text('From the task view'), findsOneWidget);
        // The arbitrary parentId flowed through Comment.draft into the persisted row —
        // it is retrievable under 'task-42', not the event default.
        final saved = await repo.fetchFor('task-42');
        expect(saved, hasLength(1));
        expect(saved.single.parentId, 'task-42');
      },
    );
  });

  // Read-only mode (Slice 2b): an archived task's comment log is frozen history — the bodies
  // (live and archived) still render and the "Show archived" toggle still works, but every
  // mutating affordance is gone: no composer, no per-comment Edit / Archive / Unarchive.
  group('read-only mode', () {
    _GatedCommentsRepo seeded() => _GatedCommentsRepo([
      _live('c1', 'Live note stays visible.'),
      Comment(
        id: 'c0',
        parentId: 'e1',
        body: 'Archived note stays visible.',
        deletedAt: DateTime(2026, 7, 10),
      ),
    ]);

    testWidgets(
      'read-only hides the composer and the live comment\'s Edit / Archive',
      (tester) async {
        await tester.pumpWidget(_standalone(seeded(), 'e1', readOnly: true));
        await tester.pumpAndSettle();

        // No composer at all.
        expect(find.byType(TextField), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Comment'), findsNothing);

        // The live body renders, but its mutating actions are absent.
        expect(find.text('Live note stays visible.'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);
        expect(find.widgetWithText(TextButton, 'Archive'), findsNothing);
      },
    );

    testWidgets('read-only reveals archived bodies but drops Unarchive', (
      tester,
    ) async {
      await tester.pumpWidget(_standalone(seeded(), 'e1', readOnly: true));
      await tester.pumpAndSettle();

      // The archived section toggle still works in read-only mode.
      await tester.ensureVisible(find.text('Show archived (1)'));
      await tester.tap(find.text('Show archived (1)'));
      await tester.pumpAndSettle();

      // Both bodies now on screen, but the frozen log offers no Unarchive.
      expect(find.text('Live note stays visible.'), findsOneWidget);
      expect(find.text('Archived note stays visible.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Unarchive'), findsNothing);
    });

    testWidgets(
      'the default (read-write) mode DOES show the composer and per-comment actions',
      (tester) async {
        // Contrast: same data, default mode → every affordance the read-only case dropped is back.
        await tester.pumpWidget(_standalone(seeded(), 'e1'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Comment'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Archive'), findsOneWidget);

        await tester.ensureVisible(find.text('Show archived (1)'));
        await tester.tap(find.text('Show archived (1)'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, 'Unarchive'), findsOneWidget);
      },
    );

    // Regression: the read-only gate must also close an OPEN inline editor when the parent
    // flips to read-only in place (task archived while editing a comment). Pre-fix, the tile
    // gated the editor on `_editingId` alone, so a live Save survived on the now-frozen log.
    testWidgets(
      'flipping to read-only in place closes an open editor (no live Save on a frozen log)',
      (tester) async {
        final repo = _GatedCommentsRepo([_live('c1', 'Draft wording')]);
        await tester.pumpWidget(
          _ReadOnlyFlipHost(repository: repo, parentId: 'e1'),
        );
        await tester.pumpAndSettle();

        // Open the inline editor on the live comment → an editing TextField + a Save button.
        await tester.ensureVisible(find.text('Edit'));
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
        expect(
          find.byType(TextField),
          findsWidgets,
        ); // composer + inline editor

        // Archive the task in place → the SAME CommentsSection State rebuilds readOnly: true.
        await tester.tap(find.text('archive-in-place'));
        await tester.pumpAndSettle();

        // No live write affordance survives on the frozen log: the editor and Save are gone
        // (and the composer with them), but the comment body still renders read-only.
        expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Draft wording'), findsOneWidget);
      },
    );
  });
}
