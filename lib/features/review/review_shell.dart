import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';
import 'review_action_dock.dart';

/// Shared chrome for every step of every review surface.
///
/// Notes, errors, skipped questions, concepts and the Cards reviews all render
/// the same immersive page, the same `back · Save · forward` dock and the same
/// create-cards floating action button. Hosts own only their step content and
/// save logic; navigation, layout and the create action stay identical.
class ReviewShell extends StatelessWidget {
  const ReviewShell({
    required this.title,
    required this.children,
    required this.saveLabel,
    required this.onSave,
    required this.onBack,
    required this.onNext,
    required this.canGoBack,
    required this.canGoNext,
    required this.onCreateCards,
    required this.onClose,
    this.busy = false,
    this.scrollController,
    this.body,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String saveLabel;
  final VoidCallback? onSave;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool canGoBack;
  final bool canGoNext;
  final VoidCallback? onCreateCards;
  final VoidCallback onClose;
  final bool busy;
  final ScrollController? scrollController;

  /// Replaces [children] when a step brings its own split or fixed body.
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: title,
      showBack: true,
      focus: true,
      onBack: onClose,
      scrollController: scrollController,
      variant: M3EAppBarVariant.small,
      body: body,
      floatingActionButton: ReviewCreateFab(
        onPressed: busy ? null : onCreateCards,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomBar: ReviewActionDock(
        busy: busy,
        saveLabel: saveLabel,
        onSave: onSave,
        onBack: onBack,
        onNext: onNext,
        canGoBack: canGoBack,
        canGoNext: canGoNext,
      ),
      children: children,
    );
  }
}

/// The one create-cards action on every review surface.
///
/// It sits in [AppPage]'s floating action slot, so the framework places it at
/// the end of the screen above the dock without any full-width bottom-bar
/// surface behind it. It is icon-only with a tooltip and semantics.
///
/// The M3E snackbar is an overlay that the scaffold cannot measure, so the
/// button steps up while a snackbar is visible; only the button moves, never a
/// background. The whole page hides the dock and this button with the
/// keyboard, so it can never overlap the soft keyboard either.
class ReviewCreateFab extends StatelessWidget {
  const ReviewCreateFab({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  static const fabKey = ValueKey<String>('review-create-fab');
  static const slotKey = ValueKey<String>('review-create-fab-slot');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: M3ESnackbar.defaultController,
      builder: (context, child) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final lift = M3ESnackbar.defaultController.isShowing
            ? 24 + 48 * textScale
            : 0.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: lift),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, value, child) => Padding(
            key: slotKey,
            padding: EdgeInsets.only(bottom: value),
            child: child,
          ),
          child: child,
        );
      },
      child: M3EFab(
        key: fabKey,
        icon: const Icon(Icons.add_card),
        size: M3EFabSize.regular,
        color: M3EFabColor.secondary,
        tooltip: 'Create cards',
        onPressed: onPressed,
      ),
    );
  }
}

/// Shared completion screen for every review surface.
class ReviewCompletionPage extends StatelessWidget {
  const ReviewCompletionPage({
    required this.title,
    required this.heading,
    required this.message,
    required this.onDone,
    this.scrollController,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String heading;
  final String message;
  final VoidCallback onDone;
  final ScrollController? scrollController;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AppPage(
      title: title,
      focus: true,
      onBack: onDone,
      scrollController: scrollController,
      variant: M3EAppBarVariant.small,
      children: [
        const SizedBox(height: 32),
        Center(child: IconBadge(Icons.check_circle_outline, size: 72)),
        const SizedBox(height: 16),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.typography.baseline.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        AppPrimaryButton(onPressed: onDone, label: 'Done', icon: Icons.check),
        for (final action in actions) ...[const SizedBox(height: 8), action],
      ],
    );
  }
}
