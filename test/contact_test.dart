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

  test(
    'toRpcParams trims the name, sends optional fields raw, and omits id/server fields',
    () {
      const c = Contact(
        id: 'x',
        name: '  Ada  ',
        email: '   ',
        company: 'Engine Co',
      );
      final p = c.toRpcParams();

      expect(p['p_name'], 'Ada'); // trimmed client-side (belt-and-suspenders)
      expect(
        p['p_email'],
        '   ',
      ); // raw — the RPC does nullif(trim()) server-side
      expect(p['p_company'], 'Engine Co');
      expect(p['p_dob'], isNull);
      expect(p.containsKey('p_id'), isFalse); // the repo adds p_id for updates
      expect(p.containsKey('created_at'), isFalse);
    },
  );

  test('toRpcParams formats a date as yyyy-MM-dd', () {
    final c = Contact(id: 'x', name: 'Ada', dob: DateTime(1815, 12, 10));
    expect(c.toRpcParams()['p_dob'], '1815-12-10');
  });

  test('toRpcParams passes phone and remarks through raw with all six keys', () {
    final c = Contact(
      id: 'x',
      name: 'Ada',
      dob: DateTime(1815, 12, 10),
      email: 'ada@x.io',
      phone: '  +44 123  ',
      company: 'Engine Co',
      remarks: '  likes engines  ',
    );
    final p = c.toRpcParams();

    // Optional text fields go raw — untrimmed — so the RPC's nullif(trim(...))
    // owns normalization in one place.
    expect(p['p_phone'], '  +44 123  ');
    expect(p['p_remarks'], '  likes engines  ');
    expect(p['p_email'], 'ada@x.io');
    expect(p['p_company'], 'Engine Co');
    // Exactly the six RPC params — the repo adds p_id for updates.
    expect(p.keys.toSet(), {
      'p_name',
      'p_dob',
      'p_email',
      'p_phone',
      'p_company',
      'p_remarks',
    });
  });

  test(
    'toRpcParams keeps null optional fields as null (server-normalized)',
    () {
      const c = Contact(id: 'x', name: 'Ada');
      final p = c.toRpcParams();
      expect(p['p_dob'], isNull);
      expect(p['p_email'], isNull);
      expect(p['p_phone'], isNull);
      expect(p['p_company'], isNull);
      expect(p['p_remarks'], isNull);
    },
  );
}
