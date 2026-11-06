import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../../app/providers.dart';
import '../lookup/domain/lookup_service.dart';
import '../lookup/ask_sheet.dart';
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

    Future<void> ask(String selection, Rect? anchor) {
      return showAskAboutSelection(
        context,
        selection: selection,
        question: card.question,
        topicName: card.topicName,
        practiceName: card.practiceName,
        sessionId: card.sessionId,
        questionId: card.questionId,
      );
    }

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
                onAsk: ask,
              ),
              const SizedBox(height: 12),
              _AnswerBox(
                label: 'Wrong answer chosen',
                value: card.wrongAnswer,
                container: theme.colorScheme.errorContainer,
                foreground: theme.colorScheme.onErrorContainer,
                onDefine: define,
                onOpenUrl: openUrl,
                onAsk: ask,
              ),
              const SizedBox(height: 8),
              _AnswerBox(
                label: 'Right answer discarded',
                value: card.correctAnswer,
                container: AppSuccess.container(context),
                foreground: AppSuccess.onContainer(context),
                onDefine: define,
                onOpenUrl: openUrl,
                onAsk: ask,
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
                  onAsk: ask,
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
          _ExplanationBox(
            card: card,
            onDefine: define,
            onOpenUrl: openUrl,
            onAsk: ask,
          ),
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
          label: 'Flawed assumption (bias)',
          hint: 'The belief that led you to the wrong answer.',
          controller: bias,
        ),
        const SizedBox(height: 14),
        _PromptField(
          prompt: 'What do you need to know to prevent that error?',
          label: 'Vaccine (rule / protocol)',
          hint: 'The rule or check you will use next time.',
          controller: vaccine,
        ),
        const SizedBox(height: 10),
        _ReviewCheck(
          question: card.question,
          correctAnswer: card.correctAnswer,
          wrongAnswer: card.wrongAnswer,
          reasoning: card.reasoning,
          bias: bias,
          vaccine: vaccine,
        ),
      ],
    );
  }
}

class _ReviewCheck extends ConsumerStatefulWidget {
  const _ReviewCheck({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswer,
    required this.reasoning,
    required this.bias,
    required this.vaccine,
  });

  final String question;
  final String correctAnswer;
  final String wrongAnswer;
  final String reasoning;
  final TextEditingController bias;
  final TextEditingController vaccine;

  @override
  ConsumerState<_ReviewCheck> createState() => _ReviewCheckState();
}

class _ReviewCheckState extends ConsumerState<_ReviewCheck> {
  ReviewCheckResult? _result;
  bool _busy = false;

  Future<void> _check() async {
    final bias = widget.bias.text.trim();
    final vaccine = widget.vaccine.text.trim();
    if (bias.isEmpty || vaccine.isEmpty) {
      await showSnack(
        context,
        'Write both the flawed assumption and the prevention note first.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(lookupServiceProvider)
          .checkErrorNotes(
            question: widget.question,
            correctAnswer: widget.correctAnswer,
            wrongAnswer: widget.wrongAnswer,
            reasoning: widget.reasoning,
            bias: bias,
            vaccine: vaccine,
          );
      if (!mounted) return;
      setState(() => _result = result);
    } on LookupException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: M3EButton.text(
            key: const ValueKey('error-review-check'),
            onPressed: _busy ? null : _check,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fact_check_outlined, size: 18),
                const SizedBox(width: 8),
                Text(_busy ? 'Checking…' : 'Check with AI'),
              ],
            ),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 8),
          TonalBox(
            key: const ValueKey('error-review-check-result'),
            color: result.consistent
                ? AppSuccess.container(context)
                : theme.colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.consistent
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.feedback,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (result.biasSuggestion.isNotEmpty ||
              result.vaccineSuggestion.isNotEmpty) ...[
            const SizedBox(height: 10),
            TonalBox(
              key: const ValueKey('error-review-suggestions'),
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggestions',
                    style: theme.typography.baseline.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.biasSuggestion.isNotEmpty)
                    _SuggestionRow(
                      label: 'Flawed assumption',
                      text: result.biasSuggestion,
                      onUse: () => widget.bias
                        ..text = result.biasSuggestion
                        ..selection = TextSelection.collapsed(
                          offset: result.biasSuggestion.length,
                        ),
                    ),
                  if (result.vaccineSuggestion.isNotEmpty)
                    _SuggestionRow(
                      label: 'Vaccine',
                      text: result.vaccineSuggestion,
                      onUse: () => widget.vaccine
                        ..text = result.vaccineSuggestion
                        ..selection = TextSelection.collapsed(
                          offset: result.vaccineSuggestion.length,
                        ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.label,
    required this.text,
    required this.onUse,
  });

  final String label;
  final String text;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          M3EButton.text(onPressed: onUse, child: const Text('Use')),
        ],
      ),
    );
  }
}

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({
    required this.card,
    required this.onDefine,
    required this.onOpenUrl,
    required this.onAsk,
  });

  final ErrorCard card;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String, Rect?) onAsk;

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
              onAsk: onAsk,
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
                  onAsk: onAsk,
                ),
          ],
        ],
      ),
    );
  }
}

class _AlternativeExplanation extends StatefulWidget {
  const _AlternativeExplanation({
    required this.index,
    required this.text,
    required this.explanation,
    required this.isCorrect,
    required this.isWrong,
    required this.onDefine,
    required this.onOpenUrl,
    required this.onAsk,
  });

  final int index;
  final String text;
  final String explanation;
  final bool isCorrect;
  final bool isWrong;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String, Rect?) onAsk;

  @override
  State<_AlternativeExplanation> createState() =>
      _AlternativeExplanationState();
}

class _AlternativeExplanationState extends State<_AlternativeExplanation> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.isCorrect || widget.isWrong;
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final isCorrect = widget.isCorrect;
    final isWrong = widget.isWrong;
    final tone = isCorrect
        ? theme.colorScheme.primary
        : isWrong
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final letter = String.fromCharCode(65 + widget.index);
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
                  text: widget.text,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  onDefine: widget.onDefine,
                  onOpenUrl: widget.onOpenUrl,
                  onAsk: widget.onAsk,
                ),
                if (_open) ...[
                  const SizedBox(height: 2),
                  SelectableLinkifiedText(
                    text: widget.explanation,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    onDefine: widget.onDefine,
                    onOpenUrl: widget.onOpenUrl,
                    onAsk: widget.onAsk,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: _open ? 'Hide explanation' : 'Show explanation',
            child: InkResponse(
              key: ValueKey(
                'error-alternative-explanation-${widget.index}-toggle',
              ),
              onTap: () => setState(() => _open = !_open),
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
    required this.onAsk,
  });

  final String label;
  final String value;
  final Color container;
  final Color foreground;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String, Rect?) onAsk;

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
            onAsk: onAsk,
          ),
        ],
      ),
    );
  }
}
