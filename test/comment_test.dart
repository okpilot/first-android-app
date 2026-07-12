import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses a live comment', () {
      final c = Comment.fromJson({
        'id': 'c1',
        'event_id': 'e1',
        'body': 'Looks good — ship it.',
        'created_at': '2026-07-11T14:32:00+00:00',
        'updated_at': '2026-07-11T14:32:00+00:00',
        'deleted_at': null,
      });
      expect(c.id, 'c1');
      expect(c.eventId, 'e1');
      expect(c.body, 'Looks good — ship it.');
      expect(c.createdAt, isNotNull);
      expect(c.deletedAt, isNull);
      expect(c.isArchived, isFalse);
    });

    test(
      'an archived comment reads deleted_at back and isArchived is true',
      () {
        final c = Comment.fromJson({
          'id': 'c2',
          'event_id': 'e1',
          'body': 'Old note.',
          'created_at': '2026-07-10T09:00:00Z',
          'deleted_at': '2026-07-11T08:00:00Z',
        });
        expect(c.isArchived, isTrue);
        expect(c.deletedAt, isNotNull);
      },
    );

    test('absent timestamp keys parse to null (no crash)', () {
      final c = Comment.fromJson({'id': 'c3', 'event_id': 'e1', 'body': 'Hi'});
      expect(c.createdAt, isNull);
      expect(c.updatedAt, isNull);
      expect(c.deletedAt, isNull);
      expect(c.isArchived, isFalse);
    });

    test('empty-string timestamps parse to null (not the epoch)', () {
      final c = Comment.fromJson({
        'id': 'c4',
        'event_id': 'e1',
        'body': 'Hi',
        'created_at': '',
        'updated_at': '',
        'deleted_at': '',
      });
      expect(c.createdAt, isNull);
      expect(c.updatedAt, isNull);
      expect(c.deletedAt, isNull);
      expect(c.isArchived, isFalse); // '' deleted_at must not read as archived
    });

    test('an unparseable timestamp yields null rather than throwing', () {
      final c = Comment.fromJson({
        'id': 'c5',
        'event_id': 'e1',
        'body': 'Hi',
        'created_at': 'not-a-date',
      });
      expect(c.createdAt, isNull);
    });
  });

  group('Comment.toRpcParams', () {
    test('maps to p_event_id + trimmed p_body (never server-owned fields)', () {
      final p = Comment.draft(eventId: 'e1', body: '  hello  ').toRpcParams();
      expect(p, {'p_event_id': 'e1', 'p_body': 'hello'});
      expect(p.containsKey('p_id'), isFalse);
      expect(p.containsKey('created_at'), isFalse);
      expect(p.containsKey('deleted_at'), isFalse);
    });
  });

  group('Comment.draft', () {
    test('has an empty id and null server fields', () {
      final c = Comment.draft(eventId: 'e1', body: 'x');
      expect(c.id, '');
      expect(c.createdAt, isNull);
      expect(c.updatedAt, isNull);
      expect(c.deletedAt, isNull);
    });
  });

  group('Comment.copyWith', () {
    test('replaces body but keeps id / timestamps / deletedAt', () {
      final original = Comment(
        id: 'c1',
        eventId: 'e1',
        body: 'first',
        createdAt: DateTime(2026, 7, 11),
        deletedAt: DateTime(2026, 7, 11),
      );
      final edited = original.copyWith(body: 'second');
      expect(edited.body, 'second');
      expect(edited.id, 'c1');
      expect(edited.createdAt, original.createdAt);
      expect(edited.deletedAt, original.deletedAt);
    });
  });
}
