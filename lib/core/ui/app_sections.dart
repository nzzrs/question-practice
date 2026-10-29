import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'app_success.dart';

/// Visual tone for compact status pills.
enum PillTone { neutral, primary, secondary, error, success }

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    this.tone = PillTone.neutral,
    this.icon,
    this.maxWidth = 220,
    super.key,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      PillTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PillTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PillTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.success => (
        AppSuccess.container(context),
        AppSuccess.onContainer(context),
      ),
      PillTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: M3ETheme.of(context).typography.baseline.labelSmall
                    .copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen section with a consistent heading rhythm.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.text, {
    this.trailing,
    this.overline,
    this.supporting,
    this.count,
    super.key,
  });

  final String text;
  final Widget? trailing;
  final String? overline;
  final String? supporting;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final label = count == null ? text : '$text · $count';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Text(
              overline!.toUpperCase(),
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.emphasized.titleLarge,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (supporting != null) ...[
            const SizedBox(height: 4),
            Text(
              supporting!,
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tonal surface used for grouped rows and feature panels.
class TonalBox extends StatelessWidget {
  const TonalBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 24,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// A set of rows that read as one surface.
class AppGroup extends StatelessWidget {
  const AppGroup({
    required this.children,
    this.variant = M3ECardVariant.filled,
    this.color,
    this.semanticsLabel,
    super.key,
  });

  final List<Widget> children;
  final M3ECardVariant variant;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final background =
        color ??
        (variant == M3ECardVariant.filled
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface);
    final border = variant == M3ECardVariant.outlined
        ? Border.all(color: theme.colorScheme.outlineVariant)
        : null;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// One tappable row inside an [AppGroup].
class AppGroupRow extends StatelessWidget {
  const AppGroupRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.titleMaxLines = 2,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
  }
}

/// A round icon chip used as a row leading or empty-state mark.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    this.tone = PillTone.primary,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final PillTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      PillTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PillTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PillTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.success => (
        AppSuccess.container(context),
        AppSuccess.onContainer(context),
      ),
      PillTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foreground, size: size * 0.48),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
