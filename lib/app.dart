import 'package:flutter/material.dart';

import 'data/contacts_repository.dart';
import 'data/event_types_repository.dart';
import 'data/events_repository.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

/// Root widget. Takes the repositories by injection so `main` can wire the real
/// Supabase-backed ones and tests can pass fakes.
class ContactsApp extends StatelessWidget {
  const ContactsApp({
    super.key,
    required this.repository,
    required this.eventsRepository,
    required this.eventTypesRepository,
  });

  final ContactsRepository repository;
  final EventsRepository eventsRepository;
  final EventTypesRepository eventTypesRepository;

  @override
  Widget build(BuildContext context) {
    // Bespoke flat/tight/monochrome theme (Linear/Attio) — see lib/theme.dart.
    return MaterialApp(
      title: 'CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeShell(
        repository: repository,
        eventsRepository: eventsRepository,
        eventTypesRepository: eventTypesRepository,
      ),
    );
  }
}
