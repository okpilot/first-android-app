import 'package:first_android_app/models/task_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskCategory.fromJson', () {
    test('parses id, name and a valid #RRGGBB colour', () {
      final c = TaskCategory.fromJson({
        'id': 'c1',
        'name': 'Follow-up',
        'color': '#4E7BC9',
      });
      expect(c.id, 'c1');
      expect(c.name, 'Follow-up');
      expect(c.colorHex, '#4E7BC9');
    });

    test('falls back to neutral grey for a malformed or missing colour', () {
      // 8-digit ARGB, shorthand, non-string, and absent all become the safe default —
      // a bad colour must never throw and blow up a whole fetchAll().
      for (final bad in <Object?>['#ff4e7bc9', '#fff', 'blue', 42, null]) {
        final c = TaskCategory.fromJson({'id': 'x', 'name': 'X', 'color': bad});
        expect(c.colorHex, '#888888', reason: 'colour was: $bad');
      }
      // An entirely absent `color` key (distinct from an explicit null) also falls back.
      final noKey = TaskCategory.fromJson({'id': 'x', 'name': 'X'});
      expect(noKey.colorHex, '#888888');
    });
  });

  group('TaskCategory.toRpcParams', () {
    test('maps to p_-prefixed params and trims the name', () {
      final params = const TaskCategory.draft(
        name: '  Errand  ',
        colorHex: '#4E7BC9',
      ).toRpcParams();
      expect(params, {'p_name': 'Errand', 'p_color': '#4E7BC9'});
    });

    test('does not include the id — the repo adds p_id for updates', () {
      final params = const TaskCategory(
        id: 'c1',
        name: 'Work',
        colorHex: '#22A06B',
      ).toRpcParams();
      expect(params.containsKey('p_id'), isFalse);
      expect(params.containsKey('id'), isFalse);
    });
  });

  group('TaskCategory.copyWith', () {
    test('overrides only the given fields and keeps the id', () {
      const original = TaskCategory(
        id: 'c1',
        name: 'Work',
        colorHex: '#4E7BC9',
      );
      final renamed = original.copyWith(name: 'Personal');
      expect(renamed.id, 'c1');
      expect(renamed.name, 'Personal');
      expect(renamed.colorHex, '#4E7BC9');

      final recolored = original.copyWith(colorHex: '#2FA090');
      expect(recolored.name, 'Work');
      expect(recolored.colorHex, '#2FA090');
    });
  });
}
