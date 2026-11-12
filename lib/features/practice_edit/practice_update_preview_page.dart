import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'domain/practice_update_models.dart';

/// Shows the question diff before any update is written.
class PracticeUpdatePreviewPage extends ConsumerStatefulWidget {
  const PracticeUpdatePreviewPage({required this.preview, super.key});

  final PracticeUpdatePreview preview;

  @override
  ConsumerState<PracticeUpdatePreviewPage> createState() =>
      _PracticeUpdatePreviewPageState();
}

class _PracticeUpdatePreviewPageState
    extends ConsumerState<PracticeUpdatePreviewPage> {
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final preview = widget.preview;
    return AppPage(
      title: 'Update practice',
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
          preview.practiceName,
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${preview.topicName} · ${preview.fileName}',
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
                '${preview.newCount} new · ${preview.modifiedCount} modified · '
                '${preview.deletedCount} deleted · '
                '${preview.unchangedCount} unchanged',
                style: theme.typography.emphasized.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                preview.hasChanges
                    ? 'Matched questions keep their answers, error cards and '
                          'statistics. Deleted questions are removed with '
                          'their linked records.'
                    : 'This file matches the stored practice. Nothing will be '
                          'changed.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (preview.newCount > 0) ...[
          const SizedBox(height: 22),
          SectionTitle('New questions', count: preview.newCount),
          AppGroup(
            children: [
              for (final update in preview.newQuestions)
                _QuestionRow(question: update.question),
            ],
          ),
        ],
        if (preview.modifiedCount > 0) ...[
          const SizedBox(height: 22),
          SectionTitle('Modified questions', count: preview.modifiedCount),
          AppGroup(
            children: [
              for (final update in preview.modifiedQuestions)
                _QuestionRow(
                  question: update.question,
                  note: 'Content changed; answers and cards stay linked.',
                ),
            ],
          ),
        ],
        if (preview.deletedCount > 0) ...[
          const SizedBox(height: 22),
          SectionTitle('Deleted questions', count: preview.deletedCount),
          AppGroup(
            children: [
              for (final question in preview.deletedQuestions)
                _DeletedQuestionRow(question: question),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(practiceEditServiceProvider).apply(widget.preview);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not update the practice: $error');
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question, this.note});

  final QuestionDraft question;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.titleSmall,
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note!,
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeletedQuestionRow extends StatelessWidget {
  const _DeletedQuestionRow({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            'Removed from the practice.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
