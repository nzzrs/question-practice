import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../../app/providers.dart';
import '../lookup/ai_summarize_button.dart';
import '../lookup/domain/lookup_service.dart';
import '../lookup/ask_sheet.dart';
import '../lookup/lookup_actions.dart';
import '../practice/selectable_linkified_text.dart';

/// Learner-edited question, options and explanations for an error card.
class ErrorCardContent {
  const ErrorCardContent({
    required this.question,
    required this.alternatives,
    this.explanation = '',
    this.alternativeExplanations = const [],
  });

  final String question;
  final List<String> alternatives;
  final String explanation;
  final List<String> alternativeExplanations;

  String alternativeExplanation(int index) {
    if (index < 0 || index >= alternativeExplanations.length) return '';
    return alternativeExplanations[index];
  }
}

/// Shared error-card study view used by session review and the Cards screen.
///
/// The question, answers, reasoning and explanations are selectable so a term
/// can be defined exactly as it can during practice.
class ErrorCardReviewView extends ConsumerStatefulWidget {
  const ErrorCardReviewView({
    required this.card,
    required this.bias,
    required this.vaccine,
    this.editedContent,
    this.checkResult,
    this.onContentChanged,
    this.onCheckResult,
    super.key,
  });

  final ErrorCard card;
  final TextEditingController bias;
  final TextEditingController vaccine;

  /// Question and options already shortened by the learner for this card.
  final ErrorCardContent? editedContent;

  /// The AI verdict for this card, kept by the page so it survives stepping
  /// away and back to the same card.
  final ReviewCheckResult? checkResult;

  /// Reports a saved edit so the page can keep showing it when the learner
  /// returns to this card.
  final ValueChanged<ErrorCardContent>? onContentChanged;

  /// Reports a new AI verdict for this card.
  final ValueChanged<ReviewCheckResult>? onCheckResult;

  @override
  ConsumerState<ErrorCardReviewView> createState() =>
      _ErrorCardReviewViewState();
}

class _ErrorCardReviewViewState extends ConsumerState<ErrorCardReviewView> {
  ErrorCardContent? _localContent;

  ErrorCardContent get _content =>
      widget.editedContent ??
      _localContent ??
      ErrorCardContent(
        question: widget.card.question,
        alternatives: widget.card.alternatives,
        explanation: widget.card.explanation,
        alternativeExplanations: widget.card.alternativeExplanations,
      );

  String get _question => _content.question;

  String _answersFor(List<int> indexes) => [
    for (final index in indexes)
      if (index >= 0 && index < _content.alternatives.length)
        _content.alternatives[index],
  ].join('; ');

