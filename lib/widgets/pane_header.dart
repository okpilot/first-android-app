import 'package:flutter/material.dart';

import 'subtle_button.dart';

/// A slim in-pane header strip for the AppBar-less desktop master-detail panes — a title on
/// the left and a top-right Edit affordance, standing in for the AppBar the pane doesn't have
/// (Decision 49). Edit is the app's shared [SubtleButton] (the same 'Edit' tonal chip as
/// Complete/Archive), NOT a bare pencil — Decision 29 already settled that. On phones the real
/// AppBar carries the same button and this strip isn't used. Shared by the contact and task
/// detail views so both panes read identically.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.title,
    this.onEdit,
    this.showEdit = true,
  });

  final String title;

  /// The Edit tap. `null` disables the button (an in-flight mutation); see [showEdit] to
  /// drop the button entirely (a read-only / archived record).
  final VoidCallback? onEdit;

  /// Whether to offer Edit at all. False on an archived task — the strip keeps its title but
  /// shows no Edit (read-only history).
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Own the bottom divider too — the strip stands in for an AppBar, which owns its own
    // bottom edge. The row is horizontally inset like an AppBar; the divider spans full width.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    // maxLines:1 is load-bearing — ellipsis alone still wraps, and two lines
                    // of titleMedium fit inside the strip, so a long title would wrap rather
                    // than truncate without it.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (showEdit) SubtleButton(label: 'Edit', onPressed: onEdit),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
