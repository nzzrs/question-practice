import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../lookup/domain/lookup_service.dart';
import 'domain/card_litmus.dart';

/// Opens the shared AI suggestion sheet for [highlight].
///
/// Returns the number of atomic cards added, or zero when the learner closes
/// the sheet without adding any. A snackbar reports the count so both the
/// end-of-session review and Cards behave the same way.
Future<int> suggestCardsFromHighlight(
  BuildContext context,
  StudyHighlight highlight,
) async {
  final added = await M3EBottomSheet.show<int>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => SuggestedCardsSheet(highlight: highlight),
  );
  final count = added ?? 0;
  if (count > 0 && context.mounted) {
    await showSnack(
      context,
      '$count card${count == 1 ? '' : 's'} added from the highlight.',
    );
  }
  return count;
}

/// Lists the AI's atomic card suggestions and adds the checked ones.
class SuggestedCardsSheet extends ConsumerStatefulWidget {
  const SuggestedCardsSheet({required this.highlight, super.key});

  final StudyHighlight highlight;

  @override
  ConsumerState<SuggestedCardsSheet> createState() =>
      _SuggestedCardsSheetState();
}

class _SuggestedCardsSheetState extends ConsumerState<SuggestedCardsSheet> {
  List<SuggestedCard>? _cards;
  final _selected = <int>{};
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _cards = null;
      _selected.clear();
    });
    try {
      final cards = await ref
          .read(lookupServiceProvider)
          .suggestArchetypeCards(
            highlight: widget.highlight.text,
            questionContext: widget.highlight.context,
            topicName: widget.highlight.topicName,
            subtopic: widget.highlight.subtopic,
          );
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _selected.addAll([
          for (var index = 0; index < cards.length; index++) index,
        ]);
      });
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not suggest cards: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> _indexesFor(CognitiveType type) {
    final cards = _cards;
    if (cards == null) return const [];
    return [
      for (var index = 0; index < cards.length; index++)
        if (cards[index].cognitiveType == type) index,
    ];
  }

  Future<void> _addSelected() async {
    final cards = _cards;
    if (cards == null || _selected.isEmpty || _saving) return;
    final indexes = _selected.toList()..sort();
    setState(() => _saving = true);
    try {
      final service = ref.read(reviewServiceProvider);
      int? firstCardId;
      var added = 0;
      for (final index in indexes) {
        final suggestion = cards[index];
        final id = await service.createBasicCard(
          sessionId: widget.highlight.sessionId,
          questionId: widget.highlight.questionId,
          question: suggestion.front,
          answer: suggestion.back,
          context: widget.highlight.context,
          topicName: widget.highlight.topicName,
          cognitiveType: suggestion.cognitiveType,
          subtopic: widget.highlight.subtopic,
        );
        firstCardId ??= id;
        added++;
      }
      if (added == 0) return;
      await service.markHighlightConverted(
        widget.highlight.id,
        manualCardId: firstCardId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(added);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not add the cards: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested cards with AI',
              style: theme.typography.emphasized.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'One fact per card. Check the ones to add.',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TonalBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                widget.highlight.text,
                style: theme.typography.baseline.bodyMedium.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: M3ELoadingIndicator()),
              )
            else if (_error != null) ...[
              TonalBox(
                key: const ValueKey('suggested-cards-error'),
                color: theme.colorScheme.errorContainer,
                child: Text(
                  _error!,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              M3EButton.tonal(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ] else if (_cards == null || _cards!.isEmpty) ...[
              TonalBox(
                key: const ValueKey('suggested-cards-empty'),
                child: Text(
                  'The AI found no new cards in this highlight.',
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              M3EButton.tonal(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ] else ...[
              for (final type in const [
                CognitiveType.heuristic,
                CognitiveType.fact,
                CognitiveType.contrast,
                CognitiveType.concept,
              ])
                if (_indexesFor(type).isNotEmpty) ...[
                  _SuggestionGroupHeading(
                    label: _groupLabel(type),
                    count: _indexesFor(type).length,
                    type: type,
                  ),
                  for (final index in _indexesFor(type))
                    _SuggestionTile(
                      key: ValueKey('suggested-card-$index'),
                      card: _cards![index],
                      selected: _selected.contains(index),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              if (value) {
                                _selected.add(index);
                              } else {
                                _selected.remove(index);
                              }
                            }),
                    ),
                ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  M3EButton.text(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(0),
                    child: const Text('Cancel'),
                  ),
                  M3EButton.filled(
                    onPressed: _saving || _selected.isEmpty
                        ? null
                        : _addSelected,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? 'Adding…'
                          : 'Add ${_selected.length} card${_selected.length == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SuggestionGroupHeading extends StatelessWidget {
  const _SuggestionGroupHeading({
    required this.label,
    required this.count,
    required this.type,
  });

  final String label;
  final int count;
  final CognitiveType type;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      key: ValueKey('suggested-group-${type.name}'),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.typography.emphasized.titleSmall),
          ),
          Text(
            '$count',
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _groupLabel(CognitiveType type) => switch (type) {
  CognitiveType.heuristic => 'Procedures & rules',
  CognitiveType.fact => 'Atomic facts',
  CognitiveType.contrast => 'Contrasts',
  CognitiveType.concept => 'Concepts',
};

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.report});

  final LitmusReport report;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (report.isClean) {
      return const Pill(
        'Ready',
        tone: PillTone.success,
        icon: Icons.check_circle_outline,
      );
    }
    return Tooltip(
      message: report.detail,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 13,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                report.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.card,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final SuggestedCard card;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final litmus = checkCardLitmus(
      front: card.front,
      back: card.back,
      cognitiveType: card.cognitiveType,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TonalBox(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ECheckbox(
              value: selected,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.front,
                    style: theme.typography.baseline.titleSmall.copyWith(
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.back,
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
                      Pill(card.cognitiveType.label),
                      _QualityBadge(report: litmus),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
