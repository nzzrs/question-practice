import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../lookup/lookup_actions.dart';
import '../practice/selectable_linkified_text.dart';

/// Shared error-card study view used by session review and the Cards screen.
///
/// The question, answers, reasoning and explanations are selectable so a term
/// can be defined exactly as it can during practice.
class ErrorCardReviewView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);

    void define(String term, Rect? anchor) {
      openTermLookup(
        context,
        ref,
        term: term,
        question: card.question,
        topicName: card.topicName,
        practiceName: card.practiceName,
        sessionId: card.sessionId,
        questionId: card.questionId,
        anchor: anchor,
      );
    }

    void openUrl(String value) => openStudyUrl(context, ref, value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableLinkifiedText(
                text: card.question,
                style: theme.typography.baseline.titleSmall.copyWith(
                  height: 1.35,
                ),
                onDefine: define,
                onOpenUrl: openUrl,
              ),
              const SizedBox(height: 12),
              _AnswerBox(
                label: 'Your answer',
                value: card.wrongAnswer,
                container: theme.colorScheme.errorContainer,
                foreground: theme.colorScheme.onErrorContainer,
                onDefine: define,
                onOpenUrl: openUrl,
              ),
              const SizedBox(height: 8),
              _AnswerBox(
                label: 'Correct answer',
                value: card.correctAnswer,
                container: AppSuccess.container(context),
                foreground: AppSuccess.onContainer(context),
                onDefine: define,
                onOpenUrl: openUrl,
              ),
              if (card.reasoning.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Your reasoning',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableLinkifiedText(
                  text: card.reasoning,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    height: 1.4,
                  ),
                  onDefine: define,
                  onOpenUrl: openUrl,
                ),
              ],
              if (card.topicName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Pill(card.topicName),
              ],
            ],
          ),
        ),
        if (card.explanation.isNotEmpty ||
            card.alternativeExplanations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExplanationBox(card: card, onDefine: define, onOpenUrl: openUrl),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Select text to define a term.',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PromptField(
          prompt: 'What was the flawed assumption in your reasoning?',
          label: 'Flawed assumption',
          hint: 'The belief that led you to the wrong answer.',
          controller: bias,
        ),
        const SizedBox(height: 14),
        _PromptField(
          prompt: 'What do you need to know to prevent that error?',
          label: 'Prevention',
          hint: 'The rule or check you will use next time.',
          controller: vaccine,
        ),
      ],
    );
  }
}

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({
    required this.card,
    required this.onDefine,
    required this.onOpenUrl,
  });

  final ErrorCard card;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final hasExplanations = card.alternativeExplanations.any(
      (value) => value.trim().isNotEmpty,
    );
    return TonalBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Why this answer',
                style: theme.typography.emphasized.titleSmall,
              ),
            ],
          ),
          if (card.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableLinkifiedText(
              text: card.explanation,
              style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
              onDefine: onDefine,
              onOpenUrl: onOpenUrl,
            ),
          ],
          if (hasExplanations) ...[
            const SizedBox(height: 14),
            Text(
              'Alternative by alternative',
              style: theme.typography.baseline.labelMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < card.alternatives.length; index++)
              if (index >= card.alternativeExplanations.length ||
                  card.alternativeExplanations[index].trim().isEmpty)
                const SizedBox.shrink()
              else
                _AlternativeExplanation(
                  index: index,
                  text: card.alternatives[index],
                  explanation: card.alternativeExplanations[index],
                  isCorrect: card.correctIndexes.contains(index),
                  isWrong: card.wrongIndexes.contains(index),
                  onDefine: onDefine,
                  onOpenUrl: onOpenUrl,
                ),
          ],
        ],
      ),
    );
  }
}

class _AlternativeExplanation extends StatelessWidget {
  const _AlternativeExplanation({
    required this.index,
    required this.text,
    required this.explanation,
    required this.isCorrect,
    required this.isWrong,
    required this.onDefine,
    required this.onOpenUrl,
  });

  final int index;
  final String text;
  final String explanation;
  final bool isCorrect;
  final bool isWrong;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final tone = isCorrect
        ? theme.colorScheme.primary
        : isWrong
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final letter = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              letter,
              style: theme.typography.baseline.labelSmall.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableLinkifiedText(
                  text: text,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  onDefine: onDefine,
                  onOpenUrl: onOpenUrl,
                ),
                const SizedBox(height: 2),
                SelectableLinkifiedText(
                  text: explanation,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  onDefine: onDefine,
                  onOpenUrl: onOpenUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.prompt,
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String prompt;
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prompt,
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        const SizedBox(height: 8),
        M3ETextField(
          controller: controller,
          label: label,
          placeholder: hint,
          minLines: 2,
          maxLines: 5,
        ),
      ],
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({
    required this.label,
    required this.value,
    required this.container,
    required this.foreground,
    required this.onDefine,
    required this.onOpenUrl,
  });

  final String label;
  final String value;
  final Color container;
  final Color foreground;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: foreground.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 2),
          SelectableLinkifiedText(
            text: value,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: foreground,
              height: 1.35,
            ),
            onDefine: onDefine,
            onOpenUrl: onOpenUrl,
          ),
        ],
      ),
    );
  }
}
