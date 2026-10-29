import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/error_card_review_view.dart';
import '../export/cards_page.dart';
import 'domain/review_service.dart';

enum _Missing { concept, question }

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
  bool _busy = false;
  bool _finished = false;

  final _bias = TextEditingController();
  final _vaccine = TextEditingController();
  final _term = TextEditingController();
  final _definition = TextEditingController();
  final _newQuestion = TextEditingController();
  final _newAnswer = TextEditingController();
  _Missing _missing = _Missing.concept;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bias.dispose();
    _vaccine.dispose();
    _term.dispose();
    _definition.dispose();
    _newQuestion.dispose();
    _newAnswer.dispose();
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
    _missing = _Missing.concept;
    _bias.clear();
    _vaccine.clear();
    _term.clear();
    _definition.clear();
    _newQuestion.clear();
    _newAnswer.clear();
    switch (step) {
      case ErrorReviewStep(:final card):
        _bias.text = card.bias;
        _vaccine.text = card.vaccine;
      case ConceptDefinitionStep(:final concept):
        _definition.text = concept.definition;
      default:
        break;
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
  }

  Future<void> _saveError(ErrorReviewStep step) async {
    if (_bias.text.trim().isEmpty || _vaccine.text.trim().isEmpty) {
      await showSnack(
        context,
        'Write both the flawed assumption and the prevention note.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewServiceProvider)
          .saveErrorDetails(
            cardId: step.card.id,
            bias: _bias.text,
            vaccine: _vaccine.text,
          );
      _created++;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSkipped(SkippedReviewStep step) async {
    if (_missing == _Missing.concept) {
      if (_term.text.trim().isEmpty || _definition.text.trim().isEmpty) {
        await showSnack(context, 'Fill in the term and its definition.');
        return;
      }
    } else if (_newQuestion.text.trim().isEmpty ||
        _newAnswer.text.trim().isEmpty) {
      await showSnack(context, 'Fill in both the new question and its answer.');
      return;
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(reviewServiceProvider);
      if (_missing == _Missing.concept) {
        await service.createConcept(
          sessionId: widget.sessionId,
          questionId: step.question.id,
          term: _term.text,
          definition: _definition.text,
          context: step.question.prompt,
          topicName: step.topicName,
          source: ConceptSource.manual,
        );
      } else {
        await service.createBasicCard(
          sessionId: widget.sessionId,
          question: _newQuestion.text,
          answer: _newAnswer.text,
          topicName: step.topicName,
        );
      }
      if (!mounted) return;
      _created++;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (_error != null) {
      return AppPage(
        title: 'Review',
        showBack: true,
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
        variant: M3EAppBarVariant.small,
        children: [
          const SizedBox(height: 32),
          Center(child: IconBadge(Icons.check_circle_outline, size: 72)),
          const SizedBox(height: 16),
          Text(
            _created == 0 ? 'Review closed' : 'Review complete',
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _created == 0
                ? 'No card details were saved.'
                : '$_created card${_created == 1 ? '' : 's'} completed or created. You can finish missing details later in Cards.',
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
    };
    return AppPage(
      title: 'Review',
      showBack: true,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                onPressed: _busy
                    ? null
                    : () {
                        switch (step) {
                          case ErrorReviewStep():
                            _saveError(step);
                          case SkippedReviewStep():
                            _saveSkipped(step);
                          case ConceptDefinitionStep():
                            _saveConceptDefinition(step);
                        }
                      },
                label: _busy ? 'Saving…' : 'Save',
                icon: Icons.check,
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
            bias: _bias,
            vaccine: _vaccine,
          ),
          SkippedReviewStep(:final question) => _SkippedStep(
            question: question,
            missing: _missing,
            onMissingChanged: (value) => setState(() => _missing = value),
            term: _term,
            definition: _definition,
            newQuestion: _newQuestion,
            newAnswer: _newAnswer,
          ),
          ConceptDefinitionStep(:final concept) => _ConceptStep(
            concept: concept,
            definition: _definition,
          ),
        },
      ],
    );
  }
}

class _SkippedStep extends StatelessWidget {
  const _SkippedStep({
    required this.question,
    required this.missing,
    required this.onMissingChanged,
    required this.term,
    required this.definition,
    required this.newQuestion,
    required this.newAnswer,
  });

  final Question question;
  final _Missing missing;
  final ValueChanged<_Missing> onMissingChanged;
  final TextEditingController term;
  final TextEditingController definition;
  final TextEditingController newQuestion;
  final TextEditingController newAnswer;

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
                question.prompt,
                style: theme.typography.baseline.titleSmall,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Answer: ${question.correctAnswer}',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.explanation,
                style: theme.typography.baseline.bodySmall.copyWith(
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'What was missing here?',
          style: theme.typography.emphasized.titleSmall,
        ),
        const SizedBox(height: 10),
        M3ESegmentedButton<_Missing>(
          segments: const [
            M3ESegment(value: _Missing.concept, label: 'A concept'),
            M3ESegment(value: _Missing.question, label: 'Another question'),
          ],
          selected: {missing},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) onMissingChanged(values.first);
          },
        ),
        const SizedBox(height: 16),
        if (missing == _Missing.concept) ...[
          M3ETextField(
            controller: term,
            label: 'Definition of…',
            placeholder: 'Term',
            isRequired: true,
          ),
          const SizedBox(height: 12),
          M3ETextField(
            controller: definition,
            label: 'Definition',
            minLines: 2,
            maxLines: 4,
            isRequired: true,
          ),
        ] else ...[
          M3ETextField(
            controller: newQuestion,
            label: 'New question',
            minLines: 2,
            maxLines: 4,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          M3ETextField(
            controller: newAnswer,
            label: 'Answer',
            minLines: 2,
            maxLines: 4,
            isRequired: true,
          ),
        ],
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
