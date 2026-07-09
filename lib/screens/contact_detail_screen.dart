import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../util/format.dart';
import '../widgets/initials_avatar.dart';
import 'contact_form_screen.dart';

/// Read view for one contact, with edit and (soft) delete. Pops `true` when the
/// contact changed so the list refreshes.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.repository,
    required this.contact,
  });

  final ContactsRepository repository;
  final Contact contact;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late Contact _contact;
  bool _dirty = false; // did anything change while we were here?
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(
          repository: widget.repository,
          existing: _contact,
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _contact = updated;
        _dirty = true;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('${_contact.name} will be removed from your contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.repository.softDelete(_contact.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${_contact.name} deleted')),
      );
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete — please try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _contact;
    return PopScope(
      // Feed the "something changed" signal back to the list on any back-out.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Defer the pop out of the PopScope callback to avoid re-entering the
        // navigator (which can trip _debugLocked) during system/app-bar back.
        final navigator = Navigator.of(context);
        Future.microtask(() => navigator.pop(_dirty));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contact'),
          actions: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _deleting ? null : _edit,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                InitialsAvatar(name: c.name, radius: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(c.name, style: theme.textTheme.headlineSmall),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Field(
              icon: Icons.cake_outlined,
              label: 'Date of birth',
              value: c.dob == null ? null : ymd(c.dob!),
            ),
            _Field(icon: Icons.email_outlined, label: 'Email', value: c.email),
            _Field(icon: Icons.phone_outlined, label: 'Phone', value: c.phone),
            _Field(
              icon: Icons.business_outlined,
              label: 'Company',
              value: c.company,
            ),
            _Field(
              icon: Icons.notes_outlined,
              label: 'Remarks',
              value: c.remarks,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _deleting ? null : _confirmDelete,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Delete contact',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled field. Renders nothing when the value is empty (no blank rows).
class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value!, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
