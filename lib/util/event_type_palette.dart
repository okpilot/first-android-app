import 'package:flutter/painting.dart';

/// A palette entry: the [color] plus a human [name] so the swatch is programmatically
/// labelled for screen readers / keyboard users (not colour-only).
typedef PaletteSwatch = ({Color color, String name});

/// The curated event-type swatches (Decision 19): muted, mid-luminance hues chosen so a
/// dot or a block tint reads on BOTH the light and dark mono surfaces. Eight hues —
/// "slate" was dropped because a desaturated grey-blue collapses into the no-type
/// neutral in both themes. The editor's swatch grid picks from this list; any stored hex
/// still renders, so this is a preset set, not an enum.
const kEventTypePalette = <PaletteSwatch>[
  (color: Color(0xFF4E7BC9), name: 'Blue'),
  (color: Color(0xFF2FA090), name: 'Teal'),
  (color: Color(0xFF57A05F), name: 'Green'),
  (color: Color(0xFFC6952F), name: 'Amber'),
  (color: Color(0xFFCF7A3C), name: 'Orange'),
  (color: Color(0xFFCE5B5B), name: 'Red'),
  (color: Color(0xFF8A6BC4), name: 'Purple'),
  (color: Color(0xFFC165A2), name: 'Pink'),
];

/// Neutral fallback when a hex can't be parsed (mirrors `EventType`'s own guard).
const kNeutralSwatch = Color(0xFF888888);

/// Parse a `#RRGGBB` hex to an opaque [Color]. Bad input falls back to [kNeutralSwatch]
/// so a malformed colour never throws at render time.
Color colorFromHex(String hex) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (m == null) return kNeutralSwatch;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// A [Color] as a 6-digit `#rrggbb` string with **alpha stripped**. Using the raw 32-bit
/// value (`toARGB32()` / the old `.value`) would emit 8 hex digits (AARRGGBB) and be
/// rejected by the DB's `^#[0-9A-Fa-f]{6}$` CHECK on every write.
String hexFromColor(Color color) {
  int channel(double v) => (v * 255).round().clamp(0, 255);
  final rgb =
      (channel(color.r) << 16) | (channel(color.g) << 8) | channel(color.b);
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
