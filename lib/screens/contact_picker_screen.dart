import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../widgets/empty_state.dart';
import '../widgets/initials_avatar.dart';

/// A searchable multi-select of contacts, used to link contacts to a parent record — an event's
/// attendees or a task's People. [title] is the role noun for that context (e.g. `'attendees'`,
/// `'people'`); it drives the AppBar copy only. Pops the selected contacts (both the back arrow
/// and Done commit the current selection; a system back is a cancel → null, so the caller keeps
/// its previous selection).
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({
    super.key,
    required this.repository,
    required this.initialSelected,
    required this.title,
  });

  final ContactsRepository repository;
  final List<Contact> initialSelected;

  /// The role noun for this context (`'attendees'` / `'people'`) — AppBar copy only.
  final String title;

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  late Future<List<Contact>> _future;
  // id -> contact, so a selection survives filtering the list.
  late final Map<String, Contact> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchAll();
    _selected = {for (final c in widget.initialSelected) c.id: c};
  }

  void _toggle(Contact c) {
    setState(() {
      if (_selected.containsKey(c.id)) {
        _selected.remove(c.id);
      } else {
        _selected[c.id] = c;
      }
    });
  }

  void _done() => Navigator.of(context).pop(_selected.values.toList());

  List<Contact> _filter(List<Contact> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.company?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    final noun = widget.title;
    final nounCap = noun.isEmpty
        ? noun
        : noun[0].toUpperCase() + noun.substring(1);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _done,
        ),
        title: Text(n == 0 ? 'Add $noun' : '$nounCap · $n'),
        actions: [
          TextButton(onPressed: _done, child: const Text('Done')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Contact>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load contacts",
                    message:
                        'Check that the backend is running, then try again.',
                  );
                }
                final all = snapshot.data ?? const <Contact>[];
                if (all.isEmpty) {
                  return EmptyState(
                    icon: Icons.contacts_outlined,
                    title: 'No contacts yet',
                    // Role-aware via the noun so the event path keeps its own wording
                    // ("…link them as attendees.") and tasks read "…as people."
                    message: 'Add contacts first, then link them as $noun.',
                  );
                }
                final shown = _filter(all);
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matches',
                    message: 'No contacts match your search.',
                  );
                }
                return ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final c = shown[i];
                    final on = _selected.containsKey(c.id);
                    return CheckboxListTile(
                      value: on,
                      onChanged: (_) => _toggle(c),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: InitialsAvatar(name: c.name),
                      title: Text(c.name),
                      subtitle: (c.company == null || c.company!.isEmpty)
                          ? null
                          : Text(c.company!),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
