import 'package:flutter/material.dart';

import '../data/comments_repository.dart';
import '../data/contacts_repository.dart';
import '../data/event_types_repository.dart';
import '../data/events_repository.dart';
import '../data/tasks_repository.dart';
import 'calendar_screen.dart';
import 'contacts_list_screen.dart';
import 'settings_screen.dart';
import 'tasks_list_screen.dart';

/// The app's navigation shell: four destinations (Contacts · Calendar · Tasks · Settings).
/// Adaptive — a bottom `NavigationBar` on narrow screens (phones) and a side `NavigationRail`
/// on wide ones (web/Linux desktop, tablets ≥600dp), honoring the standing
/// multi-platform constraint. A ≥1200dp Drawer is deferred.
///
/// Every screen lives in an `IndexedStack` so switching tabs preserves each one's
/// state (each keeps its fetched list rather than refetching).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.eventsRepository,
    required this.eventTypesRepository,
    required this.commentsRepository,
    required this.tasksRepository,
  });

  final ContactsRepository repository;
  final EventsRepository eventsRepository;
  final EventTypesRepository eventTypesRepository;
  final CommentsRepository commentsRepository;
  final TasksRepository tasksRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  static const _destinations = [
    (
      icon: Icons.contacts_outlined,
      selected: Icons.contacts,
      label: 'Contacts',
    ),
    (
      icon: Icons.calendar_today_outlined,
      selected: Icons.calendar_today,
      label: 'Calendar',
    ),
    (
      icon: Icons.check_circle_outline,
      selected: Icons.check_circle,
      label: 'Tasks',
    ),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        ContactsListScreen(repository: widget.repository),
        CalendarScreen(
          eventsRepository: widget.eventsRepository,
          contactsRepository: widget.repository,
          eventTypesRepository: widget.eventTypesRepository,
          commentsRepository: widget.commentsRepository,
        ),
        TasksListScreen(repository: widget.tasksRepository),
        SettingsScreen(eventTypesRepository: widget.eventTypesRepository),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
