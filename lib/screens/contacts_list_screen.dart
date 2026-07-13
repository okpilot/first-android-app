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

  // Wide-layout search box. A controller (not a mirror String) so a programmatic
  // clear — the ✕ suffix and the after-New reset — updates the visible field too.
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      setState(() {
        // Show the just-saved contact in the pane (harmless in the narrow layout);
        // clear any active search so the new contact is actually visible in the list.
        _selectedId = saved.id;
        _search.clear();
      });
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

  bool _matches(Contact c, String q) =>
      c.name.toLowerCase().contains(q) ||
      (c.company ?? '').toLowerCase().contains(q) ||
      (c.email ?? '').toLowerCase().contains(q);

  /// The loaded state — single pane (push) on narrow, two-pane master-detail on wide.
  Widget _loaded(bool wide, List<Contact> contacts) {
    if (contacts.isEmpty) return _EmptyState(onAdd: () => _openForm());
    if (!wide) return _ContactsList(contacts: contacts, onTap: _openDetail);

    // Resolve the selection by id against the FULL list (no package:collection
    // extension — keeps analyze clean). Auto-select the first when none is chosen.
    // Searching filters only the list rows; the detail pane holds its selection.
    final matches = contacts.where((c) => c.id == _selectedId);
    final selected = matches.isEmpty ? contacts.first : matches.first;
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? contacts
        : contacts.where((c) => _matches(c, q)).toList();

    return Row(
      children: [
        SizedBox(
          width: kListPaneWidth,
          child: Column(
            children: [
              _MasterHeader(
                count: contacts.length,
                controller: _search,
                onChanged: () => setState(() {}),
                onClear: () {
                  _search.clear();
                  setState(() {});
                },
                onNew: () => _openForm(),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const _NoMatches()
                    : _ContactsList(
                        contacts: filtered,
                        onTap: (c) => setState(() => _selectedId = c.id),
                        selectedId: selected.id,
                      ),
              ),
            ],
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
  }

  @override
  Widget build(BuildContext context) {
    // Decide the layout from the content-area width (the screen sits in HomeShell's
    // Expanded beside the sidebar). Wide drops the phone AppBar + FAB in favour of the
    // list pane's own header; narrow keeps the phone chrome untouched.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kTwoPaneBreakpoint;
        return Scaffold(
          appBar: wide ? null : AppBar(title: const Text('Contacts')),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
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
                    // Keep showing the current list/panes while refreshing; only show
                    // a full-screen spinner on the very first load.
                    if (_lastData != null) {
                      return _loaded(wide, _lastData!);
                    }
                    return const Center(child: CircularProgressIndicator());
                  default:
                    if (snapshot.hasError) {
                      debugPrint('CONTACTS_LOAD_FAILED: ${snapshot.error}');
                      return _ErrorState(
                        error: snapshot.error!,
                        onRetry: _load,
                      );
                    }
                    return _loaded(wide, snapshot.data ?? const <Contact>[]);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// The wide master-pane header: title + live count + an inline "New" button over a
/// live search field. Replaces the phone's AppBar + FAB on wide screens (Decision 28,
/// Slice C).
class _MasterHeader extends StatelessWidget {
  const _MasterHeader({
    required this.count,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onNew,
  });

  final int count;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Flexible title group (ellipsises under pressure) + the New button at
              // its natural size, so a narrow list pane never overflows the Row.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Contacts',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$count',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search contacts…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClear,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in the master pane when a search matches no contacts (distinct from the
/// zero-contacts [_EmptyState] — the detail pane keeps its selection).
class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.search_off_outlined,
      title: 'No matches',
      message: 'No contacts match your search.',
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
