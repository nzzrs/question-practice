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
import '../review/domain/card_litmus.dart';
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
  List<SuggestedCard>? _suggestions;
  final _selectedSuggestions = <int>{};
  String? _suggestionError;
  bool _loadingSuggestions = false;
  bool _savingSuggestions = false;

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
      _resetSuggestions();
    }
  }

  void _resetSuggestions() {
    _suggestions = null;
    _selectedSuggestions.clear();
    _suggestionError = null;
  }

  Future<void> _editContent() async {
    final updated = await openErrorCardContentEditor(
      context,
      card: widget.card,
      current: _content,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _localContent = updated;
      _resetSuggestions();
    });
    widget.onContentChanged?.call(updated);
    await showSnack(context, 'Card content updated.');
  }

  Future<void> _breakdown() async {
    if (_loadingSuggestions || _savingSuggestions) return;
    setState(() {
      _loadingSuggestions = true;
      _resetSuggestions();
    });
    try {
      final card = widget.card;
      final cards = await ref
          .read(lookupServiceProvider)
          .breakdownErrorCard(
            question: _question,
            wrongAnswer: _answersFor(card.wrongIndexes),
            correctAnswer: _answersFor(card.correctIndexes),
            reasoning: card.reasoning,
            explanation: _content.explanation,
            topicName: card.topicName,
            subtopic: card.subtopic,
            mistakeKinds: card.mistakeKinds,
          );
      if (!mounted) return;
      setState(() {
        _suggestions = cards;
        _selectedSuggestions.addAll([
          for (var index = 0; index < cards.length; index++) index,
        ]);
      });
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() => _suggestionError = error.message);
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _suggestionError = 'Could not break down the error: $error',
      );
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _addSelected() async {
    final suggestions = _suggestions;
    if (suggestions == null || _selectedSuggestions.isEmpty) return;
    if (_savingSuggestions) return;
    final chosen = [
      for (final index in _selectedSuggestions.toList()..sort())
        suggestions[index],
    ];
    setState(() => _savingSuggestions = true);
    try {
      final added = await ref
          .read(reviewServiceProvider)
          .createErrorBreakdownCards(card: widget.card, cards: chosen);
      if (!mounted) return;
      setState(() => _resetSuggestions());
      final report = widget.onCardsAdded;
      if (report != null) {
        report(added);
      } else {
        await showSnack(context, '$added card${added == 1 ? '' : 's'} added.');
      }
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not add the cards: $error');
      }
    } finally {
      if (mounted) setState(() => _savingSuggestions = false);
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
        _AtomicCardsSection(
          suggestions: _suggestions,
          selected: _selectedSuggestions,
          error: _suggestionError,
          loading: _loadingSuggestions,
          saving: _savingSuggestions,
          onBreakdown: _breakdown,
          onAdd: _addSelected,
          onSelectionChanged: (index, selected) => setState(() {
            if (selected) {
              _selectedSuggestions.add(index);
            } else {
              _selectedSuggestions.remove(index);
            }
          }),
        ),
      ],
    );
  }
}

class _AtomicCardsSection extends StatelessWidget {
  const _AtomicCardsSection({
    required this.suggestions,
    required this.selected,
    required this.error,
    required this.loading,
    required this.saving,
    required this.onBreakdown,
    required this.onAdd,
    required this.onSelectionChanged,
  });

  final List<SuggestedCard>? suggestions;
  final Set<int> selected;
  final String? error;
  final bool loading;
  final bool saving;
  final VoidCallback onBreakdown;
  final VoidCallback onAdd;
  final void Function(int index, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final cards = suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Break this error into atomic cards',
          style: theme.typography.emphasized.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'One idea per card. The AI proposes a contrast and a rule; choose '
          'the ones to save.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          TonalBox(
            key: const ValueKey('error-breakdown-loading'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const M3ELoadingIndicator(),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Breaking the error down…',
                    style: theme.typography.baseline.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else if (error != null) ...[
          TonalBox(
            key: const ValueKey('error-breakdown-error'),
            color: theme.colorScheme.errorContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error!,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
                if (error!.toLowerCase().contains('settings')) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Open Settings to add an AI provider and key.',
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          M3EButton.tonal(
            key: const ValueKey('error-breakdown-retry'),
            onPressed: saving ? null : onBreakdown,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ] else if (cards == null)
          M3EButton.tonal(
            key: const ValueKey('error-breakdown-ai'),
            onPressed: onBreakdown,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Break into atomic cards (AI)'),
          )
        else if (cards.isEmpty) ...[
          TonalBox(
            key: const ValueKey('error-breakdown-empty'),
            child: Text(
              'The AI found no atomic cards for this error.',
              style: theme.typography.baseline.bodyMedium.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          M3EButton.tonal(
            key: const ValueKey('error-breakdown-retry'),
            onPressed: saving ? null : onBreakdown,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ] else ...[
          if (cards.any(
            (card) => card.cognitiveType == CognitiveType.heuristic,
          )) ...[
            TonalBox(
              key: const ValueKey('error-heuristic-template'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'Heuristic template: "Given requirement X with restriction Y, '
                'what rule applies?" → answer with one atomic rule.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (var index = 0; index < cards.length; index++)
            _SuggestionTile(
              key: ValueKey('error-suggestion-$index'),
              index: index,
              suggestion: cards[index],
              report: checkCardLitmus(
                front: cards[index].front,
                back: cards[index].back,
                cognitiveType: cards[index].cognitiveType,
              ),
              selected: selected.contains(index),
              onChanged: saving
                  ? null
                  : (value) => onSelectionChanged(index, value),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              M3EButton.text(
                key: const ValueKey('error-breakdown-retry'),
                onPressed: saving ? null : onBreakdown,
                child: const Text('Try again'),
              ),
              M3EButton.filled(
                key: const ValueKey('error-add-cards'),
                onPressed: saving || selected.isEmpty ? null : onAdd,
                icon: const Icon(Icons.add),
                label: Text(
                  saving
                      ? 'Adding…'
                      : 'Add ${selected.length} card${selected.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.index,
    required this.suggestion,
    required this.report,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int index;
  final SuggestedCard suggestion;
  final LitmusReport report;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final clean = report.isClean;
    final qualityLabel = clean ? 'Ready' : 'Check quality';
    final qualityDetail = clean
        ? 'Passes the card quality checks'
        : report.detail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TonalBox(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ECheckbox(
              value: selected,
              semanticLabel: 'Select ${suggestion.cognitiveType.label} card',
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(
                        key: ValueKey('error-type-badge-$index'),
                        suggestion.cognitiveType.label,
                        tone: PillTone.primary,
                      ),
                      Tooltip(
                        message: qualityDetail,
                        child: Pill(
                          key: ValueKey('error-litmus-badge-$index'),
                          qualityLabel,
                          tone: clean ? PillTone.success : PillTone.error,
                          icon: clean
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    suggestion.front,
                    style: theme.typography.baseline.titleSmall.copyWith(
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    suggestion.back,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (!clean) ...[
                    const SizedBox(height: 6),
                    Text(
                      report.detail,
                      key: ValueKey('error-litmus-detail-$index'),
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.error,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
