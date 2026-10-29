import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Green success roles that stay readable in both light and dark themes.
///
/// Material's dynamic scheme has no success role, so these are derived from the
/// current brightness while the rest of the palette keeps following the
/// wallpaper.
abstract final class AppSuccess {
  static Color foreground(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? const Color(0xFF7FE3A1)
        : const Color(0xFF146B32);
  }

  static Color container(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? const Color(0xFF123D24)
        : const Color(0xFFD9F7E1);
  }

  static Color onContainer(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? const Color(0xFFC9F7D8)
        : const Color(0xFF063B18);
  }
}
