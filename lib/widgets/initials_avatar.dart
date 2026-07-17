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
    this.onChipFill = false,
  });

  final String name;
  final double radius;

  /// When true, wrap the avatar in a [surface]-coloured ring (+ hairline) so that
  /// overlapping avatars in a stack punch out from each other on the flat mono canvas.
  final bool ring;

  /// Set when this avatar sits on a **chip fill**. The disc normally paints in
  /// `secondaryContainer` — the very token a chip fills with (the mono scheme aliases all
  /// three container roles onto one colour), so on a chip the disc would dissolve and leave
  /// bare initials. Flips the disc to `surface` so it reads. (No hairline: `CircleAvatar` has
  /// no border, and wrapping one costs the same ~5px [ring] does — see below.)
  ///
  /// Do this rather than [ring] inside a Chip: a Chip pins its avatar to a tight
  /// `contentSize` box, and the ring's 2px padding + border eats ~5px **out of the disc**
  /// (a Chip won't grow for it) — halving an already-small avatar. Colour costs nothing.
  final bool onChipFill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: onChipFill ? scheme.surface : scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      // [radius] sizes the disc AND the type — but a parent can impose its own box and
      // ignore [radius] entirely (a Material Chip pins its avatar to a tight `contentSize`
      // box; `ring: true` then shrinks it further). When that happens the type stays sized
      // for the radius it was never given, and CircleAvatar does NOT clip — so wide
      // initials ("WW") paint out over the disc. scaleDown re-couples type to the ACTUAL
      // disc: a no-op when it already fits (every un-constrained caller renders
      // identically), a clamp only when a parent shrank us. (Decision 47.)
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: radius * 0.7,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: scheme.onSecondaryContainer,
          ),
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
