import 'package:first_android_app/models/event_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventType.fromJson', () {
    test('parses id, name and a valid #RRGGBB colour', () {
      final t = EventType.fromJson({
        'id': 't1',
        'name': 'Meeting',
        'color': '#4E7BC9',
      });
      expect(t.id, 't1');
      expect(t.name, 'Meeting');
      expect(t.colorHex, '#4E7BC9');
    });

    test('falls back to neutral grey for a malformed or missing colour', () {
      // 8-digit ARGB, shorthand, non-string, and absent all become the safe default —
      // a bad colour must never throw and blow up a whole fetchAll().
      for (final bad in <Object?>['#ff4e7bc9', '#fff', 'blue', 42, null]) {
        final t = EventType.fromJson({'id': 'x', 'name': 'X', 'color': bad});
        expect(t.colorHex, '#888888', reason: 'colour was: $bad');
      }
    });
  });
}
