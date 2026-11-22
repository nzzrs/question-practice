import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

/// Shared bottom action dock for every review surface.
///
/// Notes, errors, skipped questions and concepts all use the same
/// `back · Save · forward` row. Saving is the only primary action; backward
/// and forward move between items, and the arrows disable at the ends so a
/// review can never leave its first or last item by accident.
///
/// The row stays side by side at every width. The primary button keeps the
/// remaining space and wraps to two lines at large text sizes, so 320 dp and
/// 2x text never overflow.
class ReviewActionDock extends StatelessWidget {
  const ReviewActionDock({
    required this.saveLabel,
    required this.onSave,
    required this.onBack,
    required this.onNext,
    required this.canGoBack,
    required this.canGoNext,
    this.busy = false,
    super.key,
  });

  final String saveLabel;
  final VoidCallback? onSave;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool canGoBack;
  final bool canGoNext;
  final bool busy;

  static const backKey = ValueKey<String>('review-dock-back');
  static const saveKey = ValueKey<String>('review-dock-save');
  static const nextKey = ValueKey<String>('review-dock-next');

  @override
  Widget build(BuildContext context) {
    return AppActionDock(
      child: Row(
        children: [
          AppDockIconButton(
            key: backKey,
            icon: Icons.arrow_back,
            tooltip: 'Previous',
            onPressed: busy || !canGoBack ? null : onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppPrimaryButton(
              key: saveKey,
              onPressed: busy ? null : onSave,
              label: busy ? 'Saving…' : saveLabel,
              icon: Icons.check,
            ),
          ),
          const SizedBox(width: 8),
          AppDockIconButton(
            key: nextKey,
            icon: Icons.arrow_forward,
            tooltip: 'Next',
            onPressed: busy || !canGoNext ? null : onNext,
          ),
        ],
      ),
    );
  }
}
