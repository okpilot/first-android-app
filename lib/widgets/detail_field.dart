import 'package:flutter/material.dart';

/// A labelled read-only field row for the detail screens: a leading [icon], a small [label],
/// and a value below it. Shared by `ContactDetailScreen` and `EventDetailScreen`.
///
/// Pass **either** [value] (text) **or** [child] (a custom value widget, e.g. a type dot + name) —
/// never both. Behaviors:
/// - a `null`/empty [value] with no [child] renders a muted **"Not added"** placeholder
///   (contacts show every field, empty or not);
/// - [selectable] wraps a text value in a [SelectableText] (e.g. a link the user can copy);
/// - a [child] is rendered as-is, in place of the value text.
class DetailField extends StatelessWidget {
  const DetailField({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.selectable = false,
  }) : assert(
         child == null || value == null,
         'Pass either value or child, not both.',
       );

  final IconData icon;
  final String label;

  /// The value as text. Mutually exclusive with [child]. A `null`/empty value renders "Not added".
  final String? value;

  /// A custom value widget shown in place of [value]. Mutually exclusive with [value].
  final Widget? child;

  /// When true (and a text [value] is used), the value is rendered [SelectableText] so it can be
  /// copied — used for link-like locations.
  final bool selectable;

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
                if (child != null)
                  child!
                else if (empty)
                  Text(
                    'Not added',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (selectable)
                  SelectableText(value!, style: theme.textTheme.bodyLarge)
                else
                  Text(value!, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
