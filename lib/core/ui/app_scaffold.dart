import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Standard page shell: expressive sliver app bar, centered content column,
/// and an optional bottom action dock.
class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.children,
    this.titleWidget,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.variant = M3EAppBarVariant.largeFlexible,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.onBack,
    this.padding,
    this.maxWidth = 720,
    this.focus = false,
    this.scrollController,
    super.key,
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final bool showBack;
  final M3EAppBarVariant variant;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final VoidCallback? onBack;
  final EdgeInsets? padding;
  final double maxWidth;

  /// Hides the app bar for immersive reading and shows a slim exit row instead.
  ///
  /// Used by the review screens, where the card is the focus and the learner
  /// only needs a clear way back to the rest of the app.
  final bool focus;

  /// Optional controller for the scrolling content, used by stepped reviews to
  /// return to the top when the learner moves to another card.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 600 ? 24.0 : 20.0;
    final bottomInset = bottomBar == null
        ? 32 + MediaQuery.paddingOf(context).bottom
        : 24.0;
    final contentPadding =
        padding ?? EdgeInsets.fromLTRB(horizontal, 4, horizontal, bottomInset);
    final close = onBack ?? () => Navigator.of(context).maybePop();

    if (focus) {
      final tablet = width >= 600;
      final focusPadding =
          padding ??
          EdgeInsets.fromLTRB(
            tablet ? 24 : 12,
            4,
            tablet ? 24 : 12,
            bottomInset,
          );
      final content = CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPadding(
            padding: focusPadding,
            sliver: SliverList.list(children: children),
          ),
        ],
      );
      return PopScope(
        // Keep the system back gesture aligned with the visible close control,
        // including on the completion screen where closing reports success.
        canPop: onBack == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) close();
        },
        child: Scaffold(
          key: const ValueKey('app-focus-page'),
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _FocusHeader(title: title, onClose: close, actions: actions),
                Expanded(
                  child: tablet
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: content,
                          ),
                        )
                      : content,
                ),
                if (bottomBar != null) bottomBar!,
              ],
            ),
          ),
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              M3EAppBar.sliver(
                title: titleWidget,
                titleText: titleWidget == null ? title : null,
                subtitleText: subtitle,
                variant: variant,
                leading: showBack
                    ? M3EIconButton(
                        variant: M3EIconButtonVariant.standard,
                        icon: const Icon(M3EIcons.arrow_back),
                        tooltip: 'Back',
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
                actions: actions,
              ),
              SliverPadding(
                padding: contentPadding,
                sliver: SliverList.list(children: children),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Slim top row used by [AppPage] focus mode: one clear exit and the title.
class _FocusHeader extends StatelessWidget {
  const _FocusHeader({
    required this.title,
    required this.onClose,
    required this.actions,
  });

  final String title;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      key: const ValueKey('app-focus-header'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          M3EIconButton(
            key: const ValueKey('app-focus-exit'),
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.close),
            tooltip: 'Exit review',
            onPressed: onClose,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.emphasized.titleMedium,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A fixed bottom action area that never scrolls away from the user.
class AppActionDock extends StatelessWidget {
  const AppActionDock({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

/// High-emphasis action used in docks and hero panels.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.expand = true,
    this.size = M3EButtonSize.md,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expand;
  final M3EButtonSize size;

  @override
  Widget build(BuildContext context) {
    final button = M3EButton.filled(
      onPressed: onPressed,
      size: size,
      icon: icon == null ? null : Icon(icon),
      label: Text(label),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Compact vertical action button for docks.
class AppDockIconButton extends StatelessWidget {
  const AppDockIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return M3EIconButton(
      variant: M3EIconButtonVariant.standard,
      icon: Icon(icon, color: isDestructive ? theme.colorScheme.error : null),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
