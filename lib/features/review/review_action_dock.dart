import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

/// Shared bottom action dock for every review surface.
///
/// The same controls sit in the same relative order on end-of-session review,
/// error review, skipped review and note review:
/// back, create cards, optional delete, the single Save action, forward.
/// Compact widths stack the Save action under the icon row so 320 dp and
/// large text never overflow.
class ReviewActionDock extends StatelessWidget {
  const ReviewActionDock({
    required this.saveLabel,
    required this.onSave,
    required this.onBack,
    required this.onNext,
    required this.onCreateCards,
    this.onDelete,
    this.canGoBack = false,
    this.canGoNext = true,
    this.busy = false,
    super.key,
  });

  final String saveLabel;
  final VoidCallback? onSave;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onCreateCards;
  final VoidCallback? onDelete;
  final bool canGoBack;
  final bool canGoNext;
  final bool busy;

  static const backKey = ValueKey<String>('review-dock-back');
  static const createKey = ValueKey<String>('review-dock-create');
  static const deleteKey = ValueKey<String>('review-dock-delete');
  static const saveKey = ValueKey<String>('review-dock-save');
  static const nextKey = ValueKey<String>('review-dock-next');

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final icons = Row(
      children: [
        AppDockIconButton(
          key: backKey,
          icon: Icons.arrow_back,
          tooltip: 'Previous',
          onPressed: busy || !canGoBack ? null : onBack,
        ),
        AppDockIconButton(
          key: createKey,
          icon: Icons.add_card,
          tooltip: 'Create cards',
          onPressed: busy ? null : onCreateCards,
        ),
        if (onDelete != null)
          AppDockIconButton(
            key: deleteKey,
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            isDestructive: true,
            onPressed: busy ? null : onDelete,
          ),
        const Spacer(),
        AppDockIconButton(
          key: nextKey,
          icon: Icons.arrow_forward,
          tooltip: 'Next',
          onPressed: busy || !canGoNext ? null : onNext,
        ),
      ],
    );
    final save = AppPrimaryButton(
      key: saveKey,
      onPressed: busy ? null : onSave,
      label: busy ? 'Saving…' : saveLabel,
      icon: Icons.check,
    );

    return AppActionDock(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520 || textScale > 1.3;
          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [icons, const SizedBox(height: 6), save],
            );
          }
          return Row(
            children: [
              AppDockIconButton(
                key: backKey,
                icon: Icons.arrow_back,
                tooltip: 'Previous',
                onPressed: busy || !canGoBack ? null : onBack,
              ),
              AppDockIconButton(
                key: createKey,
                icon: Icons.add_card,
                tooltip: 'Create cards',
                onPressed: busy ? null : onCreateCards,
              ),
              if (onDelete != null)
                AppDockIconButton(
                  key: deleteKey,
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  isDestructive: true,
                  onPressed: busy ? null : onDelete,
                ),
              const SizedBox(width: 8),
              Expanded(child: save),
              AppDockIconButton(
                key: nextKey,
                icon: Icons.arrow_forward,
                tooltip: 'Next',
                onPressed: busy || !canGoNext ? null : onNext,
              ),
            ],
          );
        },
      ),
    );
  }
}
