import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../lookup/domain/lookup_service.dart';
import '../review/domain/card_litmus.dart';

enum CardCreatorKind { basic, concept }

/// The error being turned into cards, with any learner edits already applied.
class CardCreatorErrorSource {
  const CardCreatorErrorSource({
    required this.card,
    required this.question,
    required this.wrongAnswer,
    required this.correctAnswer,
    this.reasoning = '',
    this.explanation = '',
  });

  final ErrorCard card;
  final String question;
  final String wrongAnswer;
  final String correctAnswer;
  final String reasoning;
  final String explanation;
}

/// Everything one card-creation flow needs from its review surface.
class CardCreatorRequest {
  const CardCreatorRequest({
    required this.title,
    this.sessionId,
    this.questionId,
    this.questionContext = '',
    this.topicName = '',
    this.subtopic = '',
    this.initialKind = CardCreatorKind.basic,
    this.initialFront = '',
    this.initialBack = '',
    this.initialTerm = '',
    this.initialDefinition = '',
    this.note,
    this.error,
    this.skippedQuestionId,
  });

  final String title;
  final int? sessionId;
  final int? questionId;
  final String questionContext;
  final String topicName;
  final String subtopic;
  final CardCreatorKind initialKind;
  final String initialFront;
  final String initialBack;
  final String initialTerm;
  final String initialDefinition;

  /// Note context: enables AI suggestions and marks the note converted on save.
  final StudyHighlight? note;

  /// Error context: enables AI breakdown and completes details on save.
  final CardCreatorErrorSource? error;

  /// Skipped queue record to mark handled once a card is saved.
  final int? skippedQuestionId;
}

/// Opens the shared card creator in a bottom sheet and returns the number of
/// cards saved.
///
/// The sheet starts at [M3EBottomSheetValue.collapsed], so the error, note or
/// skipped question it was opened from stays readable above it. Dragging the
/// handle up gives the creator more room.
Future<int> showCardCreator(
  BuildContext context, {
  required CardCreatorRequest request,
}) async {
  final created = await M3EBottomSheet.show<int>(
    context,
    initialValue: M3EBottomSheetValue.collapsed,
    builder: (context) => CardCreatorSheet(request: request),
  );
  return created ?? 0;
}

/// One creator for manual cards and optional AI suggestions.
///
/// Lives inside an [M3EBottomSheet], so the review surface behind it keeps the
/// mistake visible while cards are written. Manual entry never needs an AI
/// provider. Cards are collected as drafts and saved together, so the learner
/// can add several ideas little by little.
class CardCreatorSheet extends ConsumerStatefulWidget {
  const CardCreatorSheet({required this.request, super.key});

  final CardCreatorRequest request;

  @override
  ConsumerState<CardCreatorSheet> createState() => _CardCreatorSheetState();
}

sealed class _CardDraft {
  const _CardDraft();
}

class _BasicDraft extends _CardDraft {
  const _BasicDraft({
    required this.front,
    required this.back,
    required this.cognitiveType,
  });

  final String front;
  final String back;
  final CognitiveType cognitiveType;
}

class _ConceptDraft extends _CardDraft {
  const _ConceptDraft({required this.term, required this.definition});

  final String term;
  final String definition;
}

class _AiSuggestion {
  _AiSuggestion(this.suggestion)
    : front = TextEditingController(text: suggestion.front),
      back = TextEditingController(text: suggestion.back);

  final SuggestedCard suggestion;
  final TextEditingController front;
  final TextEditingController back;
  bool selected = true;

  LitmusReport get report => checkCardLitmus(
    front: front.text,
    back: back.text,
    cognitiveType: suggestion.cognitiveType,
  );

  void dispose() {
    front.dispose();
    back.dispose();
  }
}

class _CardCreatorSheetState extends ConsumerState<CardCreatorSheet> {
  late final _front = TextEditingController(text: widget.request.initialFront);
  late final _back = TextEditingController(text: widget.request.initialBack);
  late final _term = TextEditingController(text: widget.request.initialTerm);
  late final _definition = TextEditingController(
    text: widget.request.initialDefinition,
  );

