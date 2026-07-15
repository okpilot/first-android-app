import 'package:flutter/material.dart';

import '../data/event_types_repository.dart';
import '../data/task_categories_repository.dart';
import 'event_types_screen.dart';
import 'task_categories_screen.dart';

/// The Settings destination. A grouped list of app configuration — the Event types and Task
/// categories managers; it grows a section at a time (theme, backend, account…) as slices earn
/// them, rather than shipping dead placeholder rows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.eventTypesRepository,
    required this.taskCategoriesRepository,
  });

  final EventTypesRepository eventTypesRepository;
  final TaskCategoriesRepository taskCategoriesRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text('WORKSPACE', style: theme.textTheme.labelMedium),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Event types'),
            subtitle: const Text('Categorise events with a colour'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    EventTypesScreen(repository: eventTypesRepository),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Task categories'),
            subtitle: const Text('Categorise tasks with a colour'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TaskCategoriesScreen(repository: taskCategoriesRepository),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
