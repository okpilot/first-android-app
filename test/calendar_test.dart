import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/util/calendar.dart';

void main() {
  group('monthGrid', () {
    test('is always 42 days, Monday-first, Sunday-last', () {
      for (final m in [
        DateTime(2026, 7, 1), // July 2026 (1st is a Wednesday)
        DateTime(2026, 2, 1), // Feb 2026 (1st is a Sunday → padded)
        DateTime(2024, 2, 1), // leap February
        DateTime(2026, 3, 1),
      ]) {
        final grid = monthGrid(m);
        expect(grid.length, 42);
        expect(grid.first.weekday, DateTime.monday);
        expect(grid.last.weekday, DateTime.sunday);
      }
    });

    test('pads July 2026 with the right leading/trailing days', () {
      final grid = monthGrid(DateTime(2026, 7, 1));
      expect(grid.first, DateTime(2026, 6, 29)); // Monday before Jul 1 (Wed)
      expect(grid.last, DateTime(2026, 8, 9));
      expect(grid.contains(DateTime(2026, 7, 8)), isTrue);
    });

    test('includes Feb 29 in a leap year', () {
      final grid = monthGrid(DateTime(2024, 2, 1));
      expect(grid.contains(DateTime(2024, 2, 29)), isTrue);
    });
  });

  group('isSameDay', () {
    test('ignores the time component', () {
      expect(
        isSameDay(DateTime(2026, 7, 8, 9, 30), DateTime(2026, 7, 8, 23, 59)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 7, 8), DateTime(2026, 7, 9)), isFalse);
    });
  });

  group('periodLabel', () {
    test('month', () {
      expect(periodLabel(0, DateTime(2026, 12, 15)), 'December 2026');
    });
    test('3-day within one month', () {
      expect(periodLabel(1, DateTime(2026, 7, 8)), '8–10 Jul');
    });
    test('3-day across a month/year boundary', () {
      expect(periodLabel(1, DateTime(2026, 12, 31)), '31 Dec – 2 Jan');
    });
    test('day', () {
      expect(periodLabel(2, DateTime(2026, 7, 8)), 'Wed 8 Jul');
    });
    test('agenda', () {
      expect(periodLabel(3, DateTime(2026, 7, 8)), 'Upcoming');
    });
  });
}
