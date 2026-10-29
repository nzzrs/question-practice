import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'app_success.dart';

class LinearScore extends StatelessWidget {
  const LinearScore({required this.value, this.semanticsLabel, super.key});

  final double value;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return M3EProgressIndicator.linear(
      value: value.clamp(0, 1),
      linearSize: M3EProgressIndicatorSize.s,
      color: scheme.primary,
      trackColor: scheme.surfaceContainerHighest,
      showTrack: true,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// Circular score used as the hero of results and topic pages.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    required this.value,
    required this.label,
    this.caption,
    this.size = 132,
    this.strokeWidth = 12,
    this.color,
    super.key,
  });

  final double value;
  final String label;
  final String? caption;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Semantics(
      label: '$label${caption == null ? '' : ', $caption'}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            M3EProgressIndicator.circular(
              value: value.clamp(0, 1),
              size: size,
              strokeWidth: strokeWidth,
              trackStrokeWidth: strokeWidth,
              trackColor: theme.colorScheme.surfaceContainerHighest,
              color: accent,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.typography.emphasized.headlineLarge.copyWith(
                    color: accent,
                    height: 1,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact labelled figure for metric grids.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.icon,
    this.caption,
    this.tone = MetricTone.neutral,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? caption;
  final MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      MetricTone.neutral => (scheme.surfaceContainerLow, scheme.onSurface),
      MetricTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      MetricTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      MetricTone.success => (
        AppSuccess.container(context),
        AppSuccess.onContainer(context),
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: foreground.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.typography.emphasized.titleLarge.copyWith(
              color: foreground,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 1),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.labelSmall.copyWith(
                color: foreground.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum MetricTone { neutral, primary, error, success }

class StatValue extends StatelessWidget {
  const StatValue({
    required this.label,
    required this.value,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.typography.emphasized.headlineSmall),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.typography.baseline.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
