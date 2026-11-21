import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/adaptive_split_view.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_controller.dart';
import '../export/card_creator_sheet.dart';
import '../feedback/domain/wrong_notes.dart';
import '../feedback/feedback_step_header.dart';
import 'error_card_review_view.dart';
import '../review/skipped_question_view.dart';

/// Reviews error cards and skipped questions together.
class ErrorCardsReviewPage extends ConsumerStatefulWidget {
  const ErrorCardsReviewPage({
    required this.cards,
    this.skippedQuestions = const [],
    this.title = 'Review cards',
    super.key,
  });

  final List<ErrorCard> cards;
  final List<SkippedQuestion> skippedQuestions;
  final String title;

  @override
  ConsumerState<ErrorCardsReviewPage> createState() =>
      _ErrorCardsReviewPageState();
}

sealed class _ReviewStep {
  const _ReviewStep();
}

class _ErrorStep extends _ReviewStep {
  const _ErrorStep(this.card);

  final ErrorCard card;
}

class _SkippedStep extends _ReviewStep {
  const _SkippedStep(this.question);

  final SkippedQuestion question;
}

class _ErrorCardsReviewPageState extends ConsumerState<ErrorCardsReviewPage> {
  static const _splitStorageKey = ValueKey<String>('error-cards-review-split');

  final _scroll = ScrollController();
  final _feedbackScroll = ScrollController();
  final _creator = CardCreatorController();
  late final List<_ReviewStep> _steps = [
    for (final card in widget.cards) _ErrorStep(card),
    for (final question in widget.skippedQuestions) _SkippedStep(question),
  ];
  int _index = 0;
  int _saved = 0;
  int _draftCount = 0;
  bool _busy = false;
  bool _finished = false;

  @override
  void dispose() {
    _scroll.dispose();
    _feedbackScroll.dispose();
    _creator.dispose();
    super.dispose();
  }

  _ReviewStep? get _step => _index < _steps.length ? _steps[_index] : null;

  CardCreatorRequest _requestFor(ErrorCard card) {
    return CardCreatorRequest(
      title: 'Create cards',
      sessionId: card.sessionId,
      questionId: card.questionId,
      questionContext: card.question,
      topicName: card.topicName,
      subtopic: card.subtopic,
      existingFronts: ref.watch(existingCardTextsProvider),
      error: CardCreatorErrorSource(
        card: card,
        question: card.question,
        wrongAnswer: card.wrongAnswer,
        correctAnswer: card.correctAnswer,
        reasoning: card.reasoning,
        explanation: card.explanation,
        wrongNotes: WrongNotes.parse(card.reasoning),
      ),
    );
  }

