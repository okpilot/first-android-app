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
      id: 'id-${types.length}',
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

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

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
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
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
}
