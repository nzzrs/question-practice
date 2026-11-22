import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_controller.dart';
import '../export/card_creator_sheet.dart';
import '../feedback/domain/wrong_answer_bullets.dart';
import '../feedback/feedback_step_header.dart';
import '../review/review_shell.dart';
import '../review/skipped_question_view.dart';
import 'error_card_review_view.dart';

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
  final _creator = CardCreatorController();
  late final List<_ReviewStep> _steps = [
    for (final card in widget.cards) _ErrorStep(card),
    for (final question in widget.skippedQuestions) _SkippedStep(question),
  ];
  int _index = 0;
  int _saved = 0;
  bool _busy = false;
  bool _finished = false;
  final _completionPending = <String>{};

  @override
  void dispose() {
    _scroll.dispose();
    _creator.dispose();
    super.dispose();
  }

  _ReviewStep? get _step => _index < _steps.length ? _steps[_index] : null;

  String _itemKey(_ReviewStep step) {
    return switch (step) {
      _ErrorStep(:final card) => 'errors-review-${card.id}',
      _SkippedStep(:final question) => 'errors-review-skipped-${question.id}',
    };
  }

  CardCreatorRequest _requestFor(_ReviewStep step) {
    return switch (step) {
      _ErrorStep(:final card) => CardCreatorRequest(
        title: 'Create cards',
        sessionId: card.sessionId,
        questionId: card.questionId,
        questionContext: card.question,
        topicName: card.topicName,
        subtopic: card.subtopic,
        existingFronts: ref.read(existingCardTextsProvider),
        itemKey: _itemKey(step),
        error: CardCreatorErrorSource(
          card: card,
          question: card.question,
          wrongAnswer: card.wrongAnswer,
          correctAnswer: card.correctAnswer,
          reasoning: card.reasoning,
          explanation: card.explanation,
          wrongNotes: WrongAnswerBullets.parse(card.reasoning),
        ),
      ),
      _SkippedStep(:final question) => CardCreatorRequest(
        title: 'Create cards',
        sessionId: question.sessionId,
        questionId: question.questionId,
        questionContext: question.question,
        topicName: question.topicName,
        initialFront: question.question,
        initialBack: question.correctAnswer,
        existingFronts: ref.read(existingCardTextsProvider),
        skippedQuestionId: question.id,
        itemKey: _itemKey(step),
      ),
    };
  }

  Future<void> _openCreator(_ReviewStep step) async {
    if (_busy) return;
    await showReviewCardCreator(
      context,
      request: _requestFor(step),
      controller: _creator,
    );
  }

  void _goBack() {
    if (_index == 0 || _busy) return;
    setState(() {
      _index--;
      _creator.resetForStep();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<bool> _saveCachedDrafts(
    _ReviewStep step,
    CardCreatorRequest request,
    CardCreatorSnapshot? snapshot,
  ) async {
    if (snapshot == null) return true;
    if (snapshot.hasUnsavedComposerWork) {
      await showSnack(context, 'Add this card to the list before saving.');
      if (!mounted) return false;
      await _openCreator(step);
      return false;
    }
    final key = _itemKey(step);
    final retryCompletion =
        !snapshot.hasDrafts && _completionPending.contains(key);
    if (!snapshot.hasDrafts && !retryCompletion) return true;
    setState(() => _busy = true);
    try {
      final result = await saveCardCreatorDrafts(
        request: request,
        drafts: snapshot.drafts,
        service: ref.read(reviewServiceProvider),
        noteToConvertId: snapshot.noteToConvert?.id,
        retryCompletion: retryCompletion,
      );
      if (!mounted) return false;
      if (result.failure != null) {
        _creator.storeSnapshot(key, snapshot.withDrafts(result.remaining));
        if (result.completionPending) {
          _completionPending.add(key);
        } else {
          _completionPending.remove(key);
        }
        _saved += result.created;
        await showSnack(context, cardCreatorSaveFailureMessage(result));
        return false;
      }
      _completionPending.remove(key);
      _creator.clearSnapshot(key);
      _creator.clearSeed();
      _saved += result.created;
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves cached drafts and advances. Returns false when the step must stay.
  Future<bool> _saveCurrentStep() async {
    if (_busy) return false;
    final step = _step;
    if (step == null) return false;
    final snapshot = _creator.snapshotFor(_itemKey(step));
    return _saveCachedDrafts(step, _requestFor(step), snapshot);
  }

  void _goNext() {
    if (_busy) return;
    if (_index + 1 >= _steps.length) {
      setState(() => _finished = true);
      ref.invalidate(homeStatsProvider);
      return;
    }
    setState(() {
      _index++;
      _creator.resetForStep();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _saveAndAdvance() async {
    if (await _saveCurrentStep() && mounted) {
      await _requestNext();
    }
  }

  Future<void> _requestNext() async {
    if (_busy) return;
    final last = _index + 1 >= _steps.length;
    if (last && _creator.hasPendingWork) {
      final leave = await confirmDialog(
        context,
        title: 'Leave review?',
        message: 'Drafts and edits for this review are discarded.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
      _creator.clearSnapshots();
      _completionPending.clear();
    }
    _goNext();
  }

  Future<void> _requestClose() async {
    if (_busy) return;
    if (_creator.hasPendingWork) {
      final leave = await confirmDialog(
        context,
        title: 'Leave review?',
        message: 'Drafts and edits for this review are discarded.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
    }
    _creator.clearSnapshots();
    _completionPending.clear();
    // Pop directly: the focus shell's PopScope delegates back here, so
    // maybePop would re-enter this guard.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveReview(child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
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
      return ReviewCompletionPage(
        title: 'Review complete',
        heading: _saved == 0 ? 'No cards changed' : 'Review complete',
        message: _saved == 0
            ? 'No card details were saved.'
            : '$_saved card${_saved == 1 ? '' : 's'} completed or created.',
        onDone: () => Navigator.of(context).pop(true),
        scrollController: _scroll,
      );
    }

    final step = _step!;
    final last = _index + 1 >= _steps.length;
    return ReviewShell(
      title: widget.title,
      saveLabel: last ? 'Save and finish' : 'Save',
      onSave: _saveAndAdvance,
      onBack: _goBack,
      onNext: _requestNext,
      onClose: _requestClose,
      canGoBack: _index > 0,
      canGoNext: !last,
      onCreateCards: () => _openCreator(step),
      busy: _busy,
      scrollController: _scroll,
      children: [
        ...switch (step) {
          _ErrorStep(:final card) => [
            ErrorCardReviewView(
              card: card,
              creator: _creator,
              onSeedRequested: () => _openCreator(step),
              hasUnsavedComposerWork: () =>
                  _creator
                      .snapshotFor(_itemKey(step))
                      ?.hasUnsavedComposerWork ??
                  false,
              leading: FeedbackStepHeader(
                label: 'Item ${_index + 1} of ${_steps.length}',
                progress: (_index + 1) / _steps.length,
                heading: card.needsDetails
                    ? 'Complete the error card'
                    : 'Check the error card',
              ),
            ),
          ],
          _SkippedStep(:final question) => [
            FeedbackStepHeader(
              label: 'Item ${_index + 1} of ${_steps.length}',
              progress: (_index + 1) / _steps.length,
              heading: 'Review the skipped question',
            ),
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
          ],
        },
      ],
    );
  }
}
