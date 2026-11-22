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
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReviewCreateFab(onPressed: busy ? null : onCreateCards),
          ReviewActionDock(
            busy: busy,
            saveLabel: saveLabel,
            onSave: onSave,
            onBack: onBack,
            onNext: onNext,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
          ),
        ],
      ),
      children: children,
    );
  }
}

/// The one create-cards action on every review surface.
///
/// It floats above the dock, is icon-only with a tooltip and semantics, and
/// steps up while a snackbar is showing so validation feedback never covers
/// it. The bottom bar is hidden with the keyboard, so it can never overlap the
/// soft keyboard either.
class ReviewCreateFab extends StatefulWidget {
  const ReviewCreateFab({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  static const fabKey = ValueKey<String>('review-create-fab');

  @override
  State<ReviewCreateFab> createState() => _ReviewCreateFabState();
}

class _ReviewCreateFabState extends State<ReviewCreateFab> {
  bool _snackbarShowing = false;

  @override
  void initState() {
    super.initState();
    _snackbarShowing = M3ESnackbar.defaultController.isShowing;
    M3ESnackbar.defaultController.addListener(_onSnackbarChanged);
  }

  @override
  void dispose() {
    M3ESnackbar.defaultController.removeListener(_onSnackbarChanged);
    super.dispose();
  }

  void _onSnackbarChanged() {
    final showing = M3ESnackbar.defaultController.isShowing;
    if (showing == _snackbarShowing) return;
    setState(() => _snackbarShowing = showing);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final lift = _snackbarShowing ? 24 + 48 * textScale : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: lift),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, value, child) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8 + value),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: child),
      ),
      child: M3EFab(
        key: ReviewCreateFab.fabKey,
        icon: const Icon(Icons.add_card),
        size: M3EFabSize.regular,
        color: M3EFabColor.secondary,
        tooltip: 'Create cards',
        onPressed: widget.onPressed,
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
