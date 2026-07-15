import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/contact.dart';
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

    test('parses the task_contacts embed into People (id/name/company)', () {
      final t = Task.fromJson({
        'id': 't7',
        'title': 'Prep the pitch',
        'is_done': false,
        'task_contacts': [
          {
            'contact_id': 'c1',
            'contacts': {'id': 'c1', 'name': 'Nadia', 'company': 'Acme'},
          },
          {
            'contact_id': 'c2',
            'contacts': {'id': 'c2', 'name': 'Bo', 'company': null},
          },
        ],
      });
      expect(t.contacts.map((c) => c.id), ['c1', 'c2']);
      expect(t.contacts.first.name, 'Nadia');
      expect(t.contacts.first.company, 'Acme');
    });

    test(
      'skips a join row whose contact is null (soft-deleted, RLS-hidden)',
      () {
        final t = Task.fromJson({
          'id': 't8',
          'title': 'x',
          'task_contacts': [
            {'contact_id': 'c1', 'contacts': null},
            {
              'contact_id': 'c2',
              'contacts': {'id': 'c2', 'name': 'Bo'},
            },
          ],
        });
        expect(t.contacts.map((c) => c.id), ['c2']);
      },
    );

    test('absent task_contacts → empty People (no crash)', () {
      final t = Task.fromJson({'id': 't9', 'title': 'x'});
      expect(t.contacts, isEmpty);
    });

    test('reads importance back', () {
      final t = Task.fromJson({'id': 't10', 'title': 'x', 'importance': 3});
      expect(t.importance, 3);
    });

    test('absent importance defaults to 0 (none)', () {
      final t = Task.fromJson({'id': 't11', 'title': 'x'});
      expect(t.importance, 0);
    });
  });

  group('Task.toRpcParams', () {
    test('maps to trimmed p_title + p_notes + p_contacts (the create shape)', () {
      final p = Task.draft(title: '  Prep the demo  ').toRpcParams();
      // p_notes + p_contacts are always present (create_task(p_title, p_notes, p_contacts)); a
      // draft without notes sends null (server → NULL); with no People, an empty id list.
      expect(p, {
        'p_title': 'Prep the demo',
        'p_notes': null,
        'p_contacts': [],
        'p_importance': 0, // draft default → none
      });
      // is_done is written by update_task, never create_task — must not leak in.
      expect(p.containsKey('p_is_done'), isFalse);
      expect(p.containsKey('p_id'), isFalse);
      expect(p.containsKey('created_at'), isFalse);
      expect(p.containsKey('deleted_at'), isFalse);
    });

    test('carries importance (the create shape)', () {
      final p = Task.draft(title: 'x', importance: 2).toRpcParams();
      expect(p['p_importance'], 2);
    });

    test('carries notes verbatim (the server does the trim/nullif)', () {
      final p = Task.draft(title: 'x', notes: '  jot this  ').toRpcParams();
      expect(p['p_notes'], '  jot this  ');
    });

    test('p_contacts is the linked-People id list', () {
      final p = Task.draft(
        title: 'x',
        contacts: const [
          Contact(id: 'c1', name: 'Nadia'),
          Contact(id: 'c2', name: 'Bo'),
        ],
      ).toRpcParams();
      expect(p['p_contacts'], ['c1', 'c2']);
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

    test('defaults importance to 0 and carries it when given', () {
      expect(Task.draft(title: 'x').importance, 0);
      expect(Task.draft(title: 'x', importance: 3).importance, 3);
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

    test(
      'toggling isDone alone preserves the People (the toggle-safety invariant)',
      () {
        const t = Task(
          id: 't1',
          title: 'x',
          contacts: [Contact(id: 'c1', name: 'Nadia')],
        );
        // A null contacts arg means "keep" — this is what stops a list/detail complete-toggle
        // from wiping the links when update() re-sends the whole p_contacts set.
        expect(t.copyWith(isDone: true).contacts.map((c) => c.id), ['c1']);
      },
    );

    test('replaces People when given', () {
      const t = Task(
        id: 't1',
        title: 'x',
        contacts: [Contact(id: 'c1', name: 'Nadia')],
      );
      final edited = t.copyWith(
        contacts: const [Contact(id: 'c2', name: 'Bo')],
      );
      expect(edited.contacts.map((c) => c.id), ['c2']);
    });

    test('replaces importance when given', () {
      const t = Task(id: 't1', title: 'x', importance: 1);
      expect(t.copyWith(importance: 3).importance, 3);
    });

    test('toggling isDone alone preserves importance (toggle-safety)', () {
      const t = Task(id: 't1', title: 'x', importance: 2);
      // A null importance arg means "keep" — this is what stops a list/detail complete-toggle
      // from resetting the marker when update() re-sends the whole task.
      expect(t.copyWith(isDone: true).importance, 2);
    });
  });
}
