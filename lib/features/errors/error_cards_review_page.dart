import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_page.dart';
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
  final _scroll = ScrollController();
  late final List<_ReviewStep> _steps = [
    for (final card in widget.cards) _ErrorStep(card),
    for (final question in widget.skippedQuestions) _SkippedStep(question),
  ];
  final _edits = <int, ErrorCardContent>{};
  int _index = 0;
  int _saved = 0;
  bool _busy = false;
  bool _finished = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  _ReviewStep? get _step => _index < _steps.length ? _steps[_index] : null;

  void _advance() {
    if (_index + 1 >= _steps.length) {
      setState(() => _finished = true);
      ref.invalidate(homeStatsProvider);
      return;
    }
    setState(() => _index++);
    _resetScroll();
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() => _index--);
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _cardsAdded(int count) {
    if (!mounted || count <= 0) return;
    setState(() => _saved += count);
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
    return AppPage(
      title: widget.title,
      showBack: true,
      focus: true,
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            if (_index > 0) ...[
              M3EButton.text(
                onPressed: _busy ? null : _goBack,
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
                            _advance();
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
              onPressed: _busy ? null : _advance,
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
      children: [
        Text(
          'Item ${_index + 1} of ${_steps.length}',
          style: theme.typography.baseline.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearScore(value: (_index + 1) / _steps.length),
        const SizedBox(height: 22),
        Text(switch (step) {
          _ErrorStep(:final card) =>
            card.needsDetails
                ? 'Complete the error card'
                : 'Check the error card',
          _SkippedStep() => 'Review the skipped question',
        }, style: theme.typography.emphasized.headlineSmall),
        const SizedBox(height: 16),
        switch (step) {
          _ErrorStep(:final card) => ErrorCardReviewView(
            card: card,
            editedContent: _edits[card.id],
            onContentChanged: (content) =>
                setState(() => _edits[card.id] = content),
            onCardsAdded: _cardsAdded,
          ),
          _SkippedStep(:final question) => Column(
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
        },
      ],
    );
  }
}
