import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/list_sort.dart';

/// Shows the shared name/recency sort dialog and returns the applied order.
///
/// The more extreme direction, decreasing, stays on the right.
Future<ListSort?> showListSortDialog(
  BuildContext context, {
  required String title,
  required ListSort initial,
  String description =
      'Increasing: A to Z or oldest first. Decreasing: Z to A or newest first.',
}) {
  var sort = initial.field;
  var direction = initial.direction;
  return M3EDialog.show<ListSort>(
    context,
    dialog: StatefulBuilder(
      builder: (context, setDialogState) {
        final theme = M3ETheme.of(context);
        return M3EDialog(
          title: title,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort by', style: theme.typography.baseline.labelMedium),
              const SizedBox(height: 8),
              M3ESegmentedButton<ListSortField>(
                segments: const [
                  M3ESegment(value: ListSortField.name, label: 'Name'),
                  M3ESegment(value: ListSortField.recency, label: 'Recency'),
                ],
                selected: {sort},
                onSelectionChanged: (values) {
                  if (values.isEmpty) return;
                  setDialogState(() => sort = values.first);
                },
              ),
              const SizedBox(height: 18),
              Text('Order', style: theme.typography.baseline.labelMedium),
              const SizedBox(height: 8),
              M3ESegmentedButton<ListSortDirection>(
                segments: const [
                  M3ESegment(
                    value: ListSortDirection.increasing,
                    label: 'Increasing',
                  ),
                  M3ESegment(
                    value: ListSortDirection.decreasing,
                    label: 'Decreasing',
                  ),
                ],
                selected: {direction},
                onSelectionChanged: (values) {
                  if (values.isEmpty) return;
                  setDialogState(() => direction = values.first);
                },
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            M3EButton.filled(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(ListSort(field: sort, direction: direction)),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}
