import 'package:flutter/material.dart';

import 'data/contacts_repository.dart';
import 'screens/contacts_list_screen.dart';

/// Root widget. Takes the repository by injection so `main` can wire the real
/// Supabase-backed one and tests can pass a fake.
class ContactsApp extends StatelessWidget {
  const ContactsApp({super.key, required this.repository});

  final ContactsRepository repository;

  @override
  Widget build(BuildContext context) {
    // Stock Material 3 for now — a bespoke theme is its own later slice (Decision 8).
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    return MaterialApp(
      title: 'Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ContactsListScreen(repository: repository),
    );
  }
}
