import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'app_sections.dart';

export 'app_metrics.dart';
export 'app_scaffold.dart';
export 'app_sections.dart';
export 'app_success.dart';
export 'app_toast.dart';
export 'immersive_review.dart';

/// A tappable icon-badge row shared by option sheets and inline editors.
///
/// The row shows an [IconBadge], a title and a subtitle or current value. The
/// trailing control is a chevron by default; pass [expanded] for a disclosure
/// tile that swaps between chevron down and up, or [trailing] for a custom
/// control. Expanded [details] render under the row inside the same surface.
class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.expanded,
    this.trailing,
    this.details,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool? expanded;
  final Widget? trailing;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    final accent = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    final Widget trailingControl;
    if (trailing != null) {
      trailingControl = trailing!;
    } else {
      final iconData = expanded == null
          ? Icons.chevron_right
          : (expanded! ? Icons.expand_less : Icons.expand_more);
      trailingControl = Icon(iconData, color: accent);
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconBadge(
            icon,
            size: 42,
            tone: destructive ? PillTone.error : PillTone.neutral,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.baseline.titleMedium.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailingControl,
        ],
      ),
    );

    final header = Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: title,
      value: subtitle,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: row,
        ),
      ),
    );

    final content = details == null
        ? header
        : Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: details!,
                ),
              ],
            ),
          );

    return content;
  }
}

Future<void> showSnack(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) async {
  M3ESnackbar.show(
    context,
    message: message,
    actionLabel: action,
    onAction: onAction,
    duration: duration,
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await M3EDialog.show<bool>(
    context,
    dialog: M3EDialog(
      title: title,
      content: Text(message),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
