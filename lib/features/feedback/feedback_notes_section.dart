import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';

/// Notes saved for the reviewed question, with Copy and card actions.
///
/// Lives inside the feedback selection area; its rows are plain selectable
/// text plus ordinary buttons, never a nested SelectionArea.
class FeedbackNotesSection extends StatelessWidget {
  const FeedbackNotesSection({
    required this.notes,
    required this.onCopy,
    required this.onCreateCard,
    this.onOverflow,
    super.key,
  });

  final List<Note> notes;
  final ValueChanged<Note> onCopy;
  final ValueChanged<Note> onCreateCard;
  final ValueChanged<Note>? onOverflow;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = M3ETheme.of(context);
    return Column(
      key: const ValueKey('feedback-notes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          'Notes for this question',
          style: theme.typography.emphasized.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < notes.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TonalBox(
              key: ValueKey('feedback-note-${notes[index].id}'),
              color: theme.colorScheme.surfaceContainerLow,
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${notes[index].text.trim()}”',
                    style: theme.typography.baseline.bodyMedium.copyWith(
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      M3EChip(
                        key: ValueKey('feedback-note-copy-${notes[index].id}'),
                        type: M3EChipType.assist,
                        leading: const Icon(Icons.copy_all_outlined),
                        label: 'Copy',
                        onPressed: () => onCopy(notes[index]),
                      ),
                      M3EChip(
                        key: ValueKey('feedback-note-card-${notes[index].id}'),
                        type: M3EChipType.assist,
                        leading: Icon(
                          notes[index].hasCard
                              ? Icons.check
                              : Icons.auto_awesome_outlined,
                        ),
                        label: notes[index].hasCard
                            ? 'Card created'
                            : 'Create card with AI',
                        onPressed: notes[index].hasCard
                            ? null
                            : () => onCreateCard(notes[index]),
                      ),
                      if (onOverflow != null)
                        M3EIconButton(
                          key: ValueKey(
                            'feedback-note-more-${notes[index].id}',
                          ),
                          variant: M3EIconButtonVariant.standard,
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Note actions',
                          onPressed: () => onOverflow!(notes[index]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
