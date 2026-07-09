import 'package:flutter/material.dart';

import '../util/format.dart';

/// A circular avatar showing up to two initials of [name], in the app's neutral chip
/// colour. Shared so the Contacts list/detail and the calendar's attendee faces + picker
/// all render identically (previously the list had a private widget and the detail
/// hand-rolled its own `CircleAvatar`).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.ring = false,
  });

  final String name;
  final double radius;

  /// When true, wrap the avatar in a [surface]-coloured ring (+ hairline) so that
  /// overlapping avatars in a stack punch out from each other on the flat mono canvas.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: avatar,
    );
  }
}
