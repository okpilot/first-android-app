import 'package:first_android_app/util/ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newEntityId', () {
    test('returns a non-empty string', () {
      expect(newEntityId(), isNotEmpty);
    });

    test('returns a distinct id on each call (no accidental reuse)', () {
      final ids = {for (var i = 0; i < 1000; i++) newEntityId()};
      expect(ids.length, 1000);
    });

    test('is a canonical 36-char v4 uuid (8-4-4-4-12, version 4)', () {
      // The client-minted id must be a real uuid so it round-trips through Postgres `uuid` columns
      // (an empty/garbage string would raise `invalid input syntax for type uuid`).
      final v4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(newEntityId(), matches(v4));
    });
  });
}
