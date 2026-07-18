import 'dart:async';

import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../models/contact.dart';
import '../util/calendar.dart';
import '../widgets/detail_field.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/meta_line.dart';
import '../widgets/pane_header.dart';
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

  // Reaches the body view's public edit() from the AppBar action (Decision 49). Safe as a
  // GlobalKey: this narrow body view is never re-keyed (the wide pane keys by id instead).
  final _viewKey = GlobalKey<ContactDetailViewState>();

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
        appBar: AppBar(
          title: const Text('Contact'),
          // Edit lives top-right (Decision 49) — the app's shared SubtleButton ('Edit' tonal
          // chip), same as the body actions, NOT a bare pencil (Decision 29 settled that). A
          // contact is never archived, so it's always offered; edit() itself no-ops mid-delete.
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: SubtleButton(
                  label: 'Edit',
                  onPressed: () => _viewKey.currentState?.edit(),
                ),
              ),
            ),
          ],
        ),
        body: ContactDetailView(
          key: _viewKey,
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
/// and lets the host decide navigation. **Edit lives top-right** (Decision 49) — in the
/// phone AppBar (via the host's [edit] call) or, on the AppBar-less desktop pane, in this
/// view's own [showPaneHeader] strip; only Delete remains in the body.
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
    this.showPaneHeader = false,
  });

  final ContactsRepository repository;
  final Contact contact;

  /// Called with the saved contact after an in-place edit.
  final ValueChanged<Contact>? onChanged;

  /// Called after a successful (soft) delete — the "deleted" snackbar has already
  /// been shown on the root messenger; the host handles navigation/refresh.
  final ValueChanged<Contact>? onDeleted;

  /// True only in the AppBar-less desktop pane: render a slim in-pane header strip
  /// ("Contact" + a top-right Edit) so Edit reads top-right in both layouts (Decision 49).
  /// The phone wrapper leaves this false and puts Edit in its real AppBar.
  final bool showPaneHeader;

  @override
  State<ContactDetailView> createState() => ContactDetailViewState();
}

class ContactDetailViewState extends State<ContactDetailView> {
  late Contact _contact;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  /// Open the editor. Public so the phone wrapper's AppBar action can trigger it via a
  /// [GlobalKey]; the desktop pane's own header strip calls it directly. No-ops mid-delete
  /// (the AppBar sits above the body, so it can't rely on the body's disabled state).
  void edit() {
    if (_deleting) return;
    unawaited(_edit());
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
    // On the AppBar-less desktop pane, prepend a fixed header strip carrying the top-right
    // Edit; the phone leaves it out and uses its real AppBar (Decision 49). The ListView is
    // Expanded so it scrolls beneath the fixed strip.
    final content = widget.showPaneHeader
        ? Column(
            children: [
              PaneHeader(title: 'Contact', onEdit: _deleting ? null : edit),
              Expanded(child: _body(context, theme, c)),
            ],
          )
        : _body(context, theme, c);
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: content,
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
          ],
        ),
        const SizedBox(height: 24),
        DetailField(
          icon: Icons.cake_outlined,
          label: 'Date of birth',
          value: c.dob == null ? null : displayDate(c.dob!),
        ),
        DetailField(icon: Icons.email_outlined, label: 'Email', value: c.email),
        DetailField(icon: Icons.phone_outlined, label: 'Phone', value: c.phone),
        DetailField(
          icon: Icons.business_outlined,
          label: 'Company',
          value: c.company,
        ),
        DetailField(
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
        if (c.createdAt != null || c.updatedAt != null) ...[
          const SizedBox(height: 24),
          MetaLine(created: c.createdAt, updated: c.updatedAt),
        ],
      ],
    );
  }
}
