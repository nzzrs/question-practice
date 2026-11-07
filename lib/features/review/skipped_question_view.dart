import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

/// Structured presentation of a skipped or unknown question.
///
/// Shared by the session review, the Cards review flow, previews and the
/// combined error/skipped browser.
class SkippedQuestionView extends StatefulWidget {
  const SkippedQuestionView({
    required this.prompt,
    required this.alternatives,
    required this.correctIndexes,
    required this.alternativeExplanations,
    required this.explanation,
    this.reasoning = '',
    this.topicName = '',
    this.unknown = false,
    this.showStatus = true,
    super.key,
  });

  final String prompt;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final List<String> alternativeExplanations;
  final String explanation;
  final String reasoning;
  final String topicName;
  final bool unknown;
  final bool showStatus;

  @override
  State<SkippedQuestionView> createState() => _SkippedQuestionViewState();
}

class _SkippedQuestionViewState extends State<SkippedQuestionView> {
  bool _showAlternatives = false;

  List<String> get _correctAnswers => [
    for (final index in widget.correctIndexes)
      if (index >= 0 && index < widget.alternatives.length)
        widget.alternatives[index],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final others = [
      for (var index = 0; index < widget.alternatives.length; index++)
        if (!widget.correctIndexes.contains(index)) index,
    ];
    return TonalBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showStatus) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pill(
                  widget.unknown ? "I didn't know this" : 'Skipped',
                  tone: widget.unknown ? PillTone.secondary : PillTone.neutral,
                ),
                if (widget.topicName.trim().isNotEmpty) Pill(widget.topicName),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            widget.prompt,
            style: theme.typography.baseline.titleMedium.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppSuccess.container(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: AppSuccess.foreground(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Correct answer',
                        style: theme.typography.baseline.labelSmall.copyWith(
                          color: AppSuccess.onContainer(context)
                              .withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _correctAnswers.join('\n'),
                        style: theme.typography.baseline.bodyMedium.copyWith(
                          color: AppSuccess.onContainer(context),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: M3EButton.text(
                key: const ValueKey('skipped-review-other-alternatives'),
                onPressed: () =>
                    setState(() => _showAlternatives = !_showAlternatives),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAlternatives ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAlternatives
                          ? 'Hide other alternatives'
                          : 'See other alternatives',
                    ),
                  ],
                ),
              ),
            ),
            if (_showAlternatives)
              for (final index in others)
                _AlternativeRow(
                  index: index,
                  text: widget.alternatives[index],
                  explanation: index < widget.alternativeExplanations.length
                      ? widget.alternativeExplanations[index]
                      : '',
                ),
          ],
          if (widget.reasoning.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Note(label: 'Your reasoning', text: widget.reasoning),
          ],
          if (widget.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Note(label: 'Why', text: widget.explanation),
          ],
        ],
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.index,
    required this.text,
    required this.explanation,
  });

  final int index;
  final String text;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final letter = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              letter,
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    explanation,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
