import 'dart:async';

import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../widgets/empty_state.dart';
import '../widgets/initials_avatar.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';

/// The fixed width of the master (list) pane in the two-pane layout.
const double kListPaneWidth = 320;

/// Content-area width at/above which Contacts shows a two-pane master-detail
/// (list + in-place detail) instead of the phone's push-to-detail flow.
/// = [kListPaneWidth] beside a ≥320dp detail. Measured on the LayoutBuilder
/// content area (not the whole window), so it composes with the nav sidebar.
const double kTwoPaneBreakpoint = kListPaneWidth + 320;

/// The primary screen: the list of contacts. Owns loading / empty / error states
/// and the entry points to add and open a contact. On a wide content area it becomes
/// a master-detail: the list on the left, an in-place [ContactDetailView] on the right.
class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key, required this.repository});

  final ContactsRepository repository;

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  late Future<List<Contact>> _future;
  // Last successful data — kept so a refresh/reload shows the current list instead
  // of flashing back to a full-screen spinner while the new fetch is in flight.
  List<Contact>? _lastData;

  // The contact shown in the desktop detail pane, tracked by id so a list reload
  // can't strand a stale object. Unused in the narrow (push) layout.
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Reload. Async so `RefreshIndicator` keeps spinning until the fetch resolves.
  Future<void> _load() async {
    final future = widget.repository.fetchAll();
    setState(() {
      _future = future;
    });
    try {
      _lastData = await future;
    } catch (_) {
      // The error is surfaced by the FutureBuilder's error branch.
    }
  }

  Future<void> _openForm({Contact? existing}) async {
    final saved = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(
          repository: widget.repository,
          existing: existing,
        ),
      ),
    );
    if (saved != null && mounted) {
      // Show the just-saved contact in the pane (harmless in the narrow layout).
      setState(() => _selectedId = saved.id);
      _load();
    }
  }

  Future<void> _openDetail(Contact contact) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          repository: widget.repository,
          contact: contact,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  /// The loaded state — one pane on a narrow content area, two panes on a wide one.
  Widget _loaded(List<Contact> contacts) {
    if (contacts.isEmpty) return _EmptyState(onAdd: () => _openForm());
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kTwoPaneBreakpoint) {
          return _ContactsList(contacts: contacts, onTap: _openDetail);
        }
        // Resolve the selection by id (no package:collection extension — keeps
        // flutter analyze clean). Auto-select the first contact when none is chosen.
        final matches = contacts.where((c) => c.id == _selectedId);
        final selected = matches.isEmpty ? contacts.first : matches.first;
        return Row(
          children: [
            SizedBox(
              width: kListPaneWidth,
              child: _ContactsList(
                contacts: contacts,
                onTap: (c) => setState(() => _selectedId = c.id),
                selectedId: selected.id,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              // Key by id so swapping the selected contact remounts the view
              // (its _contact is seeded once in initState).
              child: ContactDetailView(
                key: ValueKey(selected.id),
                repository: widget.repository,
                contact: selected,
                onChanged: (_) => _load(),
                onDeleted: (_) {
                  setState(() => _selectedId = null);
                  unawaited(_load());
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New contact'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: FutureBuilder<List<Contact>>(
          future: _future,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                // Keep showing the current list/panes while refreshing; only show a
                // full-screen spinner on the very first load.
                if (_lastData != null) {
                  return _loaded(_lastData!);
                }
                return const Center(child: CircularProgressIndicator());
              default:
                if (snapshot.hasError) {
                  debugPrint('CONTACTS_LOAD_FAILED: ${snapshot.error}');
                  return _ErrorState(error: snapshot.error!, onRetry: _load);
                }
                return _loaded(snapshot.data ?? const <Contact>[]);
            }
          },
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.contacts,
    required this.onTap,
    this.selectedId,
  });

  final List<Contact> contacts;
  final ValueChanged<Contact> onTap;

  /// When non-null, the list is a master pane: the matching row is highlighted and
  /// the push-affordance chevron is dropped (tapping selects, it doesn't navigate).
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final twoPane = selectedId != null;
    final scheme = Theme.of(context).colorScheme;
    // AlwaysScrollable so pull-to-refresh works even when the list is short.
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final c = contacts[index];
        final subtitle = [
          c.company,
          c.email,
        ].where((s) => s != null && s.isNotEmpty).join(' · ');
        return ListTile(
          selected: c.id == selectedId,
          selectedTileColor: scheme.primaryContainer,
          selectedColor: scheme.onSurface,
          leading: InitialsAvatar(name: c.name),
          title: Text(c.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: twoPane ? null : const Icon(Icons.chevron_right),
          onTap: () => onTap(c),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.contacts_outlined,
      title: 'No contacts yet',
      message: 'Add your first contact to get started.',
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('New contact'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
        Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Couldn't load contacts",
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Check that the backend is running, then try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
