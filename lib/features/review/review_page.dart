import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/error_card_review_view.dart';
import '../export/card_creator_controller.dart';
import '../export/card_creator_sheet.dart';
import '../export/cards_page.dart';
import '../feedback/domain/wrong_notes.dart';
import '../feedback/feedback_step_header.dart';
import 'domain/review_service.dart';
import 'note_review_view.dart';
import 'review_action_dock.dart';
import 'skipped_question_view.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  ReviewData? _data;
  Object? _error;
  int _index = 0;
  int _created = 0;
  int _kept = 0;
  bool _busy = false;
  bool _finished = false;

  final _definition = TextEditingController();
  final _scroll = ScrollController();
  final _creator = CardCreatorController();
  final _conceptDrafts = <int, String>{};
  final _savedConceptIds = <int>{};
  final _completionPending = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _definition.dispose();
    _scroll.dispose();
    _creator.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(reviewServiceProvider).load(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _prepareStep();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  ReviewStep? get _step {
    final data = _data;
    if (data == null || _index >= data.steps.length) return null;
    return data.steps[_index];
  }

  void _prepareStep() {
    final step = _step;
    _definition.clear();
    if (step is ConceptDefinitionStep) {
      _definition.text =
          _conceptDrafts[step.concept.id] ?? step.concept.definition;
    }
  }

  void _advance() {
    final data = _data;
    if (data == null) return;
    if (_index + 1 >= data.steps.length) {
      setState(() => _finished = true);
      ref.invalidate(homeStatsProvider);
      return;
    }
    setState(() {
      _index++;
      _creator.resetForStep();
      _prepareStep();
    });
    _resetScroll();
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _creator.resetForStep();
      _prepareStep();
    });
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _itemKey(ReviewStep step) {
    return switch (step) {
      ErrorReviewStep(:final card) => 'review-error-${card.id}',
      SkippedReviewStep(:final skippedQuestionId, :final question) =>
        'review-skipped-${skippedQuestionId ?? question.id}',
      ConceptDefinitionStep(:final concept) => 'review-concept-${concept.id}',
      NoteReviewStep(:final note) => 'review-note-${note.id}',
    };
  }

  CardCreatorRequest _requestForStep(ReviewStep step) {
    return switch (step) {
      ErrorReviewStep(:final card) => CardCreatorRequest(
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
          wrongNotes: WrongNotes.parse(card.reasoning),
        ),
      ),
      SkippedReviewStep() => CardCreatorRequest(
        title: 'Create cards',
        sessionId: widget.sessionId,
        questionId: step.question.id,
        questionContext: step.question.prompt,
        topicName: step.topicName,
        subtopic: step.question.subtopic,
        initialFront: step.question.prompt,
        initialBack: step.question.correctAnswer,
        existingFronts: ref.read(existingCardTextsProvider),
        skippedQuestionId: step.skippedQuestionId,
        itemKey: _itemKey(step),
      ),
      ConceptDefinitionStep(:final concept) => CardCreatorRequest(
        title: 'Create cards',
        sessionId: concept.sessionId,
        questionId: concept.questionId,
        questionContext: concept.context,
        topicName: concept.topicName,
        subtopic: concept.subtopic,
        initialTemplate: CardTemplate.definition,
        initialTerm: concept.term,
        initialDefinition: _definition.text,
        existingFronts: ref.read(existingCardTextsProvider),
        itemKey: _itemKey(step),
      ),
      NoteReviewStep(:final note) => CardCreatorRequest(
        title: 'Create cards',
        sessionId: note.sessionId,
        questionId: note.questionId,
        questionContext: note.context,
        topicName: note.topicName,
        subtopic: note.subtopic,
        initialTemplate: CardTemplate.definition,
        initialTerm: note.text,
        existingFronts: ref.read(existingCardTextsProvider),
        note: note,
        itemKey: _itemKey(step),
      ),
    };
  }

  Future<void> _openCreator(ReviewStep step) async {
    if (_busy) return;
    await showReviewCardCreator(
      context,
      request: _requestForStep(step),
      controller: _creator,
    );
  }

  Future<bool> _saveCachedDrafts(
    ReviewStep step,
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
        _created += result.created;
        await showSnack(context, cardCreatorSaveFailureMessage(result));
        return false;
      }
      _completionPending.remove(key);
      _creator.clearSnapshot(key);
      _creator.clearSeed();
      _created += result.created;
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCurrentStep() async {
    if (_busy) return;
    final step = _step;
    if (step == null) return;
    if (step is ConceptDefinitionStep && _definition.text.trim().isEmpty) {
      await showSnack(context, 'Write a definition before saving.');
      return;
    }
    final request = _requestForStep(step);
    final snapshot = _creator.snapshotFor(_itemKey(step));
    if (!await _saveCachedDrafts(step, request, snapshot)) return;
    if (!mounted) return;

    switch (step) {
      case ErrorReviewStep():
      case SkippedReviewStep():
        await _requestNext();
        return;
      case ConceptDefinitionStep(:final concept):
        setState(() => _busy = true);
        try {
          await ref
              .read(reviewServiceProvider)
              .saveConceptDefinition(concept.id, _definition.text);
          if (!mounted) return;
          _conceptDrafts[concept.id] = _definition.text;
          _savedConceptIds.add(concept.id);
          _created++;
        } on Object catch (error) {
          if (mounted) await showSnack(context, 'Could not save: $error');
          return;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case NoteReviewStep(:final note):
        setState(() => _busy = true);
        try {
          await ref.read(reviewServiceProvider).keepNote(note.id);
          if (!mounted) return;
          _kept++;
        } on Object catch (error) {
          if (mounted) await showSnack(context, 'Could not save: $error');
          return;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
    }
    if (mounted) await _requestNext();
  }

  bool get _hasUnsavedConceptText {
    final step = _step;
    return step is ConceptDefinitionStep &&
        !_savedConceptIds.contains(step.concept.id) &&
        _definition.text.trim().isNotEmpty;
  }

  Future<void> _deleteNote(ReviewStep step, Note note) async {
    if (_busy) return;
    final snapshot = _creator.snapshotFor(_itemKey(step));
    final hasDrafts = snapshot?.hasDrafts ?? false;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete note?',
      message:
          'The saved note "${note.text}" is removed from Cards. '
          'Cards already made from it stay.'
          '${hasDrafts ? ' Unsaved card drafts for this note are discarded.' : ''}',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(cardRepositoryProvider).deleteNote(note.id);
      if (!mounted) return;
      _creator.forgetNote(note.id);
      _creator.clearSnapshot(_itemKey(step));
      _completionPending.remove(_itemKey(step));
      final data = _data;
      if (data == null) return;
      data.steps.remove(step);
      final finished = data.steps.isEmpty;
      setState(() {
        _creator.resetForStep();
        if (finished) {
          _finished = true;
        } else {
          if (_index >= data.steps.length) {
            _index = data.steps.length - 1;
          }
          _prepareStep();
        }
      });
      if (finished) ref.invalidate(homeStatsProvider);
      _resetScroll();
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete the note: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestNext() async {
    if (_busy) return;
    final data = _data;
    if (data == null) return;
    final last = _index + 1 >= data.steps.length;
    if (last && (_creator.hasPendingWork || _hasUnsavedConceptText)) {
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
    _advance();
  }

  Future<void> _requestClose() async {
    if (_busy) return;
    if (_creator.hasPendingWork || _hasUnsavedConceptText) {
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

  String _headingFor(ReviewStep step) {
    return switch (step) {
      ErrorReviewStep() => 'Analyse the error',
      SkippedReviewStep() => 'What was missing?',
      ConceptDefinitionStep() => 'Complete the concept',
      NoteReviewStep() => 'Review the note',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveReview(child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (_error != null) {
      return AppPage(
        title: 'Review',
        showBack: true,
        focus: true,
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: [
          EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load the review',
            message: '$_error',
            action: M3EButton.filled(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    final data = _data;
    if (data == null) {
      return AppPage(
        title: 'Review',
        showBack: true,
        focus: true,
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
        ],
      );
    }
    if (_finished || data.steps.isEmpty) {
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
            _created == 0 && _kept == 0 ? 'Review closed' : 'Review complete',
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _created == 0 && _kept == 0
                ? 'No card details were saved.'
                : '${[if (_created > 0) '$_created card${_created == 1 ? '' : 's'} completed or created', if (_kept > 0) '$_kept note${_kept == 1 ? '' : 's'} kept'].join(' and ')}. You can finish missing details later in Cards.',
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: M3EButton.tonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const CardsPage(),
                ),
              ),
              icon: const Icon(Icons.style_outlined),
              label: const Text('View cards'),
            ),
          ),
        ],
      );
    }

    final step = _step!;
    final heading = _headingFor(step);
    final last = _index + 1 >= data.steps.length;
    return AppPage(
      title: 'Review',
      showBack: true,
      focus: true,
      onBack: _requestClose,
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: ReviewActionDock(
        busy: _busy,
        saveLabel: last
            ? (step is NoteReviewStep ? 'Save and finish' : 'Finish')
            : 'Save',
        onSave: _saveCurrentStep,
        onBack: _goBack,
        onNext: _requestNext,
        canGoBack: _index > 0,
        canGoNext: true,
        onCreateCards: () => _openCreator(step),
        onDelete: step is NoteReviewStep
            ? () => _deleteNote(step, step.note)
            : null,
      ),
      children: [..._buildStep(theme, step, data, heading)],
    );
  }

  List<Widget> _buildStep(
    M3EThemeData theme,
    ReviewStep step,
    ReviewData data,
    String heading,
  ) {
    final header = FeedbackStepHeader(
      label: 'Step ${_index + 1} of ${data.steps.length}',
      progress: (_index + 1) / data.steps.length,
      heading: heading,
    );
    return switch (step) {
      ErrorReviewStep(:final card) => [
        ErrorCardReviewView(
          card: card,
          creator: _creator,
          onSeedRequested: () => _openCreator(step),
          hasUnsavedComposerWork: () =>
              _creator.snapshotFor(_itemKey(step))?.hasUnsavedComposerWork ??
              false,
          leading: header,
        ),
      ],
      SkippedReviewStep(
        :final question,
        :final topicName,
        :final reasoning,
        :final unknown,
      ) =>
        [
          header,
          SkippedQuestionView(
            prompt: question.prompt,
            alternatives: question.alternatives,
            correctIndexes: question.correctIndexes,
            alternativeExplanations: question.alternativeExplanations,
            explanation: question.explanation,
            reasoning: reasoning,
            topicName: topicName,
            unknown: unknown,
          ),
        ],
      ConceptDefinitionStep(:final concept) => [
        header,
        SelectionArea(
          child: TonalBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept.term,
                  style: theme.typography.emphasized.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  concept.context,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        M3ETextField(
          controller: _definition,
          label: 'Definition of ${concept.term}',
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          onChanged: (value) {
            _conceptDrafts[concept.id] = value;
            _savedConceptIds.remove(concept.id);
          },
        ),
      ],
      NoteReviewStep(:final note) => [header, NoteReviewView(note: note)],
    };
  }
}
