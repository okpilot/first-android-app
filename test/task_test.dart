import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/task.dart';

void main() {
  group('Task.fromJson', () {
    test('parses a live, active task', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'Call Nadia about the renewal',
        'is_done': false,
        'created_at': '2026-07-12T14:32:00+00:00',
        'updated_at': '2026-07-12T14:32:00+00:00',
        'deleted_at': null,
      });
      expect(t.id, 't1');
      expect(t.title, 'Call Nadia about the renewal');
      expect(t.isDone, isFalse);
      expect(t.notes, isNull); // absent notes → null
      expect(t.createdAt, isNotNull);
      expect(t.deletedAt, isNull);
      expect(t.isArchived, isFalse);
    });

    test('reads a notes value back', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'Call Nadia',
        'is_done': false,
        'notes': 'Prefers a call after 15:00.',
      });
      expect(t.notes, 'Prefers a call after 15:00.');
    });

    test('parses a completed task', () {
      final t = Task.fromJson({
        'id': 't2',
        'title': 'Deploy the migration',
        'is_done': true,
      });
      expect(t.isDone, isTrue);
      expect(t.isArchived, isFalse);
    });

    test('an archived task reads deleted_at back and isArchived is true', () {
      final t = Task.fromJson({
        'id': 't3',
        'title': 'Old checklist',
        'is_done': false,
        'created_at': '2026-07-10T09:00:00Z',
        'deleted_at': '2026-07-11T08:00:00Z',
      });
      expect(t.isArchived, isTrue);
      expect(t.deletedAt, isNotNull);
    });

    test('absent is_done defaults to false (no crash)', () {
      final t = Task.fromJson({'id': 't4', 'title': 'Hi'});
      expect(t.isDone, isFalse);
      expect(t.createdAt, isNull);
      expect(t.updatedAt, isNull);
      expect(t.deletedAt, isNull);
    });

    test('empty-string timestamps parse to null (not the epoch)', () {
      final t = Task.fromJson({
        'id': 't5',
        'title': 'Hi',
        'is_done': false,
        'created_at': '',
        'updated_at': '',
        'deleted_at': '',
      });
      expect(t.createdAt, isNull);
      expect(t.updatedAt, isNull);
      expect(t.deletedAt, isNull);
      expect(t.isArchived, isFalse); // '' deleted_at must not read as archived
    });

    test('an unparseable timestamp yields null rather than throwing', () {
      final t = Task.fromJson({
        'id': 't6',
        'title': 'Hi',
        'created_at': 'not-a-date',
      });
      expect(t.createdAt, isNull);
    });
  });

  group('Task.toRpcParams', () {
    test('maps to trimmed p_title + p_notes (the create shape)', () {
      final p = Task.draft(title: '  Prep the demo  ').toRpcParams();
      // p_notes is always present (create_task(p_title, p_notes)); a draft without
      // notes sends null, which the server normalizes to NULL.
      expect(p, {'p_title': 'Prep the demo', 'p_notes': null});
      // is_done is written by update_task, never create_task — must not leak in.
      expect(p.containsKey('p_is_done'), isFalse);
      expect(p.containsKey('p_id'), isFalse);
      expect(p.containsKey('created_at'), isFalse);
      expect(p.containsKey('deleted_at'), isFalse);
    });

    test('carries notes verbatim (the server does the trim/nullif)', () {
      final p = Task.draft(title: 'x', notes: '  jot this  ').toRpcParams();
      expect(p['p_notes'], '  jot this  ');
    });
  });

  group('Task.draft', () {
    test('is live, not-done, with an empty id and null server fields', () {
      final t = Task.draft(title: 'x');
      expect(t.id, '');
      expect(t.isDone, isFalse);
      expect(t.isArchived, isFalse);
      expect(t.notes, isNull); // notes optional → null when omitted
      expect(t.createdAt, isNull);
      expect(t.updatedAt, isNull);
      expect(t.deletedAt, isNull);
    });

    test('carries optional notes', () {
      expect(Task.draft(title: 'x', notes: 'hi').notes, 'hi');
    });
  });

  group('Task.copyWith', () {
    test('replaces title / isDone but keeps id / timestamps / deletedAt', () {
      final original = Task(
        id: 't1',
        title: 'first',
        isDone: false,
        createdAt: DateTime(2026, 7, 12),
        deletedAt: DateTime(2026, 7, 12),
      );
      final edited = original.copyWith(title: 'second', isDone: true);
      expect(edited.title, 'second');
      expect(edited.isDone, isTrue);
      expect(edited.id, 't1');
      expect(edited.createdAt, original.createdAt);
      expect(edited.deletedAt, original.deletedAt);
    });

    test('toggling isDone alone keeps the title AND the notes', () {
      const t = Task(id: 't1', title: 'keep me', isDone: false, notes: 'ctx');
      final toggled = t.copyWith(isDone: true);
      expect(toggled.title, 'keep me');
      expect(toggled.notes, 'ctx'); // a null notes arg means "keep"
    });

    test('replaces notes when given (including an empty string to clear)', () {
      const t = Task(id: 't1', title: 'x', notes: 'old');
      expect(t.copyWith(notes: 'new').notes, 'new');
      // The form clears by passing '': non-null, so it overrides. (The server then
      // normalizes '' → NULL on the round-trip.)
      expect(t.copyWith(notes: '').notes, '');
    });
  });
}
