import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../widgets/empty_state.dart';
import '../widgets/initials_avatar.dart';

/// A searchable multi-select of contacts, used to assign attendees to an event. Pops the
/// selected contacts (both the back arrow and Done commit the current selection; a system
/// back is a cancel → null, so the caller keeps its previous selection).
class AttendeePickerScreen extends StatefulWidget {
  const AttendeePickerScreen({
    super.key,
    required this.repository,
    required this.initialSelected,
  });

  final ContactsRepository repository;
  final List<Contact> initialSelected;

  @override
  State<AttendeePickerScreen> createState() => _AttendeePickerScreenState();
}

class _AttendeePickerScreenState extends State<AttendeePickerScreen> {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _done,
        ),
        title: Text(n == 0 ? 'Add attendees' : 'Attendees · $n'),
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
                  return const EmptyState(
                    icon: Icons.contacts_outlined,
                    title: 'No contacts yet',
                    message: 'Add contacts first, then invite them to events.',
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
