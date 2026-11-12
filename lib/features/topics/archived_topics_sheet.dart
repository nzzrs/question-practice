import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/widgets.dart';

/// Lists archived topics so they can be restored, edited or deleted.
class ArchivedTopicsSheet extends ConsumerWidget {
  const ArchivedTopicsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final archived = ref.watch(archivedTopicSummariesProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archived topics',
              style: theme.typography.emphasized.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Archived topics keep their practices, sessions and cards. '
              'Tap one to unarchive, edit or delete it.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            archived.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: M3ELoadingIndicator()),
              ),
              error: (error, stackTrace) => Text('$error'),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No archived topics',
                          style: theme.typography.emphasized.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Long-press a topic on Home and choose '
                          '"Archive topic" to move it here.',
                          textAlign: TextAlign.center,
                          style: theme.typography.baseline.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return AppGroup(
                  children: [
                    for (final summary in items)
                      AppGroupRow(
                        title: summary.topic.name,
                        subtitle:
                            '${summary.practiceCount} practices · '
                            '${summary.relevantQuestionCount} questions',
                        leading: const IconBadge(Icons.archive_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(summary),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
