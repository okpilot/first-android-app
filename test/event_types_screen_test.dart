import 'dart:async';

import 'package:first_android_app/data/event_types_repository.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/screens/event_types_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory types repo so the screen tests never touch Supabase.
class _FakeTypesRepo implements EventTypesRepository {
  _FakeTypesRepo([List<EventType>? seed]) : types = seed ?? [];
  final List<EventType> types;

  @override
  Future<List<EventType>> fetchAll() async => List.of(types);

  @override
  Future<EventType> create(EventType draft) async {
    final saved = EventType(
      id: draft
          .id, // persist the client-supplied id (issue #9), like the real repo
      name: draft.name,
      colorHex: draft.colorHex,
    );
    types.add(saved);
    return saved;
  }

  @override
  Future<EventType> update(EventType type) async {
    final i = types.indexWhere((t) => t.id == type.id);
    if (i >= 0) types[i] = type;
    return type;
  }

  @override
  Future<void> softDelete(String id) async =>
      types.removeWhere((t) => t.id == id);
}

/// Succeeds on the first load, throws on every later fetch — to exercise a refresh
/// that fails while cached data is already on screen.
class _RefreshFailsRepo implements EventTypesRepository {
  _RefreshFailsRepo(this._first);
  final List<EventType> _first;
  int _calls = 0;

  @override
  Future<List<EventType>> fetchAll() async {
    if (_calls++ == 0) return List.of(_first);
    throw Exception('offline');
  }

  @override
  Future<EventType> create(EventType draft) => throw UnimplementedError();
  @override
  Future<EventType> update(EventType type) => throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

/// Hands out a fresh [Completer] per fetch so the test can resolve loads out of
/// order — to prove an older in-flight load can't overwrite a newer one. `create`
/// resolves immediately (only [fetchAll] is externally controlled).
class _OrderedRepo implements EventTypesRepository {
  final List<Completer<List<EventType>>> fetches = [];

  @override
  Future<List<EventType>> fetchAll() {
    final c = Completer<List<EventType>>();
    fetches.add(c);
    return c.future;
  }

  @override
  Future<EventType> create(EventType draft) async =>
      EventType(id: draft.id, name: draft.name, colorHex: draft.colorHex);
  @override
  Future<EventType> update(EventType type) => throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Adds a type through the editor — the app's other way to trigger a reload.
Future<void> _addTypeViaEditor(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'New type'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Add type'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state prompts creating the first type', (tester) async {
    await tester.pumpWidget(
      _wrap(EventTypesScreen(repository: _FakeTypesRepo())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No event types yet'), findsOneWidget);
    expect(find.text('Create your first type'), findsOneWidget);
  });

  testWidgets('lists existing types with their names', (tester) async {
    final repo = _FakeTypesRepo([
      const EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9'),
      const EventType(id: 't2', name: 'Call', colorHex: '#2FA090'),
    ]);
    await tester.pumpWidget(_wrap(EventTypesScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('creates a new type via the editor', (tester) async {
    final repo = _FakeTypesRepo();
    await tester.pumpWidget(_wrap(EventTypesScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New type'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Interview');
    await tester.tap(find.widgetWithText(FilledButton, 'Add type'));
    await tester.pumpAndSettle();

    // Back on the manager, the new type is listed.
    expect(find.text('Interview'), findsOneWidget);
    expect(repo.types.single.name, 'Interview');
  });

  testWidgets('deletes a type from the editor (non-destructive confirm)', (
    tester,
  ) async {
    final repo = _FakeTypesRepo([
      const EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpWidget(_wrap(EventTypesScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meeting'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete type'));
    await tester.pumpAndSettle();
    // Confirm dialog explains the non-destructive fallback.
    expect(find.textContaining('No type'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Meeting'), findsNothing);
    expect(find.text('No event types yet'), findsOneWidget);
    expect(repo.types, isEmpty);
  });

  testWidgets('a failed refresh keeps cached data and surfaces the failure', (
    tester,
  ) async {
    final repo = _RefreshFailsRepo([
      const EventType(id: 't1', name: 'Meeting', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpWidget(_wrap(EventTypesScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Meeting'), findsOneWidget);

    // Pull-to-refresh — the second fetch throws.
    await tester.fling(find.text('Meeting'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    // The cached list stays put, and the failure is no longer silent.
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text("Couldn't refresh — showing saved data"), findsOneWidget);
  });

  testWidgets('a stale load completing late cannot overwrite newer data', (
    tester,
  ) async {
    final repo = _OrderedRepo();
    await tester.pumpWidget(_wrap(EventTypesScreen(repository: repo)));
    await tester.pump();

    // Settle the initial load so the list is on screen (no spinner to churn
    // pumpAndSettle), leaving fetches[0] resolved.
    repo.fetches[0].complete(const [
      EventType(id: 'a', name: 'Alpha', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    // Kick off two overlapping reloads: an older one (fetches[1]) then a newer
    // one (fetches[2]) that supersedes it.
    await _addTypeViaEditor(tester, 'older');
    await _addTypeViaEditor(tester, 'newer');
    expect(repo.fetches.length, 3);

    // Resolve the NEWER load first, then let the older one land late.
    repo.fetches[2].complete(const [
      EventType(id: 'n', name: 'Newer', colorHex: '#2FA090'),
    ]);
    await tester.pumpAndSettle();
    repo.fetches[1].complete(const [
      EventType(id: 'o', name: 'Older', colorHex: '#C24A4A'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Newer'), findsOneWidget);

    // Force the builder to fall back to _lastData by failing one more load (a
    // pending load keeps the old snapshot's data, hiding a corrupted _lastData;
    // an error drops snapshot.data so _lastData is what shows).
    await _addTypeViaEditor(tester, 'again');
    repo.fetches[3].completeError(Exception('offline'));
    await tester.pumpAndSettle();

    // If the stale load had overwritten _lastData, 'Older' would surface now.
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsNothing);
  });
}
