import 'package:flutter/material.dart';

import '../data/event_types_repository.dart';
import '../models/event_type.dart';
import '../util/event_type_palette.dart';
import '../widgets/empty_state.dart';

/// Manage event types (Settings → Event types): the list, plus entry points to add and
/// edit. Owns loading / empty / error states, like the Contacts list.
class EventTypesScreen extends StatefulWidget {
  const EventTypesScreen({super.key, required this.repository});

  final EventTypesRepository repository;

  @override
  State<EventTypesScreen> createState() => _EventTypesScreenState();
}

class _EventTypesScreenState extends State<EventTypesScreen> {
  late Future<List<EventType>> _future;
  List<EventType>? _lastData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final future = widget.repository.fetchAll();
    setState(() {
      _future = future;
    });
    try {
      _lastData = await future;
    } catch (_) {
      // Surfaced by the FutureBuilder's error branch.
    }
  }

  /// Opens the editor; reloads on any non-null result (a save returns the [EventType],
  /// a delete returns `true`). A plain back-out returns null and skips the reload.
  Future<void> _openEditor({EventType? existing}) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => EventTypeEditorScreen(
          repository: widget.repository,
          existing: existing,
        ),
      ),
    );
    if (result != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event types')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New type'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: FutureBuilder<List<EventType>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _lastData == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && _lastData == null) {
              return _ErrorState(onRetry: _load);
            }
            final types = snapshot.data ?? _lastData ?? const <EventType>[];
            if (types.isEmpty) {
              return _EmptyState(onAdd: () => _openEditor());
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: types.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final t = types[index];
                return ListTile(
                  leading: TypeSwatch(hex: t.colorHex),
                  title: Text(t.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditor(existing: t),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A filled colour dot for a type. The one place colour enters the mono UI — kept small
/// and paired with the type name everywhere it appears.
class TypeSwatch extends StatelessWidget {
  const TypeSwatch({super.key, required this.hex, this.size = 16});

  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorFromHex(hex),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Add (when [existing] is null) or edit a type. Pops the saved [EventType] on success,
/// `true` after a delete, or nothing on cancel.
class EventTypeEditorScreen extends StatefulWidget {
  const EventTypeEditorScreen({
    super.key,
    required this.repository,
    this.existing,
  });

  final EventTypesRepository repository;
  final EventType? existing;

  @override
  State<EventTypeEditorScreen> createState() => _EventTypeEditorScreenState();
}

class _EventTypeEditorScreenState extends State<EventTypeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late Color _color;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing == null
        ? kEventTypePalette.first.color
        : colorFromHex(widget.existing!.colorHex);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final hex = hexFromColor(_color);
    final draft = _isEditing
        ? widget.existing!.copyWith(name: _name.text.trim(), colorHex: hex)
        : EventType.draft(name: _name.text.trim(), colorHex: hex);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final saved = _isEditing
          ? await widget.repository.update(draft)
          : await widget.repository.create(draft);
      if (!mounted) return;
      navigator.pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — please try again")),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete type?'),
        content: Text(
          '"${widget.existing!.name}" will be removed. Events that used it keep '
          'their schedule and show as "No type". This can\'t be undone.',
        ),
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

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.repository.softDelete(widget.existing!.id);
      if (!mounted) return;
      navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete — please try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit type' : 'New type'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Meeting',
                  prefixIcon: Icon(Icons.sell_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 28),
              Text('COLOUR', style: theme.textTheme.labelMedium),
              const SizedBox(height: 14),
              _SwatchGrid(
                selected: _color,
                onSelect: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Add type'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _confirmDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Delete type',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The curated palette as tappable circles; the selected one gets an ink ring.
class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final s in kEventTypePalette)
          Semantics(
            label: s.name,
            button: true,
            selected: s.color.toARGB32() == selected.toARGB32(),
            // InkWell (not GestureDetector) so the swatch is keyboard-focusable and
            // Enter/Space-activatable on web/Linux; the outer Semantics carries the name.
            child: InkWell(
              onTap: () => onSelect(s.color),
              customBorder: const CircleBorder(),
              excludeFromSemantics: true,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.color,
                  shape: BoxShape.circle,
                  border: s.color.toARGB32() == selected.toARGB32()
                      ? Border.all(color: scheme.onSurface, width: 2.5)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.sell_outlined,
      title: 'No event types yet',
      message: 'Create a type to colour-code your events.',
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Create your first type'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load event types",
      message: 'Check that the backend is running, then try again.',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }
}