  @override
  void didUpdateWidget(covariant ErrorCardReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _localContent = null;
    }
  }

  Future<void> _editContent() async {
    final updated = await showEditErrorCardContentDialog(
      context,
      card: widget.card,
      current: _content,
    );
    if (updated == null || !mounted) return;
    try {
      await ref
          .read(reviewServiceProvider)
          .saveErrorContent(
            cardId: widget.card.id,
            question: updated.question,
            alternatives: updated.alternatives,
            explanation: updated.explanation,
            alternativeExplanations: updated.alternativeExplanations,
          );
      if (!mounted) return;
      setState(() => _localContent = updated);
      widget.onContentChanged?.call(updated);
      await showSnack(context, 'Card content updated.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not update the card: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final card = widget.card;
    final alternatives = _content.alternatives;
    final correctAnswer = _answersFor(card.correctIndexes);
    final wrongAnswer = _answersFor(card.wrongIndexes);

    void define(String term, Rect? anchor) {
      openTermLookup(
        context,
        ref,
        term: term,
        question: _question,
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
        question: _question,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableLinkifiedText(
                      text: _question,
                      style: theme.typography.baseline.titleSmall.copyWith(
                        height: 1.35,
                      ),
                      onDefine: define,
                      onOpenUrl: openUrl,
                      onAsk: ask,
                    ),
                  ),
                  const SizedBox(width: 4),
                  M3EIconButton(
                    key: const ValueKey('error-card-edit-content'),
                    variant: M3EIconButtonVariant.standard,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit question and options',
                    onPressed: _editContent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AnswerBox(
                label: 'Wrong answer chosen',
                value: wrongAnswer,
                container: theme.colorScheme.errorContainer,
                foreground: theme.colorScheme.onErrorContainer,
                onDefine: define,
                onOpenUrl: openUrl,
                onAsk: ask,
              ),
              const SizedBox(height: 8),
              _AnswerBox(
                label: 'Right answer discarded',
                value: correctAnswer,
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
        if (_content.explanation.isNotEmpty ||
            _content.alternativeExplanations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExplanationBox(
            explanation: _content.explanation,
            alternatives: alternatives,
            alternativeExplanations: _content.alternativeExplanations,
            correctIndexes: card.correctIndexes,
            wrongIndexes: card.wrongIndexes,
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
          controller: widget.bias,
        ),
        const SizedBox(height: 14),
        _PromptField(
          prompt: 'What do you need to know to prevent that error?',
          label: 'Vaccine (rule / protocol)',
          hint: 'The rule or check you will use next time.',
          controller: widget.vaccine,
        ),
        const SizedBox(height: 10),
        _ReviewCheck(
          question: _question,
          correctAnswer: correctAnswer,
          wrongAnswer: wrongAnswer,
          reasoning: card.reasoning,
          bias: widget.bias,
          vaccine: widget.vaccine,
          result: widget.checkResult,
          onResult: widget.onCheckResult,
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
    this.result,
    this.onResult,
  });

  final String question;
  final String correctAnswer;
  final String wrongAnswer;
  final String reasoning;
  final TextEditingController bias;
  final TextEditingController vaccine;

  /// Verdict owned by the review page, so it belongs to this card only.
  final ReviewCheckResult? result;
  final ValueChanged<ReviewCheckResult>? onResult;

  @override
  ConsumerState<_ReviewCheck> createState() => _ReviewCheckState();
}

class _ReviewCheckState extends ConsumerState<_ReviewCheck> {
  ReviewCheckResult? _localResult;
  bool _busy = false;

  ReviewCheckResult? get _result => widget.result ?? _localResult;

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
      final report = widget.onResult;
      if (report == null) {
        setState(() => _localResult = result);
      } else {
        report(result);
      }
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
    required this.explanation,
    required this.alternatives,
    required this.alternativeExplanations,
    required this.correctIndexes,
    required this.wrongIndexes,
    required this.onDefine,
    required this.onOpenUrl,
    required this.onAsk,
  });

  final String explanation;
  final List<String> alternatives;
  final List<String> alternativeExplanations;
  final List<int> correctIndexes;
  final List<int> wrongIndexes;
  final void Function(String, Rect?) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String, Rect?) onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final hasExplanations = alternativeExplanations.any(
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
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableLinkifiedText(
              text: explanation,
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
            for (var index = 0; index < alternatives.length; index++)
              if (index >= alternativeExplanations.length ||
                  alternativeExplanations[index].trim().isEmpty)
                const SizedBox.shrink()
              else
                _AlternativeExplanation(
                  index: index,
                  text: alternatives[index],
                  explanation: alternativeExplanations[index],
                  isCorrect: correctIndexes.contains(index),
                  isWrong: wrongIndexes.contains(index),
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

/// Asks the learner to edit the question, options and explanations.
Future<ErrorCardContent?> showEditErrorCardContentDialog(
  BuildContext context, {
  required ErrorCard card,
  required ErrorCardContent current,
}) {
  return M3EDialog.show<ErrorCardContent>(
    context,
    dialog: _EditErrorCardContentDialog(card: card, current: current),
  );
}

class _EditErrorCardContentDialog extends StatefulWidget {
  const _EditErrorCardContentDialog({
    required this.card,
    required this.current,
  });

  final ErrorCard card;
  final ErrorCardContent current;

  @override
  State<_EditErrorCardContentDialog> createState() =>
      _EditErrorCardContentDialogState();
}

class _EditErrorCardContentDialogState
    extends State<_EditErrorCardContentDialog> {
  late final _question = TextEditingController(text: widget.current.question);
  late final _alternatives = [
    for (final value in widget.current.alternatives)
      TextEditingController(text: value),
  ];
  late final _explanations = [
    for (var index = 0; index < widget.current.alternatives.length; index++)
      TextEditingController(text: widget.current.alternativeExplanation(index)),
  ];
  late final _explanation = TextEditingController(
    text: widget.current.explanation,
  );
  bool _overallExpanded = false;

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    for (final controller in _alternatives) {
      controller.dispose();
    }
    for (final controller in _explanations) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _question.text.trim().isNotEmpty &&
      _alternatives.every((controller) => controller.text.trim().isNotEmpty);

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      ErrorCardContent(
        question: _question.text.trim(),
        alternatives: [
          for (final controller in _alternatives) controller.text.trim(),
        ],
        explanation: _explanation.text.trim(),
        alternativeExplanations: [
          for (final controller in _explanations) controller.text.trim(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return M3EDialog(
      title: 'Edit card content',
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fix the wording or add the reasoning behind an answer. '
                'Correct and chosen options keep their letters and links.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const _EditorSectionLabel(
                icon: Icons.help_outline,
                label: 'Question',
              ),
              const SizedBox(height: 8),
              M3ETextField(
                key: const ValueKey('edit-error-question'),
                controller: _question,
                label: 'Question',
                minLines: 2,
                maxLines: 5,
                isRequired: true,
                trailing: AiSummarizeButton(
                  key: const ValueKey('edit-error-question-summarize'),
                  controller: _question,
                  fieldLabel: 'question',
                  compact: true,
                  onChanged: () => setState(() {}),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 22),
              const _EditorSectionLabel(
                icon: Icons.checklist_outlined,
                label: 'Options',
              ),
              const SizedBox(height: 4),
              Text(
                'Open an explanation only when the answer needs one.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < _alternatives.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _OptionEditor(
                  index: index,
                  controller: _alternatives[index],
                  explanation: _explanations[index],
                  isCorrect: widget.card.correctIndexes.contains(index),
                  isWrong: widget.card.wrongIndexes.contains(index),
                  onChanged: () => setState(() {}),
                ),
              ],
              const SizedBox(height: 18),
              TonalBox(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionToggle(
                      toggleKey: const ValueKey(
                        'edit-error-explanation-toggle',
                      ),
                      icon: Icons.lightbulb_outline,
                      title: 'Overall explanation',
                      supporting: _explanation.text.trim().isEmpty
                          ? 'Optional context for the whole question'
                          : 'Explanation added',
                      expanded: _overallExpanded,
                      onTap: () =>
                          setState(() => _overallExpanded = !_overallExpanded),
                    ),
                    if (_overallExpanded) ...[
                      const SizedBox(height: 8),
                      M3ETextField(
                        key: const ValueKey('edit-error-explanation'),
                        controller: _explanation,
                        label: 'Overall explanation',
                        placeholder: 'Why the correct answer is right.',
                        minLines: 2,
                        maxLines: 5,
                        trailing: AiSummarizeButton(
                          key: const ValueKey(
                            'edit-error-explanation-summarize',
                          ),
                          controller: _explanation,
                          fieldLabel: 'overall explanation',
                          question: _question.text,
                          compact: true,
                          onChanged: () => setState(() {}),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: _valid ? _save : null,
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}

class _EditorSectionLabel extends StatelessWidget {
  const _EditorSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: theme.typography.emphasized.titleSmall),
      ],
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.toggleKey,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.supporting,
  });

  final Key toggleKey;
  final IconData icon;
  final String title;
  final String? supporting;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Semantics(
      button: true,
      label: expanded ? 'Hide $title' : 'Show $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: toggleKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.typography.baseline.titleSmall.copyWith(
                          height: 1.25,
                        ),
                      ),
                      if (supporting != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          supporting!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.baseline.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({
    required this.index,
    required this.controller,
    required this.explanation,
    required this.isCorrect,
    required this.isWrong,
    required this.onChanged,
  });

  final int index;
  final TextEditingController controller;
  final TextEditingController explanation;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onChanged;

  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  bool _expanded = false;

  String get _letter => String.fromCharCode(65 + widget.index);

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final tone = widget.isCorrect
        ? AppSuccess.onContainer(context)
        : widget.isWrong
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return TonalBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _letter,
                  style: theme.typography.baseline.labelMedium.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Option $_letter',
                      style: theme.typography.baseline.labelLarge.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.isCorrect)
                      const Pill('Correct', tone: PillTone.success),
                    if (widget.isWrong)
                      const Pill('Chosen wrong', tone: PillTone.error),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          M3ETextField(
            key: ValueKey('edit-error-option-${widget.index}'),
            controller: widget.controller,
            label: 'Option $_letter',
            minLines: 1,
            maxLines: 3,
            isRequired: true,
            trailing: AiSummarizeButton(
              key: ValueKey('edit-error-option-${widget.index}-summarize'),
              controller: widget.controller,
              fieldLabel: 'option $_letter',
              compact: true,
              onChanged: widget.onChanged,
            ),
            onChanged: (_) => widget.onChanged(),
          ),
          const SizedBox(height: 2),
          _SectionToggle(
            toggleKey: ValueKey(
              'edit-error-option-${widget.index}-explanation-toggle',
            ),
            icon: Icons.notes_outlined,
            title: 'Explanation',
            supporting: widget.explanation.text.trim().isEmpty
                ? 'Optional reason for this option'
                : 'Explanation added',
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            M3ETextField(
              key: ValueKey('edit-error-option-${widget.index}-explanation'),
              controller: widget.explanation,
              label: 'Explanation for option $_letter',
              placeholder: 'Why this option is right or wrong.',
              minLines: 2,
              maxLines: 4,
              trailing: AiSummarizeButton(
                key: ValueKey(
                  'edit-error-option-${widget.index}-explanation-summarize',
                ),
                controller: widget.explanation,
                fieldLabel: 'explanation for option $_letter',
                question: widget.controller.text,
                compact: true,
                onChanged: widget.onChanged,
              ),
              onChanged: (_) => widget.onChanged(),
            ),
          ],
        ],
      ),
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
