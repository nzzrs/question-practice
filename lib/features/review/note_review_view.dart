import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';

/// Shared reading surface for one saved note.
///
/// The end-of-session review and the Cards note review render the same
/// content: the note, the question it came from, its topic and practice, and
/// the create action. The create action disappears once a card exists.
/// [onKeep] and [onDelete] are optional so each surface can offer only the
/// actions its navigation already provides.
class NoteReviewView extends StatelessWidget {
  const NoteReviewView({
    required this.note,
    required this.onCreateCards,
    this.onKeep,
    this.onDelete,
    super.key,
  });

  final Note note;
  final VoidCallback onCreateCards;
  final VoidCallback? onKeep;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final showCardActions = !note.hasCard;
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
                  const Pill('Note', tone: PillTone.primary),
                  if (note.topicName.trim().isNotEmpty) Pill(note.topicName),
                  if (note.practiceName.trim().isNotEmpty)
                    Pill(note.practiceName),
                  if (note.isKept) const Pill('Kept', tone: PillTone.success),
                  if (note.hasCard)
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
                  note.text,
                  style: theme.typography.baseline.titleMedium.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (note.context.trim().isNotEmpty) ...[
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
                  note.context,
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
            'Create cards for this note, or keep it for later.',
            style: theme.typography.emphasized.titleSmall,
          ),
          const SizedBox(height: 12),
          M3EButton.tonal(
            key: const ValueKey('note-make-card'),
            onPressed: onCreateCards,
            icon: const Icon(Icons.add_card),
            label: const Text('Create cards'),
          ),
        ] else
          TonalBox(
            key: const ValueKey('note-card-made'),
            child: Text(
              'Cards were already made from this note. The saved text '
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
              if (onKeep != null && !note.isKept)
                M3EButton.text(
                  key: const ValueKey('note-keep'),
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
                  key: const ValueKey('note-delete'),
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
                        'Delete note',
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
