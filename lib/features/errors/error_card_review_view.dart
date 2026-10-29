import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';

class ErrorCardReviewView extends StatelessWidget {
  const ErrorCardReviewView({
    required this.card,
    required this.bias,
    required this.vaccine,
    super.key,
  });

  final ErrorCard card;
  final TextEditingController bias;
  final TextEditingController vaccine;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.question, style: theme.typography.baseline.titleSmall),
              const SizedBox(height: 10),
              _AnswerLine(
                label: 'Your answer',
                value: card.wrongAnswer,
                error: true,
              ),
              const SizedBox(height: 4),
              _AnswerLine(
                label: 'Correct answer',
                value: card.correctAnswer,
                error: false,
              ),
              if (card.reasoning.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Your reasoning',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  card.reasoning,
                  style: theme.typography.baseline.bodySmall,
                ),
              ],
              if (card.topicName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.topicName,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        M3ETextField(
          controller: bias,
          label: 'What was the flawed assumption in your reasoning?',
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        M3ETextField(
          controller: vaccine,
          label: 'What do you need to know to prevent that error?',
          minLines: 2,
          maxLines: 5,
        ),
      ],
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.error,
  });

  final String label;
  final String value;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: error
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
