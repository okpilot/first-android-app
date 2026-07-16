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
      // An entirely absent `color` key (distinct from an explicit null) also falls back.
      final noKey = EventType.fromJson({'id': 'x', 'name': 'X'});
      expect(noKey.colorHex, '#888888');
    });
  });

  group('EventType.toRpcParams', () {
    test('maps to p_-prefixed params and trims the name', () {
      // .draft mints the id, so capture the instance to assert its p_id round-trips.
      final et = EventType.draft(name: '  Focus  ', colorHex: '#4E7BC9');
      expect(et.toRpcParams(), {
        'p_id': et.id,
        'p_name': 'Focus',
        'p_color': '#4E7BC9',
      });
    });

    test('includes the client-minted p_id (issue #9), not a raw id key', () {
      final params = const EventType(
        id: 't1',
        name: 'Work',
        colorHex: '#22A06B',
      ).toRpcParams();
      expect(params['p_id'], 't1');
      expect(params.containsKey('id'), isFalse);
    });
  });
}
