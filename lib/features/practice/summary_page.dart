import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/cards_page.dart';
import '../review/review_page.dart';

class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({required this.summary, super.key});

  final SessionSummary summary;

  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends ConsumerState<SummaryPage> {
  bool _reviewed = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final summary = widget.summary;
    final session = summary.session;
    final percent = (session.score * 100).round();
    final wrong = summary.wrongCount;
    return AppScaffold(
      title: 'Results',
      showBack: false,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.close),
          tooltip: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Semantics(
            liveRegion: true,
            label: 'Score $percent percent',
            child: Column(
              children: [
                Text(
                  '$percent%',
                  style: theme.typography.emphasized.displayLarge.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${session.correct} of ${session.total} correct',
                  style: theme.typography.baseline.titleMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LinearScore(value: session.score),
          const SizedBox(height: 24),
          TonalBox(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatValue(
                        label: 'Wrong',
                        value: '$wrong',
                        caption: '$wrong wrong answer${wrong == 1 ? '' : 's'}',
                      ),
                    ),
                    Expanded(
                      child: StatValue(
                        label: 'Skipped',
                        value: '${session.skipped}',
                        caption: 'No error cards',
                      ),
                    ),
                    Expanded(
                      child: StatValue(
                        label: 'Words asked',
                        value: '${summary.lookupCount}',
                        caption: '${summary.conceptCount} missing concepts',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (session.distracted > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.distracted} wrong answer${session.distracted == 1 ? ' was' : 's were'} marked as distracted; no cards were made.',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          if (summary.hasReviewableIssues && !_reviewed) ...[
            Text(
              'Turn mistakes into cards',
              style: theme.typography.emphasized.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'The review asks for the flawed assumption and the fix, or what was missing on a skipped question. It stays in this session.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            M3EButton.filled(
              onPressed: () => _openReview(summary),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(
                summary.errorCardsNeedingNotes > 0
                    ? 'Start error review (${summary.errorCardsNeedingNotes})'
                    : 'Start review',
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_reviewed) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review completed. Cards missing details can be finished from Cards.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              M3EButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const CardsPage(),
                  ),
                ),
                icon: const Icon(Icons.style_outlined),
                label: const Text('View cards'),
              ),
              const SizedBox(width: 8),
              M3EButton.text(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openReview(SessionSummary summary) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReviewPage(sessionId: summary.session.id),
      ),
    );
    if (!mounted) return;
    setState(() => _reviewed = true);
    if (_reviewed) {
      ref.invalidate(homeStatsProvider);
    }
  }
}
