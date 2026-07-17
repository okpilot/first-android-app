import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/util/calendar.dart';

void main() {
  // The display date formatters (Decision 47). These replaced `ymd()`, which had leaked out of
  // the wire layer onto three screens — so these tests are the guard that an ISO date never
  // reaches the UI again.
  group('display date formats', () {
    test('displayDate is "13 Apr 1974" — d MMM yyyy, no leading zero', () {
      expect(displayDate(DateTime(1974, 4, 13)), '13 Apr 1974');
      // Single-digit day stays unpadded (a padded "09" reads as machine output).
      expect(displayDate(DateTime(2026, 7, 9)), '9 Jul 2026');
    });

    test('displayDateNoYear drops the year, keeps the shape', () {
      expect(displayDateNoYear(DateTime(2026, 7, 9)), '9 Jul');
      expect(displayDateNoYear(DateTime(2026, 12, 31)), '31 Dec');
    });

    test('longDate prefixes the weekday: "Fri, 17 Jul 2026"', () {
      expect(longDate(DateTime(2026, 7, 17)), 'Fri, 17 Jul 2026'); // a Friday
      expect(longDate(DateTime(2026, 1, 1)), 'Thu, 1 Jan 2026');
    });

    test('year and month boundaries do not roll over', () {
      expect(displayDate(DateTime(2025, 12, 31)), '31 Dec 2025');
      expect(displayDate(DateTime(2026, 1, 1)), '1 Jan 2026');
      // Monday is index 0 in weekdayShort — check the wrap-around end (Sunday).
      expect(longDate(DateTime(2026, 7, 19)), 'Sun, 19 Jul 2026');
      expect(longDate(DateTime(2026, 7, 20)), 'Mon, 20 Jul 2026');
    });

    test('longDate is displayDate plus a weekday — the two agree', () {
      final d = DateTime(2026, 7, 17);
      expect(longDate(d), endsWith(displayDate(d)));
    });
  });

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
