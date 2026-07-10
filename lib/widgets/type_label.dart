import 'package:flutter/material.dart';

import '../models/event_type.dart';
import '../util/event_type_palette.dart';

/// A filled colour dot for an event type — the single primitive for the app's only splash
/// of colour, so the dot stays one consistent size everywhere it appears.
class TypeDot extends StatelessWidget {
  const TypeDot({super.key, required this.hex, this.size = 10});

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

/// A type shown as [TypeDot] + name — the type identifier used in calendar rows, the event
/// detail, and the form. Colour never rides alone: the name always accompanies the dot
/// (Decision 19's a11y rule). A null [type] renders [placeholder] (muted, no dot) when one
/// is given, else nothing — so a no-type calendar row simply shows no type, while a
/// detail/form field can spell out "No type".
class TypeLabel extends StatelessWidget {
  const TypeLabel({
    super.key,
    required this.type,
    this.placeholder,
    this.dotSize = 10,
  });

  final EventType? type;
  final String? placeholder;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final t = type;
    if (t == null) {
      return placeholder == null
          ? const SizedBox.shrink()
          : Text(placeholder!, style: muted);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeDot(hex: t.colorHex, size: dotSize),
        const SizedBox(width: 8),
        Flexible(
          child: Text(t.name, style: muted, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
