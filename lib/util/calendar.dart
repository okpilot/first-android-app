// Pure calendar/date logic — no Flutter imports, so it unit-tests without a widget
// tree. All date arithmetic goes through the DateTime(y, m, d) constructor, which
// normalizes overflow/underflow and is DST-safe (never add Duration(days:), which
// drifts across daylight-saving boundaries).

// No `intl` dependency in this project — hardcoded English names (Monday-first for
// the weekday arrays, matching the Monday-start grid).
const List<String> monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const List<String> weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// True if [a] and [b] fall on the same calendar day (time-of-day ignored).
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Midnight of [d] — strips the time component.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The 42 days (6 rows × 7) of a Monday-start month grid for [month], including the
/// leading/trailing days that pad the first and last weeks. Fixed 6 rows keeps the
/// grid a stable height regardless of how the month falls.
List<DateTime> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final leading = first.weekday - DateTime.monday; // Mon->0 … Sun->6
  return List.generate(
    42,
    (i) => DateTime(first.year, first.month, first.day - leading + i),
  );
}

/// The [count] consecutive days starting at [start] (for the Day / 3-day timelines).
List<DateTime> daySpan(DateTime start, int count) => List.generate(
  count,
  (i) => DateTime(start.year, start.month, start.day + i),
);

/// e.g. "Wed 8 Jul" — used for the selected-day header.
String dayLabel(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';

// ---------------------------------------------------------------------------
// Display date formats — the ONE set of user-facing date renderers (Decision 47).
//
// These live here, beside [dayLabel]/[periodLabel], because this file already owns the
// month/weekday name arrays AND the date-label formatters — so every date label the user
// can read is in one place. (Putting them in `format.dart` would orphan calendar imports
// and force a format→calendar edge that every model would inherit.)
//
// NEVER render `ymd()` to the user: it is the WIRE serializer + a day-grouping map key
// (see its doc-comment in `format.dart`). That leak is what these replace.
// ---------------------------------------------------------------------------

/// e.g. "13 Apr 1974" — the default user-facing date (detail rows, Added/Updated meta).
/// Day-month-year with a short month name: unambiguous for any reader, unlike 04/13.
String displayDate(DateTime d) =>
    '${d.day} ${monthShort[d.month - 1]} ${d.year}';

/// e.g. "9 Jul" — [displayDate] without the year, for compact rows where the year is
/// implied (comment timestamps). Deliberately year-less: matches the prior behaviour and
/// [dayLabel]'s precedent.
String displayDateNoYear(DateTime d) => '${d.day} ${monthShort[d.month - 1]}';

/// e.g. "Fri, 17 Jul 2026" — [displayDate] with the weekday, for a single prominent date
/// (an event's When). The comma separates the weekday from the date proper; [dayLabel] is
/// the tighter, year-less twin used in space-constrained calendar chrome.
String longDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]} ${d.year}';

/// The AppBar period label for each view tab:
/// 0 Month → "July 2026" · 1 3-day → "8–10 Jul" (or "30 Jun – 2 Jul" across months)
/// · 2 Day → "Wed 8 Jul" · 3 Agenda → "Upcoming".
String periodLabel(int tabIndex, DateTime focused) {
  switch (tabIndex) {
    case 0:
      return '${monthNames[focused.month - 1]} ${focused.year}';
    case 1:
      final end = DateTime(focused.year, focused.month, focused.day + 2);
      if (focused.month == end.month) {
        return '${focused.day}–${end.day} ${monthShort[focused.month - 1]}';
      }
      return '${focused.day} ${monthShort[focused.month - 1]} – '
          '${end.day} ${monthShort[end.month - 1]}';
    case 2:
      return dayLabel(focused);
    default:
      return 'Upcoming';
  }
}
