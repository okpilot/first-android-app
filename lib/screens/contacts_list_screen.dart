import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';

/// The primary screen: the list of contacts. Owns loading / empty / error states
/// and the entry points to add and open a contact.
class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key, required this.repository});

  final ContactsRepository repository;

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  late Future<List<Contact>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.repository.fetchAll();
    });
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
    if (saved != null) _load();
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
    if (changed == true) _load();
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
        onRefresh: () async => _load(),
        child: FutureBuilder<List<Contact>>(
          future: _future,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return const Center(child: CircularProgressIndicator());
              default:
                if (snapshot.hasError) {
                  debugPrint('CONTACTS_LOAD_FAILED: ${snapshot.error}');
                  return _ErrorState(error: snapshot.error!, onRetry: _load);
                }
                final contacts = snapshot.data ?? const <Contact>[];
                if (contacts.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm());
                }
                return _ContactsList(
                  contacts: contacts,
                  onTap: _openDetail,
                );
            }
          },
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({required this.contacts, required this.onTap});

  final List<Contact> contacts;
  final ValueChanged<Contact> onTap;

  @override
  Widget build(BuildContext context) {
    // AlwaysScrollable so pull-to-refresh works even when the list is short.
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final c = contacts[index];
        final subtitle = [c.company, c.email]
            .where((s) => s != null && s.isNotEmpty)
            .join(' · ');
        return ListTile(
          leading: _InitialsAvatar(name: c.name),
          title: Text(c.name),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(c),
        );
      },
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      child: Text(_initials),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrollable so pull-to-refresh still works on the empty screen.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Icon(Icons.contacts_outlined,
            size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Center(
          child: Text('No contacts yet', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Add your first contact to get started.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('New contact'),
          ),
        ),
      ],
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
        Icon(Icons.cloud_off_outlined,
            size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Center(
          child: Text("Couldn't load contacts",
              style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Check that the backend is running, then try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
