import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../practice/selectable_linkified_text.dart';
import 'feedback_actions.dart';

/// Read-only bullet list used by the error review.
class WrongNotesReadonly extends StatelessWidget {
  const WrongNotesReadonly({
    required this.notes,
    required this.actions,
    this.onTurnBulletIntoCard,
    this.bulletBusy = false,
    this.activeBulletId,
    this.addedBulletIds = const {},
    super.key,
  });

  final List<String> notes;
  final FeedbackActions actions;
  final void Function(String bulletId, String note)? onTurnBulletIntoCard;
  final bool bulletBusy;
  final String? activeBulletId;
  final Set<String> addedBulletIds;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      key: const ValueKey('wrong-notes-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What went wrong?', style: theme.typography.emphasized.titleSmall),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          Text(
            'Nothing was written for this attempt.',
            key: const ValueKey('wrong-notes-empty'),
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0; index < notes.length; index++)
            Builder(
              builder: (context) {
                final bulletId = '$index';
                final added = addedBulletIds.contains(bulletId);
                final active = activeBulletId == bulletId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        key: ValueKey('wrong-notes-readonly-$index'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 8),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableLinkifiedText(
                              text: notes[index],
                              style: theme.typography.baseline.bodyMedium
                                  .copyWith(height: 1.45),
                              useSelectionArea: false,
                              onDefine: actions.onDefine,
                              onOpenUrl: actions.onOpenUrl,
                              onNote: actions.onSaveNote,
                              onAsk: actions.onAsk,
                              onNoteTap: actions.onNoteTap,
                            ),
                          ),
                        ],
                      ),
                      if (onTurnBulletIntoCard != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, top: 2),
                          child: Semantics(
                            button: true,
                            label: added
                                ? 'Bullet added to cards'
                                : active
                                ? 'Drafting a card from this bullet'
                                : 'Turn this bullet into a card',
                            child: M3EButton.tonal(
                              key: ValueKey('wrong-note-card-$index'),
                              size: M3EButtonSize.md,
                              onPressed: bulletBusy && !active
                                  ? null
                                  : () => onTurnBulletIntoCard!(
                                      bulletId,
                                      notes[index],
                                    ),
                              icon: Icon(
                                added
                                    ? Icons.check
                                    : active
                                    ? Icons.hourglass_top
                                    : Icons.add_card,
                              ),
                              label: Text(
                                added
                                    ? 'Added to cards'
                                    : active
                                    ? 'Drafting…'
                                    : 'Turn bullet into card',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}
