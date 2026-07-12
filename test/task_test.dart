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
      expect(t.createdAt, isNotNull);
      expect(t.deletedAt, isNull);
      expect(t.isArchived, isFalse);
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
    test('maps to the trimmed p_title only (the create shape)', () {
      final p = Task.draft(title: '  Prep the demo  ').toRpcParams();
      expect(p, {'p_title': 'Prep the demo'});
      // is_done is written by update_task, never create_task — must not leak in.
      expect(p.containsKey('p_is_done'), isFalse);
      expect(p.containsKey('p_id'), isFalse);
      expect(p.containsKey('created_at'), isFalse);
      expect(p.containsKey('deleted_at'), isFalse);
    });
  });

  group('Task.draft', () {
    test('is live, not-done, with an empty id and null server fields', () {
      final t = Task.draft(title: 'x');
      expect(t.id, '');
      expect(t.isDone, isFalse);
      expect(t.isArchived, isFalse);
      expect(t.createdAt, isNull);
      expect(t.updatedAt, isNull);
      expect(t.deletedAt, isNull);
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

    test('toggling isDone alone keeps the title', () {
      const t = Task(id: 't1', title: 'keep me', isDone: false);
      expect(t.copyWith(isDone: true).title, 'keep me');
    });
  });
}