  late CardCreatorKind _kind = widget.request.initialKind;
  CognitiveType _cognitiveType = CognitiveType.fact;
  final _drafts = <_CardDraft>[];
  List<_AiSuggestion>? _suggestions;
  final _retiredSuggestions = <_AiSuggestion>[];
  String? _aiError;
  bool _aiLoading = false;
  bool _saving = false;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _term.dispose();
    _definition.dispose();
    for (final suggestion in _suggestions ?? const <_AiSuggestion>[]) {
      suggestion.dispose();
    }
    for (final suggestion in _retiredSuggestions) {
      suggestion.dispose();
    }
    super.dispose();
  }

  bool get _hasAiContext =>
      widget.request.note != null || widget.request.error != null;

  bool get _canAdd => _kind == CardCreatorKind.basic
      ? _front.text.trim().isNotEmpty && _back.text.trim().isNotEmpty
      : _term.text.trim().isNotEmpty && _definition.text.trim().isNotEmpty;

  LitmusReport get _currentReport => _kind == CardCreatorKind.basic
      ? checkCardLitmus(
          front: _front.text,
          back: _back.text,
          cognitiveType: _cognitiveType,
        )
      : checkCardLitmus(
          front: _term.text,
          back: _definition.text,
          cognitiveType: CognitiveType.concept,
        );

  void _addDraft() {
    if (!_canAdd || _saving) return;
    setState(() {
      if (_kind == CardCreatorKind.basic) {
        _drafts.add(
          _BasicDraft(
            front: _front.text.trim(),
            back: _back.text.trim(),
            cognitiveType: _cognitiveType,
          ),
        );
        _front.clear();
        _back.clear();
      } else {
        _drafts.add(
          _ConceptDraft(
            term: _term.text.trim(),
            definition: _definition.text.trim(),
          ),
        );
        _term.clear();
        _definition.clear();
      }
    });
  }

  void _removeDraft(int index) {
    if (_saving || index < 0 || index >= _drafts.length) return;
    setState(() => _drafts.removeAt(index));
  }

  Future<void> _loadAiSuggestions() async {
    if (_aiLoading || _saving) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _retiredSuggestions.addAll(_suggestions ?? const []);
      _suggestions = null;
    });
    try {
      final lookup = ref.read(lookupServiceProvider);
      final List<SuggestedCard> cards;
      final error = widget.request.error;
      final note = widget.request.note;
      if (error != null) {
        cards = await lookup.breakdownErrorCard(
          question: error.question,
          wrongAnswer: error.wrongAnswer,
          correctAnswer: error.correctAnswer,
          reasoning: error.reasoning,
          explanation: error.explanation,
          topicName: widget.request.topicName,
          subtopic: widget.request.subtopic,
          mistakeKinds: error.card.mistakeKinds,
        );
      } else if (note != null) {
        cards = await lookup.suggestArchetypeCards(
          highlight: note.text,
          questionContext: widget.request.questionContext,
          topicName: widget.request.topicName,
          subtopic: widget.request.subtopic,
        );
      } else {
        cards = const [];
      }
      if (!mounted) return;
      setState(() {
        _suggestions = [for (final card in cards) _AiSuggestion(card)];
        _aiLoading = false;
      });
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error.message;
        _aiLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = 'Could not suggest cards: $error';
        _aiLoading = false;
      });
    }
  }

  void _addSelectedSuggestions() {
    final suggestions = _suggestions;
    if (suggestions == null || _saving) return;
    final chosen = [
      for (final suggestion in suggestions)
        if (suggestion.selected) suggestion,
    ];
    if (chosen.isEmpty) return;
    setState(() {
      for (final suggestion in chosen) {
        _drafts.add(
          _BasicDraft(
            front: suggestion.front.text.trim(),
            back: suggestion.back.text.trim(),
            cognitiveType: suggestion.suggestion.cognitiveType,
          ),
        );
      }
      _suggestions = [
        for (final suggestion in suggestions)
          if (!suggestion.selected) suggestion,
      ];
      _retiredSuggestions.addAll(chosen);
    });
  }

  Future<void> _applySideEffects({int? manualCardId}) async {
    final service = ref.read(reviewServiceProvider);
    final note = widget.request.note;
    if (note != null) {
      await service.markHighlightConverted(note.id, manualCardId: manualCardId);
    }
    final error = widget.request.error;
    if (error != null) {
      await service.completeErrorDetails(error.card.id);
    }
  }

  Future<void> _save() async {
    if (_drafts.isEmpty || _saving) return;
    setState(() => _saving = true);
    final service = ref.read(reviewServiceProvider);
    final request = widget.request;
    final pending = List<_CardDraft>.of(_drafts);
    var created = 0;
    int? manualCardId;
    Object? failure;
    for (final draft in pending) {
      try {
        switch (draft) {
          case _BasicDraft():
            final id = await service.createBasicCard(
              sessionId: request.sessionId,
              questionId: request.questionId,
              question: draft.front,
              answer: draft.back,
              context: request.questionContext,
              topicName: request.topicName,
              subtopic: request.subtopic,
              cognitiveType: draft.cognitiveType,
              skippedQuestionId: request.skippedQuestionId,
            );
            manualCardId ??= id;
          case _ConceptDraft():
            await service.createConcept(
              sessionId: request.sessionId,
              questionId: request.questionId,
              term: draft.term,
              definition: draft.definition,
              context: request.questionContext,
              topicName: request.topicName,
              subtopic: request.subtopic,
              source: ConceptSource.manual,
              skippedQuestionId: request.skippedQuestionId,
            );
        }
        created++;
        if (mounted) setState(() => _drafts.remove(draft));
      } on Object catch (error) {
        failure = error;
        break;
      }
    }

    if (created > 0) {
      try {
        await _applySideEffects(manualCardId: manualCardId);
      } on Object catch (error) {
        failure ??= error;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      await showSnack(
        context,
        created > 0
            ? '$created card${created == 1 ? '' : 's'} saved, but the rest '
                  'could not be saved: $failure'
            : 'Could not create the cards: $failure',
      );
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final request = widget.request;
    final hasKey = ref.watch(hasApiKeyProvider).value ?? false;
    final count = _drafts.length;
    final hasContext =
        request.error != null ||
        request.note != null ||
        request.skippedQuestionId != null ||
        request.questionContext.trim().isNotEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const ValueKey('creator-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      request.title,
                      style: theme.typography.emphasized.titleLarge,
                    ),
                  ),
                ),
                M3EIconButton(
                  key: const ValueKey('creator-close'),
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close card creator',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasContext) ...[
              _CreatorContextRecap(request: request),
              const SizedBox(height: 20),
            ],
            Text('Card type', style: theme.typography.emphasized.titleSmall),
            const SizedBox(height: 8),
            M3ESegmentedButton<CardCreatorKind>(
              key: const ValueKey('creator-kind'),
              segments: const [
                M3ESegment(value: CardCreatorKind.basic, label: 'Basic'),
                M3ESegment(value: CardCreatorKind.concept, label: 'Concept'),
              ],
              selected: {_kind},
              enabled: !_saving,
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(() => _kind = values.first);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_kind == CardCreatorKind.basic) ...[
              M3ETextField(
                key: const ValueKey('creator-front'),
                controller: _front,
                label: 'Front',
                placeholder: 'A short question',
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              M3ETextField(
                key: const ValueKey('creator-back'),
                controller: _back,
                label: 'Back',
                placeholder: 'One atomic answer',
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Cognitive type',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              M3ETheme(
                data: theme.copyWith(
                  chipTheme: theme.chipTheme.copyWith(height: 48),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in const [
                      CognitiveType.fact,
                      CognitiveType.heuristic,
                      CognitiveType.contrast,
                    ])
                      M3EChip(
                        key: ValueKey('creator-type-${type.name}'),
                        type: M3EChipType.filter,
                        label: type.label,
                        selected: _cognitiveType == type,
                        onPressed: _saving
                            ? null
                            : () => setState(() => _cognitiveType = type),
                      ),
                  ],
                ),
              ),
              if (_cognitiveType == CognitiveType.heuristic) ...[
                const SizedBox(height: 12),
                TonalBox(
                  key: const ValueKey('creator-heuristic-template'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    'Heuristic template: "Given requirement X with restriction Y, '
                    'what rule applies?" → answer with one atomic rule.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ] else ...[
              M3ETextField(
                key: const ValueKey('creator-term'),
                controller: _term,
                label: 'Term',
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              M3ETextField(
                key: const ValueKey('creator-definition'),
                controller: _definition,
                label: 'Definition',
                minLines: 2,
                maxLines: 4,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            _LitmusRow(
              report: _currentReport,
              badgeKey: const ValueKey('creator-litmus-current'),
              detailKey: const ValueKey('creator-litmus-detail-current'),
            ),
            const SizedBox(height: 12),
            M3EButton.tonal(
              key: const ValueKey('creator-add'),
              onPressed: _canAdd && !_saving ? _addDraft : null,
              icon: const Icon(Icons.add_card),
              label: const Text('Add card'),
            ),
            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle('Cards to save', count: _drafts.length),
              AppGroup(
                semanticsLabel: 'Cards waiting to be saved',
                children: [
                  for (var index = 0; index < _drafts.length; index++)
                    _DraftRow(
                      key: ValueKey('creator-draft-$index'),
                      draft: _drafts[index],
                      onRemove: _saving ? null : () => _removeDraft(index),
                    ),
                ],
              ),
            ],
            if (_hasAiContext) ...[
              const SizedBox(height: 28),
              SectionTitle(
                'Suggest with AI',
                supporting:
                    'Optional. Write cards by hand above, or let the AI propose '
                    'some to review.',
              ),
              if (!hasKey)
                TonalBox(
                  key: const ValueKey('creator-ai-unavailable'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    'AI is optional. Add an API key in Settings to suggest cards; '
                    'manual cards work without one.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                )
              else ...[
                if (_aiLoading)
                  TonalBox(
                    key: const ValueKey('creator-ai-loading'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        const M3ELoadingIndicator(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Suggesting cards…',
                            style: theme.typography.baseline.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_aiError != null) ...[
                  TonalBox(
                    key: const ValueKey('creator-ai-error'),
                    color: theme.colorScheme.errorContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _aiError!,
                          style: theme.typography.baseline.bodyMedium.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                        if (_aiError!.toLowerCase().contains('settings')) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Open Settings to add an AI provider and key.',
                            style: theme.typography.baseline.labelSmall
                                .copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  M3EButton.tonal(
                    key: const ValueKey('creator-ai-retry'),
                    onPressed: _saving ? null : _loadAiSuggestions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ] else if (_suggestions == null)
                  M3EButton.tonal(
                    key: const ValueKey('creator-ai-suggest'),
                    onPressed: _saving ? null : _loadAiSuggestions,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Suggest with AI'),
                  )
                else if (_suggestions!.isEmpty)
                  TonalBox(
                    key: const ValueKey('creator-ai-empty'),
                    child: Text(
                      'The AI found no new cards here.',
                      style: theme.typography.baseline.bodyMedium.copyWith(
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < _suggestions!.length; index++)
                        _AiSuggestionTile(
                          key: ValueKey('creator-ai-$index'),
                          index: index,
                          suggestion: _suggestions![index],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _suggestions![index].selected = value;
                                }),
                          onTextChanged: () => setState(() {}),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          M3EButton.text(
                            key: const ValueKey('creator-ai-clear'),
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _retiredSuggestions.addAll(_suggestions!);
                                    _suggestions = null;
                                  }),
                            child: const Text('Clear suggestions'),
                          ),
                          M3EButton.filled(
                            key: const ValueKey('creator-ai-add'),
                            onPressed:
                                _saving ||
                                    _suggestions!.every(
                                      (item) => !item.selected,
                                    )
                                ? null
                                : _addSelectedSuggestions,
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add selected to list'),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              key: const ValueKey('creator-save'),
              onPressed: count == 0 || _saving ? null : _save,
              label: _saving
                  ? 'Saving…'
                  : 'Save $count card${count == 1 ? '' : 's'}',
              icon: Icons.check,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CreatorContextRecap extends StatelessWidget {
  const _CreatorContextRecap({required this.request});

  final CardCreatorRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final error = request.error;
    final note = request.note;
    final topicPills = <Widget>[
      if (request.topicName.trim().isNotEmpty) Pill(request.topicName),
      if (request.subtopic.trim().isNotEmpty)
        Pill(request.subtopic, tone: PillTone.secondary),
    ];

    final List<Widget> fields;
    if (error != null) {
      fields = [
        _RecapLabel('From this error'),
        const SizedBox(height: 4),
        Text(
          error.question.trim().isEmpty
              ? request.questionContext.trim()
              : error.question.trim(),
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        const SizedBox(height: 10),
        _RecapField(
          label: 'Wrong answer chosen',
          value: error.wrongAnswer.trim(),
          valueColor: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        _RecapField(label: 'Correct answer', value: error.correctAnswer.trim()),
        if (error.card.mistakeKinds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final kind in error.card.mistakeKinds)
                Pill(kind.label, tone: PillTone.secondary),
            ],
          ),
        ],
      ];
    } else if (note != null) {
      fields = [
        _RecapLabel('From this note'),
        const SizedBox(height: 4),
        Text(
          note.text.trim(),
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        if (request.questionContext.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecapField(
            label: 'The question',
            value: request.questionContext.trim(),
          ),
        ],
      ];
    } else if (request.skippedQuestionId != null) {
      final prompt = request.questionContext.trim().isEmpty
          ? request.initialFront.trim()
          : request.questionContext.trim();
      fields = [
        _RecapLabel('Skipped question'),
        const SizedBox(height: 4),
        Text(
          prompt,
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        if (request.initialBack.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecapField(
            label: 'Correct answer',
            value: request.initialBack.trim(),
          ),
        ],
      ];
    } else {
      fields = [
        _RecapLabel('From the question'),
        const SizedBox(height: 4),
        Text(
          request.questionContext.trim(),
          style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
        ),
      ];
    }

    return TonalBox(
      key: const ValueKey('creator-context'),
      padding: const EdgeInsets.all(14),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...fields,
            if (topicPills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: topicPills),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecapLabel extends StatelessWidget {
  const _RecapLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Text(
      text,
      style: theme.typography.baseline.labelSmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RecapField extends StatelessWidget {
  const _RecapField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecapLabel(label),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.typography.baseline.bodySmall.copyWith(
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft, required this.onRemove, super.key});

  final _CardDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final (title, body, badge, report) = switch (draft) {
      _BasicDraft(:final front, :final back, :final cognitiveType) => (
        front,
        back,
        cognitiveType.label,
        checkCardLitmus(front: front, back: back, cognitiveType: cognitiveType),
      ),
      _ConceptDraft(:final term, :final definition) => (
        term,
        definition,
        'Concept',
        checkCardLitmus(
          front: term,
          back: definition,
          cognitiveType: CognitiveType.concept,
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.baseline.titleSmall.copyWith(
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(badge, tone: PillTone.secondary),
                    _LitmusBadge(report: report),
                  ],
                ),
                if (!report.isClean) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.detail,
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove card',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AiSuggestionTile extends StatelessWidget {
  const _AiSuggestionTile({
    required this.index,
    required this.suggestion,
    required this.onChanged,
    required this.onTextChanged,
    super.key,
  });

  final int index;
  final _AiSuggestion suggestion;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    final report = suggestion.report;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TonalBox(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ECheckbox(
              key: ValueKey('creator-ai-select-$index'),
              value: suggestion.selected,
              semanticLabel: 'Select suggested card',
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
                        key: ValueKey('creator-ai-type-$index'),
                        suggestion.suggestion.cognitiveType.label,
                        tone: PillTone.primary,
                      ),
                      _LitmusBadge(
                        key: ValueKey('creator-ai-litmus-$index'),
                        report: report,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  M3ETextField(
                    key: ValueKey('creator-ai-front-$index'),
                    controller: suggestion.front,
                    label: 'Front',
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => onTextChanged(),
                  ),
                  const SizedBox(height: 8),
                  M3ETextField(
                    key: ValueKey('creator-ai-back-$index'),
                    controller: suggestion.back,
                    label: 'Back',
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => onTextChanged(),
                  ),
                  if (!report.isClean) ...[
                    const SizedBox(height: 6),
                    Text(
                      report.detail,
                      key: ValueKey('creator-ai-litmus-detail-$index'),
                      style: M3ETheme.of(context).typography.baseline.labelSmall
                          .copyWith(
                            color: M3ETheme.of(context).colorScheme.error,
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

class _LitmusRow extends StatelessWidget {
  const _LitmusRow({
    required this.report,
    required this.badgeKey,
    required this.detailKey,
  });

  final LitmusReport report;
  final Key badgeKey;
  final Key detailKey;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Card quality',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            _LitmusBadge(key: badgeKey, report: report),
          ],
        ),
        if (!report.isClean) ...[
          const SizedBox(height: 4),
          Text(
            report.detail,
            key: detailKey,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.error,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _LitmusBadge extends StatelessWidget {
  const _LitmusBadge({required this.report, super.key});

  final LitmusReport report;

  @override
  Widget build(BuildContext context) {
    final clean = report.isClean;
    return Tooltip(
      message: clean ? 'Passes the card quality checks' : report.detail,
      child: Pill(
        clean ? 'Ready' : 'Check quality',
        tone: clean ? PillTone.success : PillTone.error,
        icon: clean ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      ),
    );
  }
}
