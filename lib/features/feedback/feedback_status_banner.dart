import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';
import 'feedback_snapshot.dart';

/// The answer verdict shown above "Why this answer" in both feedback modes.
class FeedbackStatusBanner extends StatelessWidget {
  const FeedbackStatusBanner({required this.snapshot, super.key});

  final FeedbackSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final (color, icon, text) = snapshot.isUnknown
        ? (
            theme.colorScheme.secondaryContainer,
            Icons.help_outline,
            "You didn't know this. No error card was created; the review asks "
                'which concept was missing.',
          )
        : switch ((
            snapshot.mode,
            snapshot.pastErrors,
            snapshot.isCorrect,
            snapshot.isSkipped,
            snapshot.isDistracted,
          )) {
            (FeedbackMode.review, _, _, _, _) => (
              theme.colorScheme.errorContainer,
              Icons.error_outline,
              'Not quite. This is the error card from that attempt.',
            ),
            (_, true, true, _, _) => (
              AppSuccess.container(context),
              Icons.check_circle_outline,
              'Error resolved. It stays in your history.',
            ),
            (_, true, false, _, true) => (
              theme.colorScheme.secondaryContainer,
              Icons.pause_circle_outline,
              'Not counted because you were distracted. The card stays due.',
            ),
            (_, true, false, _, false) => (
              theme.colorScheme.errorContainer,
              Icons.schedule,
              'Still in the error queue. Next attempt in 48 hours.',
            ),
            (_, false, true, _, _) => (
              AppSuccess.container(context),
              Icons.check_circle_outline,
              'Correct.',
            ),
            (_, false, false, true, _) => (
              theme.colorScheme.secondaryContainer,
              Icons.skip_next_outlined,
              'Skipped. No error card is created; the review asks what was '
                  'missing.',
            ),
            (_, false, false, false, true) => (
              theme.colorScheme.secondaryContainer,
              Icons.pause_circle_outline,
              'Marked as distracted. No error card was created.',
            ),
            _ => (
              theme.colorScheme.errorContainer,
              Icons.error_outline,
              'Not quite. Write what went wrong, then turn it into cards.',
            ),
          };
    return TonalBox(
      key: const ValueKey('feedback-status'),
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.typography.baseline.bodySmall.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
