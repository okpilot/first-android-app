import 'dart:async';

import 'package:first_android_app/data/task_categories_repository.dart';
import 'package:first_android_app/models/task_category.dart';
import 'package:first_android_app/screens/task_categories_screen.dart';
import 'package:first_android_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory categories repo so the screen tests never touch Supabase.
class _FakeCategoriesRepo implements TaskCategoriesRepository {
  _FakeCategoriesRepo([List<TaskCategory>? seed]) : categories = seed ?? [];
  final List<TaskCategory> categories;

  @override
  Future<List<TaskCategory>> fetchAll() async => List.of(categories);

  @override
  Future<TaskCategory> create(TaskCategory draft) async {
    final saved = TaskCategory(
      id: draft
          .id, // persist the client-supplied id (issue #9), like the real repo
      name: draft.name,
      colorHex: draft.colorHex,
    );
    categories.add(saved);
    return saved;
  }

  @override
  Future<TaskCategory> update(TaskCategory category) async {
    final i = categories.indexWhere((c) => c.id == category.id);
    if (i >= 0) categories[i] = category;
    return category;
  }

  @override
  Future<void> softDelete(String id) async =>
      categories.removeWhere((c) => c.id == id);
}

/// Succeeds on the first load, throws on every later fetch — to exercise a refresh
/// that fails while cached data is already on screen.
class _RefreshFailsRepo implements TaskCategoriesRepository {
  _RefreshFailsRepo(this._first);
  final List<TaskCategory> _first;
  int _calls = 0;

  @override
  Future<List<TaskCategory>> fetchAll() async {
    if (_calls++ == 0) return List.of(_first);
    throw Exception('offline');
  }

  @override
  Future<TaskCategory> create(TaskCategory draft) => throw UnimplementedError();
  @override
  Future<TaskCategory> update(TaskCategory category) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

/// Hands out a fresh [Completer] per fetch so the test can resolve loads out of
/// order — to prove an older in-flight load can't overwrite a newer one. `create`
/// resolves immediately (only [fetchAll] is externally controlled).
class _OrderedRepo implements TaskCategoriesRepository {
  final List<Completer<List<TaskCategory>>> fetches = [];

  @override
  Future<List<TaskCategory>> fetchAll() {
    final c = Completer<List<TaskCategory>>();
    fetches.add(c);
    return c.future;
  }

  @override
  Future<TaskCategory> create(TaskCategory draft) async =>
      TaskCategory(id: draft.id, name: draft.name, colorHex: draft.colorHex);
  @override
  Future<TaskCategory> update(TaskCategory category) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

/// Fails `fetchAll` while [fail] is true — to assert the initial-load error state,
/// then prove Retry recovers once the backend returns. Flip [fail] to false first.
class _FailingCategoriesRepo implements TaskCategoriesRepository {
  _FailingCategoriesRepo({this.categories = const []});
  // Starts failing; the Retry test flips it to false directly to prove recovery.
  bool fail = true;
  final List<TaskCategory> categories;

  @override
  Future<List<TaskCategory>> fetchAll() async {
    if (fail) throw Exception('offline');
    return List.of(categories);
  }

  @override
  Future<TaskCategory> create(TaskCategory draft) => throw UnimplementedError();
  @override
  Future<TaskCategory> update(TaskCategory category) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

/// `fetchAll` succeeds (empty); `create` throws — to exercise the editor's
/// "Couldn't save" snackbar path.
class _CreateFailsRepo implements TaskCategoriesRepository {
  @override
  Future<List<TaskCategory>> fetchAll() async => const [];
  @override
  Future<TaskCategory> create(TaskCategory draft) async =>
      throw Exception('offline');
  @override
  Future<TaskCategory> update(TaskCategory category) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Adds a category through the editor — the app's other way to trigger a reload.
Future<void> _addCategoryViaEditor(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'New category'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Add category'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state prompts creating the first category', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TaskCategoriesScreen(repository: _FakeCategoriesRepo())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No task categories yet'), findsOneWidget);
    expect(find.text('Create your first category'), findsOneWidget);
  });

  testWidgets('lists existing categories with their names', (tester) async {
    final repo = _FakeCategoriesRepo([
      const TaskCategory(id: 'c1', name: 'Follow-up', colorHex: '#4E7BC9'),
      const TaskCategory(id: 'c2', name: 'Errand', colorHex: '#2FA090'),
    ]);
    await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Follow-up'), findsOneWidget);
    expect(find.text('Errand'), findsOneWidget);
  });

