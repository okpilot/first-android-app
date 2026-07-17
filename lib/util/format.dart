// Small presentation helpers shared across screens — kept out of widgets so the
// same logic isn't duplicated (per our path instructions: push reusable logic into
// plain Dart).

/// Up to two uppercase initials from a name: "Ada Lovelace" -> "AL", "" -> "?".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// A date as `yyyy-MM-dd` — the **WIRE** format, and a day-grouping **map key**. Never display.
///
/// Two jobs, neither of them user-facing:
/// 1. **Wire** — the `p_dob` / `p_event_date` RPC params (`models/contact.dart`, `models/event.dart`).
///    Postgres `date` literals; changing this breaks writes.
/// 2. **Map keys** — day-grouping in `calendar_screen.dart`. Changing this silently breaks the
///    grouping with NO compiler error and NO test coverage (`grep ymd test/` → 0 hits).
///
/// For anything a user reads, use `util/calendar.dart`'s [displayDate] / [displayDateNoYear] /
/// [longDate]. This function leaking into the UI is exactly what put three different date formats
/// on screen (Decision 47) — an ISO date is a serializer talking, not a date.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Minutes-from-midnight as 24h `HH:MM`: 840 -> "14:00", 0 -> "00:00".
String hhmm(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
