import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';
import '../practice/selectable_linkified_text.dart';
import 'feedback_actions.dart';
import 'row_action_menu.dart';

enum _BulletRowAction { copy, createCard }

/// Read-only bullet list used by the error review.
class WrongAnswerBulletsReadonly extends StatelessWidget {
  const WrongAnswerBulletsReadonly({
    required this.bullets,
    required this.actions,
    this.onTurnBulletIntoCard,
    this.bulletBusy = false,
    this.activeBulletId,
    this.addedBulletIds = const {},
    super.key,
  });

  final List<String> bullets;
  final FeedbackActions actions;
  final void Function(String bulletId, String bullet)? onTurnBulletIntoCard;
  final bool bulletBusy;
  final String? activeBulletId;
  final Set<String> addedBulletIds;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      key: const ValueKey('wrong-answer-bullets-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What went wrong?', style: theme.typography.emphasized.titleSmall),
        const SizedBox(height: 8),
        if (bullets.isEmpty)
          Text(
            'Nothing was written for this attempt.',
            key: const ValueKey('wrong-answer-bullets-empty'),
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0; index < bullets.length; index++)
            Builder(
              builder: (context) {
                final bulletId = '$index';
                final added = addedBulletIds.contains(bulletId);
                final active = activeBulletId == bulletId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    key: ValueKey('wrong-answer-bullets-readonly-$index'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 14),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: SelectableLinkifiedText(
                            text: bullets[index],
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
                      ),
                      const SizedBox(width: 4),
                      RowActionMenu<_BulletRowAction>(
                        menuKey: ValueKey('wrong-answer-bullets-more-$index'),
                        tooltip: 'Bullet actions',
                        items: [
                          RowActionItem(
                            value: _BulletRowAction.copy,
                            label: 'Copy',
                            icon: Icons.copy_all_outlined,
                            key: ValueKey('wrong-answer-bullets-copy-$index'),
                          ),
                          if (onTurnBulletIntoCard != null)
                            RowActionItem(
                              value: _BulletRowAction.createCard,
                              label: added
                                  ? 'Card created'
                                  : 'Create card with AI',
                              icon: added
                                  ? Icons.check
                                  : active
                                  ? Icons.hourglass_top
                                  : Icons.auto_awesome_outlined,
                              key: ValueKey('wrong-answer-bullets-card-$index'),
                              enabled: !added && !bulletBusy,
                            ),
                        ],
                        onSelected: (action) {
                          switch (action) {
                            case _BulletRowAction.copy:
                              _copy(context, bullets[index]);
                            case _BulletRowAction.createCard:
                              onTurnBulletIntoCard?.call(
                                bulletId,
                                bullets[index],
                              );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) await showSnack(context, 'Bullet copied.');
  }
}
