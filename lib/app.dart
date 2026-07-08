import 'package:flutter/material.dart';

import 'data/contacts_repository.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

/// Root widget. Takes the repository by injection so `main` can wire the real
/// Supabase-backed one and tests can pass a fake.
class ContactsApp extends StatelessWidget {
  const ContactsApp({super.key, required this.repository});

  final ContactsRepository repository;

  @override
  Widget build(BuildContext context) {
    // Bespoke flat/tight/monochrome theme (Linear/Attio) — see lib/theme.dart.
    return MaterialApp(
      title: 'CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeShell(repository: repository),
    );
  }
}
