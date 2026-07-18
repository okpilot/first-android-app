import 'package:flutter/material.dart';

/// A quiet, tonal button — clearly a button, but visually secondary to the filled-ink
/// primaries (New task / Save). It reads as an affordance without shouting, for per-item
/// actions like **Edit / Complete / Archive / Restore** (Decision 29). Decision 49 relocated
/// **Edit** to the top-right (the AppBar on phones, the [PaneHeader] strip on desktop) but
/// kept it this same 'Edit' chip — moved, not restyled, and never a bare pencil.
///
/// Why not `FilledButton.tonal`? The app's [FilledButtonThemeData] (theme.dart) pins
/// **every** `FilledButton` — tonal included — to `scheme.primary`/`onPrimary`, so a plain
/// tonal button would render identical to the loud primary. This overrides the container to
/// the neutral chip (`secondaryContainer`) with ink text to get a genuine subtle affordance.
class SubtleButton extends StatelessWidget {
  const SubtleButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSurface,
    );
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
