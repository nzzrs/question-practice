import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/widgets.dart';
import 'domain/topic_update_models.dart';

/// Shows the practice and question diff before a topic update is written.
class TopicUpdatePreviewPage extends ConsumerStatefulWidget {
  const TopicUpdatePreviewPage({required this.preview, super.key});

  final TopicUpdatePreview preview;

  @override
  ConsumerState<TopicUpdatePreviewPage> createState() =>
      _TopicUpdatePreviewPageState();
}

class _TopicUpdatePreviewPageState
    extends ConsumerState<TopicUpdatePreviewPage> {
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final preview = widget.preview;
    return AppPage(
      title: 'Update topic',
      showBack: true,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                onPressed: _applying || !preview.hasChanges ? null : _apply,
                label: _applying ? 'Applying…' : 'Apply changes',
                icon: Icons.check,
              ),
            ),
            const SizedBox(width: 8),
            M3EButton.text(
              onPressed: _applying
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
      children: [
        Text(
          preview.topicName,
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          preview.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summary(preview),
                style: theme.typography.emphasized.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                preview.hasChanges
                    ? 'Matched questions keep their answers, error cards and '
                          'statistics. Practices missing from the file are left '
                          'untouched.'
                    : 'This file matches the stored topic. Nothing will be '
                          'changed.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (preview.hasMetadataChanges) ...[
          const SizedBox(height: 22),
          const SectionTitle('Topic details'),
          AppGroup(
            children: [
              if (preview.description != null)
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Description',
                  value: preview.description!.isEmpty
                      ? 'Cleared'
                      : preview.description!,
                ),
              if (preview.updatePriority)
                _DetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Priority',
                  value: preview.priority?.toString() ?? 'Not set',
                ),
              if (preview.minimumScore != null)
                _DetailRow(
                  icon: Icons.flag_circle_outlined,
                  label: 'Minimum approval score',
                  value: '${preview.minimumScore}%',
                ),
              if (preview.targetScore != null)
                _DetailRow(
                  icon: Icons.gps_fixed,
                  label: 'Target score',
                  value: '${preview.targetScore}%',
                ),
            ],
          ),
        ],
        if (preview.newPractices.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionTitle('New practices', count: preview.newPracticeCount),
          AppGroup(
            children: [
              for (final practice in preview.newPractices)
                _PracticeRow(
                  practice: practice,
                  note:
                      'Created with ${practice.questions.length} '
                      'question${practice.questions.length == 1 ? '' : 's'}.',
                ),
            ],
          ),
        ],
        if (preview.modifiedPractices.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionTitle(
            'Updated practices',
            count: preview.modifiedPracticeCount,
          ),
          AppGroup(
            children: [
              for (final practice in preview.modifiedPractices)
                _PracticeRow(
                  practice: practice,
                  note: _practiceChanges(practice),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _summary(TopicUpdatePreview preview) {
    final parts = <String>[
      if (preview.newPracticeCount > 0)
        '${preview.newPracticeCount} new practice'
            '${preview.newPracticeCount == 1 ? '' : 's'}',
      if (preview.modifiedPracticeCount > 0)
        '${preview.modifiedPracticeCount} updated practice'
            '${preview.modifiedPracticeCount == 1 ? '' : 's'}',
      if (preview.newQuestionCount > 0)
        '${preview.newQuestionCount} new question'
            '${preview.newQuestionCount == 1 ? '' : 's'}',
      if (preview.modifiedQuestionCount > 0)
        '${preview.modifiedQuestionCount} modified question'
            '${preview.modifiedQuestionCount == 1 ? '' : 's'}',
      if (preview.deletedQuestionCount > 0)
        '${preview.deletedQuestionCount} deleted question'
            '${preview.deletedQuestionCount == 1 ? '' : 's'}',
    ];
    if (parts.isEmpty) {
      return preview.hasMetadataChanges
          ? 'Topic details changed'
          : 'No changes';
    }
    return parts.join(' · ');
  }

  String _practiceChanges(TopicPracticeUpdatePreview practice) {
    final parts = <String>[
      if (practice.newCount > 0) '${practice.newCount} new',
      if (practice.modifiedCount > 0) '${practice.modifiedCount} modified',
      if (practice.deletedCount > 0) '${practice.deletedCount} deleted',
      if (practice.descriptionChanged) 'description changed',
    ];
    if (parts.isEmpty) return 'Unchanged.';
    return '${parts.join(' · ')}.';
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(topicEditServiceProvider).apply(widget.preview);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not update the topic: $error');
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.typography.baseline.titleSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({required this.practice, required this.note});

  final TopicPracticeUpdatePreview practice;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            practice.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            note,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (practice.newQuestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final update in practice.newQuestions.take(5))
              _PromptLine(
                prompt: update.question.prompt,
                prefix: 'New',
                color: theme.colorScheme.primary,
              ),
            if (practice.newQuestions.length > 5)
              Text(
                '…and ${practice.newQuestions.length - 5} more new.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (practice.modifiedQuestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final update in practice.modifiedQuestions.take(5))
              _PromptLine(
                prompt: update.question.prompt,
                prefix: 'Modified',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            if (practice.modifiedQuestions.length > 5)
              Text(
                '…and ${practice.modifiedQuestions.length - 5} more modified.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (practice.deletedQuestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final question in practice.deletedQuestions.take(5))
              _PromptLine(
                prompt: question.prompt,
                prefix: 'Deleted',
                color: theme.colorScheme.error,
              ),
            if (practice.deletedQuestions.length > 5)
              Text(
                '…and ${practice.deletedQuestions.length - 5} more deleted.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PromptLine extends StatelessWidget {
  const _PromptLine({
    required this.prompt,
    required this.prefix,
    required this.color,
  });

  final String prompt;
  final String prefix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$prefix · $prompt',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.baseline.labelSmall.copyWith(color: color),
      ),
    );
  }
}