  void _advance() {
    if (_index + 1 >= _steps.length) {
      setState(() => _finished = true);
      ref.invalidate(homeStatsProvider);
      return;
    }
    setState(() => _index++);
    _resetStepState();
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() => _index--);
    _resetStepState();
  }

  void _resetStepState() {
    _creator.resetForStep();
    _draftCount = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_feedbackScroll.hasClients) _feedbackScroll.jumpTo(0);
  }

  Future<bool> _confirmDiscard() async {
    if (_draftCount <= 0) return true;
    final count = _draftCount;
    return confirmDialog(
      context,
      title: 'Discard unsaved cards?',
      message:
          '$count card${count == 1 ? ' is' : 's are'} not saved yet. '
          'Leaving this step discards ${count == 1 ? 'it' : 'them'}.',
      confirmLabel: 'Discard cards',
      cancelLabel: 'Keep editing',
    );
  }

  Future<void> _requestAdvance() async {
    if (_busy) return;
    if (!await _confirmDiscard() || !mounted) return;
    _advance();
  }

  Future<void> _requestBack() async {
    if (_busy) return;
    if (!await _confirmDiscard() || !mounted) return;
    _goBack();
  }

  Future<void> _requestClose() async {
    if (!await _confirmDiscard() || !mounted) return;
    // Pop directly: the focus shell's PopScope delegates back here, so
    // maybePop would re-enter this guard.
    Navigator.of(context).pop();
  }

  void _cardsAdded(int count) {
    if (!mounted || count <= 0) return;
    setState(() => _saved += count);
    _creator.clearSeed();
    _advance();
  }

  Future<void> _createSkippedCards(_SkippedStep step) async {
    if (_busy) return;
    final question = step.question;
    setState(() => _busy = true);
    try {
      final created = await showCardCreator(
        context,
        request: CardCreatorRequest(
          title: 'Create cards',
          sessionId: question.sessionId,
          questionId: question.questionId,
          questionContext: question.question,
          topicName: question.topicName,
          initialFront: question.question,
          initialBack: question.correctAnswer,
          existingFronts: ref.read(existingCardTextsProvider),
          skippedQuestionId: question.id,
        ),
      );
      if (!mounted || created == 0) return;
      _saved += created;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveReview(child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (_steps.isEmpty) {
      return AppPage(
        title: widget.title,
        showBack: true,
        focus: true,
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: const [
          EmptyState(
            icon: Icons.style_outlined,
            title: 'Nothing to review',
            message: 'Wrong answers create error cards; skipped answers wait here too.',
          ),
        ],
      );
    }
    if (_finished) {
      return AppPage(
        title: 'Review complete',
        focus: true,
        onBack: () => Navigator.of(context).pop(true),
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: [
          const SizedBox(height: 32),
          Center(child: IconBadge(Icons.check_circle_outline, size: 72)),
          const SizedBox(height: 16),
          Text(
            _saved == 0 ? 'No cards changed' : 'Review complete',
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _saved == 0
                ? 'No card details were saved.'
                : '$_saved card${_saved == 1 ? '' : 's'} completed or created.',
            textAlign: TextAlign.center,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Done',
            icon: Icons.check,
          ),
        ],
      );
    }

    final step = _step!;
    final isSkipped = step is _SkippedStep;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AppPage(
      title: widget.title,
      showBack: true,
      focus: true,
      maxWidth: 1200,
      onBack: _requestClose,
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            if (_index > 0) ...[
              M3EButton.text(
                onPressed: _busy ? null : _requestBack,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: AppPrimaryButton(
                onPressed: _busy
                    ? null
                    : () {
                        switch (step) {
                          case _ErrorStep():
                            _requestAdvance();
                          case _SkippedStep():
                            _createSkippedCards(step);
                        }
                      },
                label: _busy
                    ? 'Saving…'
                    : isSkipped
                    ? 'Create cards'
                    : 'Continue',
                icon: isSkipped ? Icons.add_card : Icons.arrow_forward,
              ),
            ),
            const SizedBox(width: 8),
            M3EButton.text(
              onPressed: _busy ? null : _requestAdvance,
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
      body: switch (step) {
        _ErrorStep(:final card) => AdaptiveSplitView(
          storageKey: _splitStorageKey,
          minLeading: keyboardOpen ? 96 : 160,
          minTrailing: keyboardOpen ? 240 : 220,
          leading: ErrorCardReviewView(
            card: card,
            creator: _creator,
            onSeedRequested: () {},
            leading: FeedbackStepHeader(
              label: 'Item ${_index + 1} of ${_steps.length}',
              progress: (_index + 1) / _steps.length,
              heading: card.needsDetails
                  ? 'Complete the error card'
                  : 'Check the error card',
            ),
            scrollController: _feedbackScroll,
          ),
          trailing: CardCreatorPane(
            key: ValueKey('creator-${card.id}'),
            request: _requestFor(card),
            controller: _creator,
            onSaved: _cardsAdded,
            onDraftCountChanged: (count) {
              if (!mounted || count == _draftCount) return;
              setState(() => _draftCount = count);
            },
          ),
        ),
        _SkippedStep() => null,
      },
      children: switch (step) {
        _ErrorStep() => const [],
        _SkippedStep(:final question) => [
          Text(
            'Item ${_index + 1} of ${_steps.length}',
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearScore(value: (_index + 1) / _steps.length),
          const SizedBox(height: 22),
          Text(
            'Review the skipped question',
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkippedQuestionView(
                prompt: question.question,
                alternatives: question.alternatives,
                correctIndexes: question.correctIndexes,
                alternativeExplanations: question.alternativeExplanations,
                explanation: question.explanation,
                reasoning: question.reasoning,
                topicName: question.topicName,
                unknown: question.unknown,
              ),
              const SizedBox(height: 18),
              TonalBox(
                key: const ValueKey('skipped-review-missing'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What was missing?',
                      style: theme.typography.emphasized.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create cards from the right answer, or skip to leave '
                      'it in the queue.',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      },
    );
  }
}
