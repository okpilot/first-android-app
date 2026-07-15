import 'package:flutter/material.dart';

import '../util/importance.dart';

/// The task-importance marker — bold coloured `!` / `!!` / `!!!` (Decision 38). Renders nothing for
/// level 0, so callers can drop it in unconditionally. The single primitive for importance display,
/// used on the task list rows and the task detail, so the marks stay one consistent style.
///
/// The `!` glyph carries the signal; colour (amber / orange / red, per [importanceColor]) is
/// enrichment — and a [Semantics] label ("Importance High") spells the level out, since the bare
/// glyph isn't descriptive to a screen reader (design-principles: colour/'!' never rides alone).
///
/// [muted] dims the marker for a completed / archived row so active urgent tasks stay the loudest
/// thing on the list.
class ImportanceMarks extends StatelessWidget {
  const ImportanceMarks({super.key, required this.level, this.muted = false});

  final int level;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final marks = importanceMarks(level);
    if (marks.isEmpty) return const SizedBox.shrink();

    final color = importanceColor(level, Theme.of(context).brightness);
    return Semantics(
      label: 'Importance ${importanceName(level)}',
      child: Text(
        marks,
        style: TextStyle(
          color: muted ? color?.withValues(alpha: 0.5) : color,
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 1,
          // Tabular so single vs triple marks don't shift the row baseline.
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
      ),
    );
  }
}
