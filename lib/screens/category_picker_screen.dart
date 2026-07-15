import 'package:flutter/material.dart';

import '../data/task_categories_repository.dart';
import '../models/task_category.dart';
import '../widgets/empty_state.dart';
import 'event_types_screen.dart' show TypeSwatch;

/// A searchable multi-select of task categories, used to link categories to a task. Pops the
/// selected categories (both the back arrow and Done commit the current selection; a system back is
/// a cancel → null, so the caller keeps its previous selection). A near-verbatim mirror of
/// [ContactPickerScreen] — swaps the People model/repo for categories, searches by name only, and
/// uses the colour [TypeSwatch] instead of an initials avatar.
class CategoryPickerScreen extends StatefulWidget {
  const CategoryPickerScreen({
    super.key,
    required this.repository,
    required this.initialSelected,
  });

  final TaskCategoriesRepository repository;
  final List<TaskCategory> initialSelected;

  @override
  State<CategoryPickerScreen> createState() => _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends State<CategoryPickerScreen> {
  late Future<List<TaskCategory>> _future;
  // id -> category, so a selection survives filtering the list.
  late final Map<String, TaskCategory> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchAll();
    _selected = {for (final c in widget.initialSelected) c.id: c};
  }

  void _toggle(TaskCategory c) {
    setState(() {
      if (_selected.containsKey(c.id)) {
        _selected.remove(c.id);
      } else {
        _selected[c.id] = c;
      }
    });
  }

  void _done() => Navigator.of(context).pop(_selected.values.toList());

  List<TaskCategory> _filter(List<TaskCategory> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
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
        title: Text(n == 0 ? 'Add categories' : 'Categories · $n'),
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
                hintText: 'Search categories',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TaskCategory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load categories",
                    message:
                        'Check that the backend is running, then try again.',
                  );
                }
                final all = snapshot.data ?? const <TaskCategory>[];
                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.label_outline,
                    title: 'No categories yet',
                    // Categories are created in Settings → Task categories.
                    message:
                        'Add categories in Settings first, then tag tasks with them.',
                  );
                }
                final shown = _filter(all);
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matches',
                    message: 'No categories match your search.',
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
                      secondary: TypeSwatch(hex: c.colorHex),
                      title: Text(c.name),
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
