import 'dart:async';

import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../util/format.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/subtle_button.dart';
import 'contact_form_screen.dart';

/// Full-screen read view for one contact — the phone / narrow layout. A thin
/// `Scaffold` wrapper around [ContactDetailView]: it owns the "something changed"
/// back-signal (pops `true` on any back-out if the contact changed) and pops
/// immediately after a delete. The detail body itself lives in [ContactDetailView]
/// so the desktop master-detail pane renders exactly the same thing.
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
  bool _dirty = false; // did anything change while we were here?

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Feed the "something changed" signal back to the list on any back-out.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Defer the pop out of the PopScope callback to avoid re-entering the
        // navigator (which can trip _debugLocked) during system/app-bar back.
        final navigator = Navigator.of(context);
        unawaited(Future.microtask(() => navigator.pop(_dirty)));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: ContactDetailView(
          repository: widget.repository,
          contact: widget.contact,
          onChanged: (_) => _dirty = true,
          // The view has already shown the "deleted" snackbar; the screen just
          // closes, handing `true` back so the list refreshes.
          onDeleted: (_) => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}

/// The shared detail *body* for one contact. Rendered full-screen on phones (inside
/// [ContactDetailScreen]) and embedded in the desktop master-detail pane. It has no
/// `Scaffold`/`AppBar` and NEVER pops — it reports up via [onChanged] / [onDeleted]
/// and lets the host decide navigation. Edit and Delete live in the body (the header
/// Edit button, the bottom Delete button) so both layouts share one control set.
///
/// **Key it by contact id** when the host swaps the selected contact in place
/// (`ContactDetailView(key: ValueKey(contact.id), …)`): `_contact` is seeded once in
/// [initState], so a parent-driven `contact:` change only takes effect on remount.
class ContactDetailView extends StatefulWidget {
  const ContactDetailView({
    super.key,
    required this.repository,
    required this.contact,
    this.onChanged,
    this.onDeleted,
  });

  final ContactsRepository repository;
  final Contact contact;

  /// Called with the saved contact after an in-place edit.
  final ValueChanged<Contact>? onChanged;

  /// Called after a successful (soft) delete — the "deleted" snackbar has already
  /// been shown on the root messenger; the host handles navigation/refresh.
  final ValueChanged<Contact>? onDeleted;

  @override
  State<ContactDetailView> createState() => _ContactDetailViewState();
}

class _ContactDetailViewState extends State<ContactDetailView> {
  late Contact _contact;
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
      if (!mounted) return;
      setState(() => _contact = updated);
      widget.onChanged?.call(updated);
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
    // Root messenger so the snackbar survives the host closing the detail.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.softDelete(_contact.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${_contact.name} deleted')),
      );
      widget.onDeleted?.call(_contact);
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
    // Cap the reading measure so the fields/buttons don't stretch edge-to-edge in
    // the wide desktop pane, and LEFT-align it so it hugs the list divider instead of
    // floating in the middle (the empty space belongs on the far right). Harmless on a
    // phone (its width is already < 720).
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _body(context, theme, c),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme, Contact c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            InitialsAvatar(name: c.name, radius: 28),
            const SizedBox(width: 16),
            Expanded(child: Text(c.name, style: theme.textTheme.headlineSmall)),
            const SizedBox(width: 12),
            // A labeled subtle button, not a bare pencil icon — clearer intent and a real
            // tap target. Quiet (neutral chip) next to the filled-ink primaries.
            SubtleButton(onPressed: _deleting ? null : _edit, label: 'Edit'),
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
        _Field(icon: Icons.notes_outlined, label: 'Remarks', value: c.remarks),
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
        if (c.createdAt != null || c.updatedAt != null) ...[
          const SizedBox(height: 24),
          _MetaLine(created: c.createdAt, updated: c.updatedAt),
        ],
      ],
    );
  }
}

/// One labelled field. Empty values render a muted "Not added" (rather than hiding
/// the row) so a contact's shape is always visible — the same in both layouts.
class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = value == null || value!.isEmpty;
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
                Text(
                  empty ? 'Not added' : value!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: empty ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A muted date-only "Added / Updated" footer. Date-only via [ymd] (no time-of-day)
/// keeps clear of the project's `timestamptz`/UTC time trap.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.created, required this.updated});

  final DateTime? created;
  final DateTime? updated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (created != null) 'Added ${ymd(created!)}',
      if (updated != null) 'Updated ${ymd(updated!)}',
    ];
    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