  testWidgets('creates a new category via the editor', (tester) async {
    final repo = _FakeCategoriesRepo();
    await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New category'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Waiting-on');
    await tester.tap(find.widgetWithText(FilledButton, 'Add category'));
    await tester.pumpAndSettle();

    // Back on the manager, the new category is listed.
    expect(find.text('Waiting-on'), findsOneWidget);
    expect(repo.categories.single.name, 'Waiting-on');
  });

  testWidgets('deletes a category from the editor (confirm dialog)', (
    tester,
  ) async {
    final repo = _FakeCategoriesRepo([
      const TaskCategory(id: 'c1', name: 'Follow-up', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Follow-up'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete category'));
    await tester.pumpAndSettle();
    // Confirm dialog warns it can't be undone.
    expect(find.textContaining("can't be undone"), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Follow-up'), findsNothing);
    expect(find.text('No task categories yet'), findsOneWidget);
    expect(repo.categories, isEmpty);
  });

  testWidgets(
    'a failed initial load shows the error state, and Retry recovers',
    (tester) async {
      final repo = _FailingCategoriesRepo(
        categories: const [
          TaskCategory(id: 'c1', name: 'Follow-up', colorHex: '#4E7BC9'),
        ],
      );
      await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load task categories"), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

      // Backend comes back; Retry re-fetches and the list renders.
      repo.fail = false;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Follow-up'), findsOneWidget);
    },
  );

  testWidgets(
    'renaming and recolouring an existing category persists via update',
    (tester) async {
      final repo = _FakeCategoriesRepo([
        const TaskCategory(id: 'c1', name: 'Follow-up', colorHex: '#4E7BC9'),
      ]);
      await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Follow-up'));
      await tester.pumpAndSettle();

      // Rename and pick a different swatch (Blue -> Teal, #2fa090).
      await tester.enterText(find.byType(TextFormField), 'Waiting-on');
      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      // Back on the manager with the persisted rename + recolour (same id).
      expect(find.text('Waiting-on'), findsOneWidget);
      final saved = repo.categories.single;
      expect(saved.id, 'c1');
      expect(saved.name, 'Waiting-on');
      expect(saved.colorHex, '#2fa090');
    },
  );

  testWidgets('a failed save surfaces the error and stays on the editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TaskCategoriesScreen(repository: _CreateFailsRepo())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New category'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Waiting-on');
    await tester.tap(find.widgetWithText(FilledButton, 'Add category'));
    await tester.pumpAndSettle();

    // The failure is surfaced and we're still on the editor (the typed name shows).
    expect(find.text("Couldn't save — please try again"), findsOneWidget);
    expect(find.text('Waiting-on'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps cached data and surfaces the failure', (
    tester,
  ) async {
    final repo = _RefreshFailsRepo([
      const TaskCategory(id: 'c1', name: 'Follow-up', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Follow-up'), findsOneWidget);

    // Pull-to-refresh — the second fetch throws.
    await tester.fling(find.text('Follow-up'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    // The cached list stays put, and the failure is no longer silent.
    expect(find.text('Follow-up'), findsOneWidget);
    expect(find.text("Couldn't refresh — showing saved data"), findsOneWidget);
  });

  testWidgets('a stale load completing late cannot overwrite newer data', (
    tester,
  ) async {
    final repo = _OrderedRepo();
    await tester.pumpWidget(_wrap(TaskCategoriesScreen(repository: repo)));
    await tester.pump();

    // Settle the initial load so the list is on screen (no spinner to churn
    // pumpAndSettle), leaving fetches[0] resolved.
    repo.fetches[0].complete(const [
      TaskCategory(id: 'a', name: 'Alpha', colorHex: '#4E7BC9'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    // Kick off two overlapping reloads: an older one (fetches[1]) then a newer
    // one (fetches[2]) that supersedes it.
    await _addCategoryViaEditor(tester, 'older');
    await _addCategoryViaEditor(tester, 'newer');
    expect(repo.fetches.length, 3);

    // Resolve the NEWER load first, then let the older one land late.
    repo.fetches[2].complete(const [
      TaskCategory(id: 'n', name: 'Newer', colorHex: '#2FA090'),
    ]);
    await tester.pumpAndSettle();
    repo.fetches[1].complete(const [
      TaskCategory(id: 'o', name: 'Older', colorHex: '#C24A4A'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Newer'), findsOneWidget);

    // Force the builder to fall back to _lastData by failing one more load (a
    // pending load keeps the old snapshot's data, hiding a corrupted _lastData;
    // an error drops snapshot.data so _lastData is what shows).
    await _addCategoryViaEditor(tester, 'again');
    repo.fetches[3].completeError(Exception('offline'));
    await tester.pumpAndSettle();

    // If the stale load had overwritten _lastData, 'Older' would surface now.
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsNothing);
  });
}
