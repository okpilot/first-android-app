import '../util/format.dart';
import '../util/ids.dart';
import 'contact.dart';
import 'event_type.dart';

/// A calendar event — mirrors the `public.events` table plus its attendees (the
/// `event_attendees` → `contacts` embed). Pure Dart (no Flutter import, like [Contact])
/// so it unit-tests without a widget tree.
///
/// Times are minutes-from-midnight ([startMin]/[endMin], null iff [allDay]) rather than
/// a Flutter `TimeOfDay`: it keeps the model widget-free and matches the timeline's own
/// pixel math (`startMin / 60 * rowHeight`). Screens bridge to `TimeOfDay` only at the
/// picker boundary. Single-day events only — see the backend migration.
class Event {
  final String id;
  final String title;

  /// Date-only (local midnight); the event's calendar day.
  final DateTime date;
  final bool allDay;

  /// Minutes from midnight. Both null when [allDay]; both set otherwise.
  final int? startMin;
  final int? endMin;

  final String? location;
  final String? notes;

  /// The event's type, or null for "No type" — also null when the assigned type has
  /// been soft-deleted (RLS hides it, so the `event_types` embed comes back null).
  final EventType? type;

  /// The assigned contacts. Only id/name/company are populated from the embed.
  final List<Contact> attendees;

  const Event({
    required this.id,
    required this.title,
    required this.date,
    required this.allDay,
    this.startMin,
    this.endMin,
    this.location,
    this.notes,
    this.type,
    this.attendees = const [],
  });

  /// A not-yet-persisted event. Mints a client-side id up front (issue #9) so `create_event` is
  /// idempotent on it; pass [id] to reuse one across a retry (the form holds a stable id).
  factory Event.draft({
    String? id,
    required String title,
    required DateTime date,
    required bool allDay,
    int? startMin,
    int? endMin,
    String? location,
    String? notes,
    EventType? type,
    List<Contact> attendees = const [],
  }) => Event(
    id: id ?? newEntityId(),
    title: title,
    date: date,
    allDay: allDay,
    startMin: startMin,
    endMin: endMin,
    location: location,
    notes: notes,
    type: type,
    attendees: attendees,
  );

  factory Event.fromJson(Map<String, dynamic> json) {
    // event_attendees is a to-many array; each row's `contacts` is a to-ONE object (or
    // null when that contact was soft-deleted and hidden by RLS — skip those).
    final attendees = <Contact>[];
    for (final row in (json['event_attendees'] as List? ?? const [])) {
      final c = (row as Map<String, dynamic>)['contacts'];
      if (c is Map<String, dynamic>) attendees.add(Contact.fromJson(c));
    }
    // event_types is a to-ONE embed via a nullable FK. It's null when the event has no
    // type AND when the assigned type was soft-deleted (RLS hides it) — treat both, and
    // an absent key, as "No type".
    final typeJson = json['event_types'];
    final type = typeJson is Map<String, dynamic>
        ? EventType.fromJson(typeJson)
        : null;
    final allDay = (json['all_day'] as bool?) ?? false;
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(
        json['event_date'] as String,
      ), // 'yyyy-MM-dd' → local midnight
      allDay: allDay,
      startMin: allDay ? null : _minutesOf(json['start_time']),
      endMin: allDay ? null : _minutesOf(json['end_time']),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      type: type,
      attendees: attendees,
    );
  }

  /// Named params for the `create_event` / `update_event` RPCs. Times as `"HH:MM"`
  /// strings; the server trims text and maps empty → NULL. (`update` adds `p_id`.)
  ///
  /// `p_type_id` is null for "No type". Note a soft-deleted type reads back as [type] ==
  /// null (RLS hides the embed), so re-saving such an event nulls its `type_id` — intended
  /// (the type is gone; the event already shows "No type").
  Map<String, dynamic> toRpcParams() => {
    'p_id': id,
    'p_title': title.trim(),
    'p_event_date': ymd(date),
    'p_all_day': allDay,
    'p_start_time': allDay || startMin == null ? null : hhmm(startMin!),
    'p_end_time': allDay || endMin == null ? null : hhmm(endMin!),
    'p_location': location,
    'p_notes': notes,
    'p_attendees': [for (final c in attendees) c.id],
    'p_type_id': type?.id,
  };

  /// Order within a single day: all-day events first, then by start time. Null-safe.
  static int compareForDay(Event a, Event b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return (a.startMin ?? 0).compareTo(b.startMin ?? 0);
  }

  static int? _minutesOf(Object? v) {
    if (v is! String || v.isEmpty) return null;
    final parts = v.split(':'); // accepts "HH:MM" and "HH:MM:SS"
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
