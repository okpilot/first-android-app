import 'package:flutter/material.dart';

import '../data/comments_repository.dart';
import '../data/contacts_repository.dart';
import '../data/event_types_repository.dart';
import '../data/events_repository.dart';
import '../data/task_categories_repository.dart';
import '../data/tasks_repository.dart';
import 'calendar_screen.dart';
import 'contacts_list_screen.dart';
import 'settings_screen.dart';
import 'tasks_list_screen.dart';

/// One navigation destination: its outline + filled icons and label. Shared by the
/// `_destinations` table, the wide-screen [_Sidebar], and its [_SidebarItem] rows so a
/// field rename is a single edit.
typedef NavDestination = ({IconData icon, IconData selected, String label});

/// The app's navigation shell: four destinations (Contacts · Calendar · Tasks · Settings).
/// Adaptive — a bottom `NavigationBar` on narrow screens (phones) and a labelled side
/// [_Sidebar] on wide ones (web/Linux desktop, tablets ≥600dp), honoring the standing
/// multi-platform constraint (Decision 28). A ≥1200dp Drawer is deferred.
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
    required this.taskCommentsRepository,
    required this.tasksRepository,
    required this.taskCategoriesRepository,
  });

  final ContactsRepository repository;
  final EventsRepository eventsRepository;
  final EventTypesRepository eventTypesRepository;
  final CommentsRepository commentsRepository;
  // A SECOND CommentsRepository, for task comments — parallel to the event `commentsRepository`
  // above (both implement CommentsRepository; each targets its own *_comments table).
  final CommentsRepository taskCommentsRepository;
  final TasksRepository tasksRepository;
  final TaskCategoriesRepository taskCategoriesRepository;

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
        TasksListScreen(
          repository: widget.tasksRepository,
          commentsRepository: widget.taskCommentsRepository,
          contactsRepository: widget.repository,
        ),
        SettingsScreen(
          eventTypesRepository: widget.eventTypesRepository,
          taskCategoriesRepository: widget.taskCategoriesRepository,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            body: Row(
              children: [
                _Sidebar(
                  destinations: _destinations,
                  selectedIndex: _index,
                  onSelect: _select,
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

/// The wide-screen side navigation: a labelled sidebar (CRM+ mark + named
/// destinations, Settings pinned to the bottom) that replaces the compact
/// `NavigationRail` at ≥600dp. Chrome only — no data, no counts. Selection styling
/// matches the shipped `navigationRailTheme` (primaryContainer chip, onSurface w600)
/// so it reads as the same app, just laid out for a mouse. (Decision 28.)
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _width = 232.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Settings (the last destination) is pinned to the bottom; the rest form the
    // primary group under the "Workspace" label.
    final lastIndex = destinations.length - 1;

    return SizedBox(
      width: _width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand: ink-filled C⁺ mark + wordmark. The glyph is a logo, not body
            // copy, so it opts out of textScaler to stay crisp under large text sizes.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'C⁺',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'CRM+',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Text(
                'WORKSPACE',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (var i = 0; i < lastIndex; i++)
              _SidebarItem(
                destination: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            _SidebarItem(
              destination: destinations[lastIndex],
              selected: lastIndex == selectedIndex,
              onTap: () => onSelect(lastIndex),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the [_Sidebar]. `InkWell` gives hover + keyboard focus + ripple; the
/// selected row takes the neutral chip fill and heavier ink, mirroring the rail's
/// selection tokens. Text is [Flexible] + ellipsis so it never overflows or clips
/// under textScaler.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.selected : destination.icon,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      destination.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
