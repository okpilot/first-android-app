// Small presentation helpers shared across screens — kept out of widgets so the
// same logic isn't duplicated (per our path instructions: push reusable logic into
// plain Dart).

/// Up to two uppercase initials from a name: "Ada Lovelace" -> "AL", "" -> "?".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// A date as `yyyy-MM-dd`.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
