import 'package:flutter/painting.dart';
import 'dart:ui' show Brightness;

/// Task importance — a fixed 0..3 priority scale (Decision 38). 0 = none, 1/2/3 = `!`/`!!`/`!!!`.
///
/// Unlike event types (Decision 19, user-owned colour-as-data), this is a FIXED semantic scale:
/// each level maps to one hue the user can't change. The `!` marks carry the signal; colour is
/// enrichment, so the marker is never colour-alone (design-principles a11y — see [ImportanceMarks],
/// which also attaches a screen-reader label). The hues are the app's amber / orange / red family
/// (event_type_palette) but TUNED per theme for legibility as text: raw amber (`#C6952F`) fails
/// contrast on the light surface, so light darkens each hue and dark lightens it.

/// The exclamation marks for [level] — `''` outside 1..3, else `level` copies of `!`. Bounding
/// both ends keeps this in step with [importanceColor] (null) and [importanceName] ('None') so the
/// three helpers never disagree on an out-of-range value (unreachable today — the DB check + smallint
/// + `?? 0` parse bound it to 0..3 — but defensive branches that agree can't drift).
String importanceMarks(int level) =>
    (level < 1 || level > 3) ? '' : '!' * level;

/// A human name for [level] — for the form picker's "None" option and the marker's a11y label.
String importanceName(int level) => switch (level) {
  1 => 'Low',
  2 => 'Medium',
  3 => 'High',
  _ => 'None',
};

// Per-theme, per-level marker colours. Tuned from the light+dark prototype QA.
const _light = <Color>[
  Color(0xFF8A6A12), // 1 — amber, darkened for text on the light surface
  Color(0xFFB4551C), // 2 — orange
  Color(0xFFBA1A1A), // 3 — red (== theme error, light)
];
const _dark = <Color>[
  Color(0xFFE0B15A), // 1 — amber, lightened for the dark surface
  Color(0xFFE8975A), // 2 — orange
  Color(0xFFFFB4AB), // 3 — red (== theme error, dark)
];

/// The marker colour for [level] in [brightness] — `null` for level 0 (no marker) or out of range.
Color? importanceColor(int level, Brightness brightness) {
  if (level < 1 || level > 3) return null;
  return (brightness == Brightness.dark ? _dark : _light)[level - 1];
}
