import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/error_card_review_view.dart';
import '../export/card_creator_sheet.dart';
import '../export/cards_page.dart';
import 'domain/review_service.dart';
import 'highlight_review_view.dart';
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
  final _edits = <int, ErrorCardContent>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _definition.dispose();
    _scroll.dispose();
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
      _definition.text = step.concept.definition;
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
      _prepareStep();
    });
    _resetScroll();
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _prepareStep();
    });
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _createSkippedCards(SkippedReviewStep step) async {
    if (_busy) return;
    final created = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: widget.sessionId,
        questionId: step.question.id,
        questionContext: step.question.prompt,
        topicName: step.topicName,
        subtopic: step.question.subtopic,
        initialFront: step.question.prompt,
        initialBack: step.question.correctAnswer,
        skippedQuestionId: step.skippedQuestionId,
      ),
    );
    if (!mounted || created == 0) return;
    _created += created;
    _advance();
  }

  Future<void> _saveConceptDefinition(ConceptDefinitionStep step) async {
    if (_definition.text.trim().isEmpty) {
      await showSnack(context, 'Write a definition before saving.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewServiceProvider)
          .saveConceptDefinition(step.concept.id, _definition.text);
      _created++;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepHighlight(HighlightReviewStep step) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(reviewServiceProvider).keepHighlight(step.highlight.id);
      _kept++;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createHighlightCards(HighlightReviewStep step) async {
    final highlight = step.highlight;
    final created = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: highlight.sessionId,
        questionId: highlight.questionId,
        questionContext: highlight.context,
        topicName: highlight.topicName,
        subtopic: highlight.subtopic,
        initialKind: CardCreatorKind.concept,
        initialTerm: highlight.text,
        note: highlight,
      ),
    );
    if (!mounted || created == 0) return;
    _created += created;
    _advance();
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
    final heading = switch (step) {
      ErrorReviewStep() => 'Analyse the error',
      SkippedReviewStep() => 'What was missing?',
      ConceptDefinitionStep() => 'Complete the concept',
      HighlightReviewStep() => 'Keep this note?',
    };
    return AppPage(
      title: 'Review',
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
                          case ErrorReviewStep():
                            _advance();
                          case SkippedReviewStep():
                            _createSkippedCards(step);
                          case ConceptDefinitionStep():
                            _saveConceptDefinition(step);
                          case HighlightReviewStep():
                            _keepHighlight(step);
                        }
                      },
                label: _busy
                    ? 'Saving…'
                    : step is HighlightReviewStep
                    ? 'Keep & save'
                    : step is ErrorReviewStep
                    ? 'Continue'
                    : step is SkippedReviewStep
                    ? 'Create cards'
                    : 'Save',
                icon: step is ErrorReviewStep
                    ? Icons.arrow_forward
                    : step is SkippedReviewStep
                    ? Icons.add_card
                    : Icons.check,
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
          'Step ${_index + 1} of ${data.steps.length}',
          style: theme.typography.baseline.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearScore(value: (_index + 1) / data.steps.length),
        const SizedBox(height: 22),
        Text(heading, style: theme.typography.emphasized.headlineSmall),
        const SizedBox(height: 16),
        switch (step) {
          ErrorReviewStep(:final card) => ErrorCardReviewView(
            card: card,
            editedContent: _edits[card.id],
            onContentChanged: (content) =>
                setState(() => _edits[card.id] = content),
            onCardsAdded: (count) {
              if (!mounted) return;
              setState(() => _created += count);
              _advance();
            },
          ),
          SkippedReviewStep(
            :final question,
            :final topicName,
            :final reasoning,
            :final unknown,
          ) =>
            _SkippedStep(
              question: question,
              topicName: topicName,
              reasoning: reasoning,
              unknown: unknown,
            ),
          ConceptDefinitionStep(:final concept) => _ConceptStep(
            concept: concept,
            definition: _definition,
          ),
          HighlightReviewStep(:final highlight) => HighlightReviewView(
            highlight: highlight,
            onCreateCards: () => _createHighlightCards(step),
          ),
        },
      ],
    );
  }
}

class _SkippedStep extends StatelessWidget {
  const _SkippedStep({
    required this.question,
    required this.topicName,
    required this.reasoning,
    required this.unknown,
  });

  final Question question;
  final String topicName;
  final String reasoning;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 20),
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
                'Create cards from the right answer, or skip to leave it in '
                'the queue.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConceptStep extends StatelessWidget {
  const _ConceptStep({required this.concept, required this.definition});

  final Concept concept;
  final TextEditingController definition;

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
        const SizedBox(height: 16),
        M3ETextField(
          controller: definition,
          label: 'Definition of ${concept.term}',
          minLines: 2,
          maxLines: 4,
          isRequired: true,
        ),
      ],
    );
  }
}
