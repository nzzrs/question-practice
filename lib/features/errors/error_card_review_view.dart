import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_page.dart';
import '../lookup/ask_sheet.dart';
import '../lookup/lookup_actions.dart';
import '../practice/selectable_linkified_text.dart';
import 'error_card_content.dart';
import 'error_card_content_editor_page.dart';

export 'error_card_content.dart';

/// Shared error-card study view used by session review and the Cards screen.
///
/// The question, answers, reasoning and explanations are selectable so a term
/// can be defined exactly as it can during practice. The learner turns the
/// error into atomic Basic cards instead of writing bias and vaccine notes.
class ErrorCardReviewView extends ConsumerStatefulWidget {
  const ErrorCardReviewView({
    required this.card,
    this.editedContent,
    this.onContentChanged,
    this.onCardsAdded,
    super.key,
  });

  final ErrorCard card;

  /// Question and options already shortened by the learner for this card.
  final ErrorCardContent? editedContent;

  /// Reports a saved edit so the page can keep showing it when the learner
  /// returns to this card.
  final ValueChanged<ErrorCardContent>? onContentChanged;

  /// Reports how many atomic cards were added so the page can advance.
  final ValueChanged<int>? onCardsAdded;

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
    final updated = await openErrorCardContentEditor(
      context,
      card: widget.card,
      current: _content,
    );
    if (updated == null || !mounted) return;
    setState(() => _localContent = updated);
    widget.onContentChanged?.call(updated);
    await showSnack(context, 'Card content updated.');
  }

  Future<void> _createCards() async {
    final card = widget.card;
    final added = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: card.sessionId,
        questionId: card.questionId,
        questionContext: _question,
        topicName: card.topicName,
        subtopic: card.subtopic,
        error: CardCreatorErrorSource(
          card: card,
          question: _question,
          wrongAnswer: _answersFor(card.wrongIndexes),
          correctAnswer: _answersFor(card.correctIndexes),
          reasoning: card.reasoning,
          explanation: _content.explanation,
        ),
      ),
    );
    if (!mounted || added == 0) return;
    final report = widget.onCardsAdded;
    if (report != null) {
      report(added);
    } else {
      await showSnack(context, '$added card${added == 1 ? '' : 's'} created.');
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
        subtopic: card.subtopic,
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
              if (card.topicName.isNotEmpty || card.subtopic.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (card.topicName.isNotEmpty) Pill(card.topicName),
                    if (card.subtopic.isNotEmpty)
                      Pill(card.subtopic, tone: PillTone.secondary),
                  ],
                ),
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
        const SizedBox(height: 22),
        _CreateCardsSection(onCreateCards: _createCards),
      ],
    );
  }
}

class _CreateCardsSection extends StatelessWidget {
  const _CreateCardsSection({required this.onCreateCards});

  final VoidCallback onCreateCards;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create cards from this error',
          style: theme.typography.emphasized.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Write one idea per card. AI suggestions are optional when an AI '
          'provider is configured.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        M3EButton.filled(
          key: const ValueKey('error-create-cards'),
          onPressed: onCreateCards,
          icon: const Icon(Icons.add_card),
          label: const Text('Create cards'),
        ),
      ],
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
