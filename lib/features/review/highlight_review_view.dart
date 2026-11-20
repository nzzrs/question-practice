import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';

/// Shared reading surface for one saved highlight.
///
/// The end-of-session review and the Cards highlight review render the same
/// content: the highlighted phrase, the question it came from, its topic and
/// practice, and the card-making actions. Card-making actions disappear once a
/// card exists. [onKeep] and [onDelete] are optional so each surface can offer
/// only the actions its navigation already provides.
class HighlightReviewView extends StatelessWidget {
  const HighlightReviewView({
    required this.highlight,
    required this.onMakeCard,
    required this.onSuggestCards,
    this.onKeep,
    this.onDelete,
    super.key,
  });

  final StudyHighlight highlight;
  final VoidCallback onMakeCard;
  final VoidCallback onSuggestCards;
  final VoidCallback? onKeep;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final showCardActions = !highlight.hasCard;
    final showActions = onKeep != null || onDelete != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Pill('Highlight', tone: PillTone.primary),
                  if (highlight.topicName.trim().isNotEmpty)
                    Pill(highlight.topicName),
                  if (highlight.practiceName.trim().isNotEmpty)
                    Pill(highlight.practiceName),
                  if (highlight.isKept)
                    const Pill('Kept', tone: PillTone.success),
                  if (highlight.hasCard)
                    const Pill('Card made', tone: PillTone.success),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  highlight.text,
                  style: theme.typography.baseline.titleMedium.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (highlight.context.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'From the question',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  highlight.context,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (showCardActions) ...[
          Text(
            'Make a concept card, suggest atomic cards, or keep it for later.',
            style: theme.typography.emphasized.titleSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              M3EButton.tonal(
                key: const ValueKey('highlight-make-card'),
                onPressed: onMakeCard,
                icon: const Icon(Icons.style_outlined),
                label: const Text('Make concept card'),
              ),
              M3EButton.tonal(
                key: const ValueKey('highlight-suggest-cards'),
                onPressed: onSuggestCards,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Suggest cards with AI'),
              ),
            ],
          ),
        ] else
          TonalBox(
            key: const ValueKey('highlight-card-made'),
            child: Text(
              'A card was already made from this highlight. The saved phrase '
              'stays in Cards until you delete it.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        if (showActions) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (onKeep != null && !highlight.isKept)
                M3EButton.text(
                  key: const ValueKey('highlight-keep'),
                  onPressed: onKeep,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Keep for later'),
                    ],
                  ),
                ),
              if (onDelete != null)
                M3EButton.text(
                  key: const ValueKey('highlight-delete'),
                  onPressed: onDelete,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Delete highlight',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
