import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/practice_sound_player.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playFinishedSound());
  }

  Future<void> _playFinishedSound() async {
    if (!mounted) return;
    final current = ref.read(settingsProvider).value;
    final enabled =
        current?.soundsEnabled ??
        (await ref.read(settingsRepositoryProvider).load()).soundsEnabled;
    if (!enabled) return;
    await ref.read(practiceSoundPlayerProvider).play(PracticeSound.finished);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final summary = widget.summary;
    final session = summary.session;
    final percent = (session.score * 100).round();
    final wrong = summary.wrongCount;
    final strongResult = session.score > 0.8;

    return AppPage(
      title: 'Results',
      showBack: false,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            Expanded(
              child: M3EButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const CardsPage(),
                  ),
                ),
                icon: const Icon(Icons.style_outlined),
                label: const Text('View cards'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: M3EButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
      children: [
        const SizedBox(height: 8),
        Center(
          child: ScoreRing(
            value: session.score,
            label: '$percent%',
            caption: '${session.correct} of ${session.total} correct',
            size: 168,
            strokeWidth: 14,
            color: strongResult ? AppSuccess.foreground(context) : null,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Wrong',
                value: '$wrong',
                icon: Icons.close,
                caption: wrong == 1 ? '1 answer' : '$wrong answers',
                tone: wrong > 0 ? MetricTone.error : MetricTone.neutral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Skipped',
                value: '${session.skipped}',
                icon: Icons.skip_next_outlined,
                caption: 'No error cards',
              ),
            ),
          ],
        ),
        if (summary.lookupCount > 0) ...[
          const SizedBox(height: 10),
          TonalBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.manage_search_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${summary.lookupCount} word${summary.lookupCount == 1 ? '' : 's'} asked · ${summary.conceptCount} missing concept${summary.conceptCount == 1 ? '' : 's'}',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (session.distracted > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.pause_circle_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.distracted} wrong answer${session.distracted == 1 ? ' was' : 's were'} marked as distracted; no cards were made.',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        if (summary.hasReviewableIssues && !_reviewed) ...[
          TonalBox(
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Turn mistakes into cards',
                        style: theme.typography.emphasized.titleMedium.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The review asks for the flawed assumption and the fix, or what was missing on a skipped question. It stays in this session.',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.85,
                    ),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                AppPrimaryButton(
                  onPressed: () => _openReview(summary),
                  label: summary.errorCardsNeedingNotes > 0
                      ? 'Start error review (${summary.errorCardsNeedingNotes})'
                      : 'Start review',
                  icon: Icons.arrow_forward,
                ),
              ],
            ),
          ),
        ],
        if (_reviewed)
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
      ],
    );
  }

  Future<void> _openReview(SessionSummary summary) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewPage(sessionId: summary.session.id),
      ),
    );
    if (!mounted || completed != true) return;
    setState(() => _reviewed = true);
    ref.invalidate(homeStatsProvider);
  }
}
