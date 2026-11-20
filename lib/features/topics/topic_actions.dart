import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../import/domain/import_models.dart';
import 'domain/topic_edit_service.dart';
import 'topic_editor_sheet.dart';
import 'topic_update_preview_page.dart';

/// Actions offered when a topic row is long-pressed.
enum TopicAction { edit, downloadJson, updateJson, archive, unarchive, delete }

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
    case TopicAction.downloadJson:
      await _downloadTopicJson(context, ref, summary.topic.id);
    case TopicAction.updateJson:
      await _updateTopicFromJson(context, ref, summary.topic.id);
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

Future<void> _downloadTopicJson(
  BuildContext context,
  WidgetRef ref,
  int topicId,
) async {
  try {
    await ref.read(topicEditServiceProvider).shareTopicJson(topicId);
  } on Object catch (error) {
    if (context.mounted) {
      await showSnack(context, 'Could not export the topic JSON: $error');
    }
  }
}

Future<void> _updateTopicFromJson(
  BuildContext context,
  WidgetRef ref,
  int topicId,
) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
    );
    if (files.isEmpty || !context.mounted) return;
    final file = files.single;
    final bytes = await file.readAsBytes();
    final preview = await ref
        .read(topicEditServiceProvider)
        .previewUpdateBytes(bytes, fileName: file.name, topicId: topicId);
    if (!context.mounted) return;
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => TopicUpdatePreviewPage(preview: preview),
      ),
    );
    if (applied == true && context.mounted) {
      await showSnack(
        context,
        'Topic updated: ${preview.newPracticeCount} new and '
        '${preview.modifiedPracticeCount} changed practices, '
        '${preview.newQuestionCount} new, '
        '${preview.modifiedQuestionCount} modified and '
        '${preview.deletedQuestionCount} deleted questions.',
      );
    }
  } on ImportException catch (error) {
    if (context.mounted) {
      await _showIssues(context, error.issues);
    }
  } on TopicFileException catch (error) {
    if (context.mounted) await showSnack(context, error.message);
  } on Object catch (error) {
    if (context.mounted) {
      await showSnack(context, 'Could not read that file: $error');
    }
  }
}

Future<void> _showIssues(BuildContext context, List<ImportIssue> issues) async {
  await M3EDialog.show<void>(
    context,
    dialog: M3EDialog(
      title: 'Update file rejected',
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${issues.length} problem${issues.length == 1 ? '' : 's'} '
                'found. Nothing was changed.',
              ),
              const SizedBox(height: 12),
              for (final issue in issues.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${issue.displayPath}: ${issue.message}'),
                ),
              if (issues.length > 20) Text('…and ${issues.length - 20} more.'),
            ],
          ),
        ),
      ),
      actions: [
        M3EButton.filled(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
/// Opens the [TopicEditorSheet] and returns whether the topic was saved.
/// Callers keep their existing refresh and snackbar behaviour.
Future<bool> showEditTopicDialog(
  BuildContext context,
  WidgetRef ref,
  Topic topic,
) async {
  final guard = TopicEditorSheetGuard();
  final saved = await M3EBottomSheet.show<bool>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    onDismissRequest: () async {
      if (guard.saving) return false;
      if (!guard.dirty) return true;
      if (!context.mounted) return true;
      return confirmDiscardTopicChanges(context);
    },
    builder: (context) => TopicEditorSheet(topic: topic, guard: guard),
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
            OptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit topic',
              subtitle:
                  'Change the name, description, priority, scores or deck',
              onTap: () => Navigator.of(context).pop(TopicAction.edit),
            ),
            OptionTile(
              icon: Icons.download_outlined,
              title: 'Download topic JSON',
              subtitle: 'Every practice in this topic',
              onTap: () => Navigator.of(context).pop(TopicAction.downloadJson),
            ),
            OptionTile(
              icon: Icons.upload_file_outlined,
              title: 'Update topic JSON',
              subtitle: 'Add or modify practices and questions from a file',
              onTap: () => Navigator.of(context).pop(TopicAction.updateJson),
            ),
            OptionTile(
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
            OptionTile(
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
