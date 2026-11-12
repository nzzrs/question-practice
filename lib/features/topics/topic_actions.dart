import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'topic_editor_page.dart';

/// Actions offered when a topic row is long-pressed.
enum TopicAction { edit, archive, unarchive, delete }

/// Opens the topic options sheet and runs the chosen action.
Future<void> showTopicActions(
  BuildContext context,
  WidgetRef ref,
  TopicSummary summary,
) async {
  final action = await M3EBottomSheet.show<TopicAction>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => TopicOptionsSheet(summary: summary),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case TopicAction.edit:
      await showEditTopicDialog(context, ref, summary.topic);
    case TopicAction.archive:
      await ref
          .read(topicRepositoryProvider)
          .setTopicArchived(summary.topic.id, true);
      if (context.mounted) await showSnack(context, 'Topic archived.');
    case TopicAction.unarchive:
      await ref
          .read(topicRepositoryProvider)
          .setTopicArchived(summary.topic.id, false);
      if (context.mounted) await showSnack(context, 'Topic unarchived.');
    case TopicAction.delete:
      await _deleteTopic(context, ref, summary);
  }
}

Future<void> _deleteTopic(
  BuildContext context,
  WidgetRef ref,
  TopicSummary summary,
) async {
  final confirmed = await confirmDialog(
    context,
    title: 'Delete topic?',
    message:
        'Deleting "${summary.topic.name}" removes every practice, question, '
        'session and card in it. It cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(topicRepositoryProvider).deleteTopic(summary.topic.id);
  if (context.mounted) await showSnack(context, 'Topic deleted.');
}

/// Edits a topic's name, description, priority and AnkiDroid deck.
///
/// Opens the full-page [TopicEditorPage] and returns whether the topic was
/// saved. Callers keep their existing refresh and snackbar behaviour.
Future<bool> showEditTopicDialog(
  BuildContext context,
  WidgetRef ref,
  Topic topic,
) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (context) => TopicEditorPage(topic: topic),
    ),
  );
  if (saved == true) {
    ref.invalidate(topicSummariesProvider);
    ref.invalidate(archivedTopicSummariesProvider);
    ref.invalidate(topicSummaryProvider(topic.id));
    if (context.mounted) await showSnack(context, 'Topic updated.');
  }
  return saved == true;
}

/// The options sheet shown for a long-pressed topic.
class TopicOptionsSheet extends StatelessWidget {
  const TopicOptionsSheet({required this.summary, super.key});

  final TopicSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final topic = summary.topic;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.emphasized.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.practiceCount} practices · '
                    '${topic.archived ? 'Archived' : 'Active'}',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _TopicOptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit topic',
              subtitle: 'Change the name, description, priority or deck',
              onTap: () => Navigator.of(context).pop(TopicAction.edit),
            ),
            _TopicOptionTile(
              icon: topic.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              title: topic.archived ? 'Unarchive topic' : 'Archive topic',
              subtitle: topic.archived
                  ? 'Return it to the Home list'
                  : 'Hide it from Home and keep its data',
              onTap: () => Navigator.of(context).pop(
                topic.archived ? TopicAction.unarchive : TopicAction.archive,
              ),
            ),
            _TopicOptionTile(
              icon: Icons.delete_outline,
              title: 'Delete topic',
              subtitle: 'Remove the topic and everything inside it',
              destructive: true,
              onTap: () => Navigator.of(context).pop(TopicAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicOptionTile extends StatelessWidget {
  const _TopicOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconBadge(
                icon,
                size: 42,
                tone: destructive ? PillTone.error : PillTone.neutral,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.typography.baseline.titleMedium.copyWith(
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: destructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
