import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

/// Review step header that scrolls with the feedback pane.
class FeedbackStepHeader extends StatelessWidget {
  const FeedbackStepHeader({
    required this.label,
    required this.progress,
    required this.heading,
    super.key,
  });

  final String label;
  final double progress;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearScore(value: progress),
          const SizedBox(height: 22),
          Text(heading, style: theme.typography.emphasized.headlineSmall),
        ],
      ),
    );
  }
}
