import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/data/task_categories_repository.dart';
import 'package:first_android_app/models/task_category.dart';
import 'package:first_android_app/screens/category_picker_screen.dart';
import 'package:first_android_app/theme.dart';

/// A minimal fake categories repo — the picker only reads the list via fetchAll; writes unused.
class _FakeTaskCategoriesRepo implements TaskCategoriesRepository {
  _FakeTaskCategoriesRepo([this._all = const []]);
  final List<TaskCategory> _all;

  @override
  Future<List<TaskCategory>> fetchAll() async => _all;
  @override
  Future<TaskCategory> create(TaskCategory draft) async => draft;
  @override
  Future<TaskCategory> update(TaskCategory category) async => category;
  @override
  Future<void> softDelete(String id) async {}
}

/// fetchAll throws — drives the picker's "Couldn't load categories" error state.
class _FailingCategoriesRepo implements TaskCategoriesRepository {
  @override
  Future<List<TaskCategory>> fetchAll() async => throw Exception('offline');
  @override
  Future<TaskCategory> create(TaskCategory draft) => throw UnimplementedError();
  @override
  Future<TaskCategory> update(TaskCategory category) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

const _list = [
  TaskCategory(id: 'k1', name: 'Work', colorHex: '#4E7BC9'),
  TaskCategory(id: 'k2', name: 'Home', colorHex: '#22A06B'),
];

Widget _picker({
  List<TaskCategory> initialSelected = const [],
  TaskCategoriesRepository? repo,
}) => MaterialApp(
  theme: AppTheme.light,
  home: CategoryPickerScreen(
    repository: repo ?? _FakeTaskCategoriesRepo(_list),
    initialSelected: initialSelected,
  ),
);

void main() {
  testWidgets('empty selection shows the "Add categories" AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(_picker());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Add categories'), findsOneWidget);
  });

  testWidgets('a pre-selection shows the count and toggles it live', (
    tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        initialSelected: const [
          TaskCategory(id: 'k1', name: 'Work', colorHex: '#4E7BC9'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // n > 0 branch: the count is appended.
    expect(find.widgetWithText(AppBar, 'Categories · 1'), findsOneWidget);

    // Selecting the second updates the count live (1 → 2).
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Home'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Categories · 2'), findsOneWidget);

    // Un-selecting both drops back to the "Add" copy.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Home'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add categories'), findsOneWidget);
  });

  testWidgets('a pre-selected category renders as a checked box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        initialSelected: const [
          TaskCategory(id: 'k1', name: 'Work', colorHex: '#4E7BC9'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final work = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Work'),
    );
    final home = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Home'),
    );
    expect(work.value, isTrue);
    expect(home.value, isFalse);
  });

  testWidgets('search filters the list by name', (tester) async {
    await tester.pumpWidget(_picker());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hom');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CheckboxListTile, 'Home'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Work'), findsNothing);
  });

  testWidgets('Done pops the committed selection to the caller', (
    tester,
  ) async {
    List<TaskCategory>? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<List<TaskCategory>>(
                    MaterialPageRoute(
                      builder: (_) => CategoryPickerScreen(
                        repository: _FakeTaskCategoriesRepo(_list),
                        initialSelected: const [],
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.map((c) => c.id), ['k2']);
  });

  testWidgets('an empty list shows the "Add categories in Settings" state', (
    tester,
  ) async {
    await tester.pumpWidget(_picker(repo: _FakeTaskCategoriesRepo()));
    await tester.pumpAndSettle();

    expect(find.text('No categories yet'), findsOneWidget);
    expect(
      find.text('Add categories in Settings first, then tag tasks with them.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load shows the categories error state', (tester) async {
    await tester.pumpWidget(_picker(repo: _FailingCategoriesRepo()));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load categories"), findsOneWidget);
  });
}
