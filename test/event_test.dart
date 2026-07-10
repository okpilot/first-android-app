import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event.fromJson', () {
    test('parses a timed event with a to-one attendee embed', () {
      // Shape verified against PostgREST: event_attendees is an array, each row's
      // `contacts` is a single object, and `start_time` comes back "HH:MM:SS".
      final e = Event.fromJson({
        'id': 'e1',
        'title': 'Kickoff',
        'event_date': '2026-07-09',
        'all_day': false,
        'start_time': '14:00:00',
        'end_time': '15:30:00',
        'location': 'Room 2',
        'notes': 'bring slides',
        'event_attendees': [
          {
            'contact_id': 'c1',
            'contacts': {'id': 'c1', 'name': 'Ada Lovelace', 'company': 'Acme'},
          },
        ],
      });

      expect(e.id, 'e1');
      expect(e.allDay, isFalse);
      expect(e.startMin, 14 * 60);
      expect(e.endMin, 15 * 60 + 30);
      expect(e.date, DateTime(2026, 7, 9));
      expect(e.attendees, hasLength(1));
      expect(e.attendees.single.name, 'Ada Lovelace');
    });

    test('all-day event has null times regardless of payload', () {
      final e = Event.fromJson({
        'id': 'e2',
        'title': 'Holiday',
        'event_date': '2026-07-13',
        'all_day': true,
        'start_time': null,
        'end_time': null,
        'event_attendees': const [],
      });
      expect(e.allDay, isTrue);
      expect(e.startMin, isNull);
      expect(e.endMin, isNull);
      expect(e.attendees, isEmpty);
    });

    test('skips a soft-deleted attendee whose contact embed is null', () {
      final e = Event.fromJson({
        'id': 'e3',
        'title': 'Sync',
        'event_date': '2026-07-09',
        'all_day': false,
        'start_time': '09:00:00',
        'end_time': '09:30:00',
        'event_attendees': [
          {'contact_id': 'gone', 'contacts': null}, // hidden by RLS
          {
            'contact_id': 'c2',
            'contacts': {'id': 'c2', 'name': 'Alan Turing', 'company': null},
          },
        ],
      });
      expect(e.attendees, hasLength(1));
      expect(e.attendees.single.id, 'c2');
    });

    test('accepts a "HH:MM" time (no seconds)', () {
      final e = Event.fromJson({
        'id': 'e4',
        'title': 'Short',
        'event_date': '2026-07-09',
        'all_day': false,
        'start_time': '08:05',
        'end_time': '08:20',
        'event_attendees': const [],
      });
      expect(e.startMin, 8 * 60 + 5);
      expect(e.endMin, 8 * 60 + 20);
    });

    test('parses the event_types to-one embed into Event.type', () {
      final e = Event.fromJson({
        'id': 'e5',
        'title': 'Interview',
        'event_date': '2026-07-10',
        'all_day': false,
        'start_time': '16:00:00',
        'end_time': '19:00:00',
        'event_types': {'id': 't1', 'name': 'Interview', 'color': '#8A6BC4'},
        'event_attendees': const [],
      });
      expect(e.type, isNotNull);
      expect(e.type!.name, 'Interview');
      expect(e.type!.colorHex, '#8A6BC4');
    });

    test('type is null for no-type, a null embed, and an absent key', () {
      // event_types comes back null both for an untyped event and for one whose type was
      // soft-deleted (RLS-hidden). An absent key must be tolerated too.
      final nullEmbed = Event.fromJson({
        'id': 'e6',
        'title': 'No type',
        'event_date': '2026-07-10',
        'all_day': true,
        'event_types': null,
        'event_attendees': const [],
      });
      final absentKey = Event.fromJson({
        'id': 'e7',
        'title': 'Absent',
        'event_date': '2026-07-10',
        'all_day': true,
        'event_attendees': const [],
      });
      expect(nullEmbed.type, isNull);
      expect(absentKey.type, isNull);
    });
  });

  group('Event.toRpcParams', () {
    test(
      'timed event serializes times as HH:MM and attendee ids as a list',
      () {
        final e = Event.draft(
          title: 'Call',
          date: DateTime(2026, 7, 9),
          allDay: false,
          startMin: 14 * 60,
          endMin: 15 * 60,
          attendees: const [
            Contact(id: 'c1', name: 'A'),
            Contact(id: 'c2', name: 'B'),
          ],
        );
        final p = e.toRpcParams();
        expect(p['p_start_time'], '14:00');
        expect(p['p_end_time'], '15:00');
        expect(p['p_all_day'], isFalse);
        expect(p['p_event_date'], '2026-07-09');
        expect(p['p_attendees'], ['c1', 'c2']);
      },
    );

    test('all-day event nulls out the times', () {
      final e = Event.draft(
        title: 'Holiday',
        date: DateTime(2026, 7, 13),
        allDay: true,
      );
      final p = e.toRpcParams();
      expect(p['p_all_day'], isTrue);
      expect(p['p_start_time'], isNull);
      expect(p['p_end_time'], isNull);
      expect(p['p_attendees'], isEmpty);
    });
  });

  group('Event.compareForDay', () {
    test('all-day sorts before timed; timed sorts by start; null-safe', () {
      Event ev({required bool allDay, int? start}) => Event(
        id: 'x',
        title: 't',
        date: DateTime(2026, 7, 9),
        allDay: allDay,
        startMin: start,
        endMin: start == null ? null : start + 30,
      );
      final list = [
        ev(allDay: false, start: 600), // 10:00
        ev(allDay: true),
        ev(allDay: false, start: 540), // 09:00
      ]..sort(Event.compareForDay);

      expect(list[0].allDay, isTrue);
      expect(list[1].startMin, 540);
      expect(list[2].startMin, 600);
    });
  });

  group('hhmm', () {
    test('formats minutes-from-midnight as HH:MM', () {
      expect(hhmm(0), '00:00');
      expect(hhmm(14 * 60), '14:00');
      expect(hhmm(9 * 60 + 5), '09:05');
      expect(hhmm(23 * 60 + 59), '23:59');
    });
  });
}
