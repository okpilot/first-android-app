import 'package:flutter/material.dart';

void main() => runApp(const ContactsApp());

/// A single CRM contact. Six fields, all plain strings for now — `dob` becomes a
/// real `DateTime` in a later slice, when a slice actually needs date logic (YAGNI).
class Contact {
  final String name;
  final String dob;
  final String email;
  final String phone;
  final String company;
  final String remarks;

  const Contact({
    required this.name,
    required this.dob,
    required this.email,
    required this.phone,
    required this.company,
    required this.remarks,
  });
}

/// Hard-coded sample data — Slice 1 has no backend and no storage.
const _contacts = <Contact>[
  Contact(
    name: 'Ada Lovelace',
    dob: '1815-12-10',
    email: 'ada@analyticalengine.co',
    phone: '+44 7700 900123',
    company: 'Analytical Engines Ltd',
    remarks: 'Prefers written correspondence.',
  ),
  Contact(
    name: 'Alan Turing',
    dob: '1912-06-23',
    email: 'alan@bletchley.uk',
    phone: '+44 7700 900456',
    company: 'Bletchley Park',
    remarks: 'Fast replies; morning meetings only.',
  ),
  Contact(
    name: 'Grace Hopper',
    dob: '1906-12-09',
    email: 'grace@navy.mil',
    phone: '+1 202 555 0147',
    company: 'US Navy',
    remarks: 'Coined "debugging". Very direct.',
  ),
  Contact(
    name: 'Katherine Johnson',
    dob: '1918-08-26',
    email: 'katherine@nasa.gov',
    phone: '+1 757 555 0198',
    company: 'NASA',
    remarks: 'Trusted for the hardest calculations.',
  ),
];

class ContactsApp extends StatelessWidget {
  const ContactsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ContactsScreen(),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _contacts.length,
        itemBuilder: (context, index) => ContactCard(contact: _contacts[index]),
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('DOB: ${contact.dob}'),
            Text(contact.email),
            Text(contact.phone),
            Text(contact.company),
            Text('Remarks: ${contact.remarks}'),
          ],
        ),
      ),
    );
  }
}
