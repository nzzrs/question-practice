import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// One compact row inside a [RowActionMenu].
@immutable
class RowActionItem<T> {
  const RowActionItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Stable key for the menu row label.
  final Key? key;
  final bool enabled;
  final bool destructive;
}

/// Three-dot overflow action for a saved note or a wrong-answer bullet.
///
/// Opens a compact Material 3 Expressive [M3EMenu] anchored to the button, so
/// copy, card and note actions share one touch target and one focus loop.
class RowActionMenu<T> extends StatelessWidget {
  const RowActionMenu({
    required this.menuKey,
    required this.tooltip,
    required this.items,
    required this.onSelected,
    super.key,
  });

  /// Key for the three-dot anchor button.
  final Key menuKey;

  /// Tooltip and semantics label for the anchor.
  final String tooltip;

  final List<RowActionItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return M3EMenu(
      position: M3EMenuAnchorPosition.bottomEnd,
      anchorBuilder: (context, open) => M3EIconButton(
        key: menuKey,
        variant: M3EIconButtonVariant.standard,
        icon: const Icon(Icons.more_vert),
        tooltip: tooltip,
        semanticLabel: tooltip,
        onPressed: items.isEmpty ? null : open,
      ),
      onSelected: (value) {
        if (value is T) onSelected(value);
      },
      children: [
        for (final item in items)
          M3EMenuWidget(
            value: item.value,
            enabled: item.enabled,
            semanticLabel: item.label,
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.destructive ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      item.label,
                      key: item.key,
                      style: item.destructive
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
