import 'dart:async';

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// A short-lived floating message that does not take over the screen.
class FloatingToastHandle {
  FloatingToastHandle._(this._entry, this._timer);

  final OverlayEntry _entry;
  final Timer _timer;
  bool _dismissed = false;

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer.cancel();
    if (_entry.mounted) _entry.remove();
  }
}

FloatingToastHandle showFloatingToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.schedule,
  Duration duration = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (context) => _FloatingToast(message: message, icon: icon),
  );
  overlay.insert(entry);
  final timer = Timer(duration, () {
    if (entry.mounted) entry.remove();
  });
  return FloatingToastHandle._(entry, timer);
}

class _FloatingToast extends StatelessWidget {
  const _FloatingToast({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final foreground = theme.colorScheme.onInverseSurface;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -12 * (1 - value)),
                child: child,
              ),
            ),
            child: Semantics(
              liveRegion: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: theme.colorScheme.inverseSurface,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: foreground),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: foreground,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
