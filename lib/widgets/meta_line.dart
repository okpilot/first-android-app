import 'package:flutter/material.dart';

import '../util/calendar.dart';

/// A muted date-only "Added X · Updated Y" footer, shared by the detail screens.
/// `created`/`updated` come from `timestamptz` columns → parsed as UTC, so convert to local
/// BEFORE taking the date (matches `CommentsSection._timestamp`): date-only does NOT dodge the
/// UTC trap — an instant near midnight UTC lands on a different local *day*. Renders nothing
/// when both dates are null.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.created, required this.updated});

  final DateTime? created;
  final DateTime? updated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (created != null) 'Added ${displayDate(created!.toLocal())}',
      if (updated != null) 'Updated ${displayDate(updated!.toLocal())}',
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
