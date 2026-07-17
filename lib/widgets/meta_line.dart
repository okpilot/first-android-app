import 'package:flutter/material.dart';

import '../util/calendar.dart';

/// A muted date-only "Added X · Updated Y" footer, shared by the detail screens.
/// Date-only via [displayDate] (no time-of-day) keeps clear of the project's `timestamptz`/UTC
/// time trap. Renders nothing when both dates are null.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.created, required this.updated});

  final DateTime? created;
  final DateTime? updated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (created != null) 'Added ${displayDate(created!)}',
      if (updated != null) 'Updated ${displayDate(updated!)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
