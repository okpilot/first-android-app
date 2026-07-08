import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/models/contact.dart';

void main() {
  test('fromJson parses fields and the date', () {
    final c = Contact.fromJson({
      'id': 'abc',
      'name': 'Ada',
      'dob': '1815-12-10',
      'email': 'ada@x.io',
      'phone': null,
      'company': 'Engine Co',
      'remarks': null,
      'created_at': '2026-07-08T10:00:00Z',
      'updated_at': '2026-07-08T10:00:00Z',
    });

    expect(c.id, 'abc');
    expect(c.name, 'Ada');
    expect(c.dob, DateTime(1815, 12, 10));
    expect(c.email, 'ada@x.io');
    expect(c.phone, isNull);
    expect(c.company, 'Engine Co');
  });

  test('toWrite trims, normalizes empty strings to null, and omits server fields', () {
    const c = Contact(id: 'x', name: '  Ada  ', email: '   ', company: 'Engine Co');
    final w = c.toWrite();

    expect(w['name'], 'Ada');
    expect(w['email'], isNull);
    expect(w['company'], 'Engine Co');
    expect(w['dob'], isNull);
    expect(w.containsKey('id'), isFalse);
    expect(w.containsKey('created_at'), isFalse);
  });

  test('toWrite formats a date as yyyy-MM-dd', () {
    final c = Contact(id: 'x', name: 'Ada', dob: DateTime(1815, 12, 10));
    expect(c.toWrite()['dob'], '1815-12-10');
  });
}
