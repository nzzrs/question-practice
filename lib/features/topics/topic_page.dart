import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/data/practice_repository.dart';
import '../../core/domain/list_sort.dart';
import '../../core/domain/models.dart';
import '../../core/domain/natural_compare.dart';
import '../../core/ui/sort_dialog.dart';
import '../../core/ui/widgets.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import 'practice_actions.dart';
import 'topic_stats_page.dart';

enum _ResumeChoice { continueSession, discardAndStart }

class TopicPage extends ConsumerStatefulWidget {
  const TopicPage({required this.topicId, super.key});

  final int topicId;

  @override
  ConsumerState<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends ConsumerState<TopicPage> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(topicSummaryProvider(widget.topicId));
    final practices = ref.watch(practiceSummariesProvider(widget.topicId));
    final sort =
        ref.watch(topicPracticeSortProvider(widget.topicId)).value ??
        ListSort.defaultByName;
    final defaultDeck =
        ref.watch(settingsProvider).value?.ankiDeck ?? 'Question Practice';

    return AppPage(
      title: summary.value?.topic.name ?? 'Topic',
      titleWidget: summary.value == null
          ? null
          : Text(
              summary.value!.topic.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.insights_outlined),
          tooltip: 'Topic statistics',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TopicStatsPage(topicId: widget.topicId),
            ),
          ),
        ),
      ],
      children: [
        summary.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
          error: (error, stackTrace) => EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load this topic',
            message: '$error',
          ),
          data: (data) {
            if (data == null) {
              return const EmptyState(
                icon: Icons.search_off,
                title: 'Topic not found',
                message: 'This topic may have been removed.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (data.topic.priority != null) ...[
                      Pill(
                        'P${data.topic.priority}',
                        tone: PillTone.primary,
                        icon: Icons.flag_outlined,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Pill(
                      '${data.sessionCount} sessions',
                      tone: PillTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Anki deck: ${data.topic.ankiDeck ?? '$defaultDeck (default)'}',
                  style: M3ETheme.of(context).typography.baseline.labelSmall
                      .copyWith(
                        color: M3ETheme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                if (data.topic.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    data.topic.description,
                    style: M3ETheme.of(context).typography.baseline.bodyLarge
                        .copyWith(
                          color: M3ETheme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
                const SizedBox(height: 20),
                _TopicHero(summary: data),
                const SizedBox(height: 24),
                SectionTitle(
                  'Practices',
                  trailing: M3EIconButton(
                    variant: M3EIconButtonVariant.standard,
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort practices',
                    onPressed: () => _chooseSort(sort),
                  ),
                ),
                practices.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: M3ELoadingIndicator()),
                  ),
                  error: (error, stackTrace) => Text('$error'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.library_books_outlined,
                        title: 'No practices here',
                        message: 'Import a practice file that names this topic to add practices.',
                      );
                    }
                    final sorted = _sortedPractices(items, sort);
                    return AppGroup(
                      children: [
                        for (final practice in sorted)
                          AppGroupRow(
                            title: practice.practice.name,
                            titleMaxLines: 2,
                            subtitle: practice.practice.description.isEmpty
                                ? null
                                : practice.practice.description,
                            leading: IconBadge(
                              practice.hasInProgressSession
                                  ? Icons.play_circle_outline
                                  : Icons.play_arrow_outlined,
                            ),
                            trailing: _PracticeTrailing(summary: practice),
                            onTap: _starting
                                ? null
                                : () => _openPractice(practice),
                            onLongPress: _starting
                                ? null
                                : () => _showPracticeActions(practice),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<PracticeSummary> _sortedPractices(
    List<PracticeSummary> items,
    ListSort sort,
  ) {
    final sorted = List<PracticeSummary>.of(items);
    final direction = sort.direction == ListSortDirection.increasing ? 1 : -1;
    sorted.sort((a, b) {
      final comparison = switch (sort.field) {
        ListSortField.name => compareNatural(a.practice.name, b.practice.name),
        ListSortField.recency => a.practice.importedAt.compareTo(
          b.practice.importedAt,
        ),
      };
      final tieBreak = a.practice.id.compareTo(b.practice.id);
      return (comparison != 0 ? comparison : tieBreak) * direction;
    });
    return sorted;
  }

  Future<void> _chooseSort(ListSort current) async {
    final applied = await showListSortDialog(
      context,
      title: 'Sort practices',
      initial: current,
    );
    if (applied == null || !mounted) return;
    await ref
        .read(settingsRepositoryProvider)
        .saveTopicPracticeSort(widget.topicId, applied);
  }

  Future<void> _openPractice(PracticeSummary summary) async {
    final sessionId = summary.inProgressSessionId;
    if (sessionId == null) {
      await _startPractice(summary.practice);
      return;
    }
    final choice = await M3EDialog.show<_ResumeChoice>(
      context,
      dialog: M3EDialog(
        title: 'Continue this practice?',
        content: Text(
          '"${summary.practice.name}" already has a session in progress. '
          'Continue where you left off, or discard it and start another.',
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          M3EButton.text(
            onPressed: () =>
                Navigator.of(context).pop(_ResumeChoice.discardAndStart),
            child: const Text('Discard and start another'),
          ),
          M3EButton.filled(
            onPressed: () =>
                Navigator.of(context).pop(_ResumeChoice.continueSession),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _ResumeChoice.continueSession:
        await _resumePractice(sessionId);
      case _ResumeChoice.discardAndStart:
        setState(() => _starting = true);
        try {
          await ref.read(sessionServiceProvider).discard(sessionId);
        } finally {
          if (mounted) setState(() => _starting = false);
        }
        if (mounted) await _startPractice(summary.practice);
    }
  }

  Future<void> _resumePractice(int sessionId) async {
    setState(() => _starting = true);
    try {
      final start = await ref.read(sessionServiceProvider).resume(sessionId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SessionPage(start: start),
        ),
      );
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _startPractice(Practice practice) async {
    setState(() => _starting = true);
    try {
      final start = await ref
          .read(sessionServiceProvider)
          .startPractice(practice.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SessionPage(start: start),
        ),
      );
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _showPracticeActions(PracticeSummary summary) async {
    final action = await showPracticeActions(context, summary);
    if (action == null || !mounted) return;
    switch (action) {
      case PracticeAction.edit:
        await showPracticeEditMenu(context, ref, summary);
      case PracticeAction.delete:
        final practice = summary.practice;
        final confirmed = await confirmDialog(
          context,
          title: 'Delete practice?',
          message:
              'This removes "${practice.name}", its questions, sessions and cards. It cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!confirmed) return;
        await ref.read(topicRepositoryProvider).deletePractice(practice.id);
        if (mounted) await showSnack(context, 'Practice deleted.');
      case PracticeAction.markDone:
        await ref
            .read(topicRepositoryProvider)
            .setPracticeDone(summary.practice.id, true);
        if (mounted) await showSnack(context, 'Practice marked as done.');
      case PracticeAction.markActive:
        await ref
            .read(topicRepositoryProvider)
            .setPracticeDone(summary.practice.id, false);
        if (mounted) await showSnack(context, 'Practice marked active.');
      case PracticeAction.split:
        await _splitPractice(summary);
    }
  }

  Future<void> _splitPractice(PracticeSummary summary) async {
    final count = summary.questionCount;
    if (summary.hasInProgressSession) {
      await showSnack(
        context,
        'Finish or discard the session in progress before splitting this practice.',
      );
      return;
    }
    if (count < 2) {
      await showSnack(context, 'A split needs at least two questions.');
      return;
    }
    if (count.isOdd) {
      await showSnack(
        context,
        'A split needs an even number of questions. This practice has $count.',
      );
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'Split practice?',
      message:
          'This replaces "${summary.practice.name}" with two practices of '
          '${count ~/ 2} randomly chosen questions each, named '
          '"${summary.practice.name} Slice A" and '
          '"${summary.practice.name} Slice B".\n\n'
          'Sessions, answers and error cards for the original practice are '
          'removed.',
      confirmLabel: 'Split',
    );
    if (!confirmed || !mounted) return;
    setState(() => _starting = true);
    try {
      final result = await ref
          .read(topicRepositoryProvider)
          .splitPractice(summary.practice.id);
      if (mounted) {
        await showSnack(
          context,
          'Split into ${result.sliceA.name} and ${result.sliceB.name}.',
        );
      }
    } on PracticeSplitException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

class _TopicHero extends StatelessWidget {
  const _TopicHero({required this.summary});

  final TopicSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = summary.answeredCount == 0
        ? 0.0
        : summary.accuracy.clamp(0, 1).toDouble();
    final accuracyLabel = summary.answeredCount == 0
        ? '—'
        : '${(accuracy * 100).round()}%';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(
                value: accuracy,
                label: accuracyLabel,
                caption: 'Accuracy',
                size: 116,
                strokeWidth: 11,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: theme.typography.baseline.labelMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(summary.progress * 100).round()}%',
                      style: theme.typography.emphasized.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.attemptedQuestionCount}/${summary.relevantQuestionCount} answered',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearScore(value: summary.progress),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Active errors',
                  value: '${summary.activeErrorCount}',
                  icon: Icons.error_outline,
                  caption: '${summary.dueErrorCount} due now',
                  tone: summary.activeErrorCount > 0
                      ? MetricTone.error
                      : MetricTone.neutral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: 'Correct answers',
                  value: '${summary.correctCount}/${summary.answeredCount}',
                  icon: Icons.check_circle_outline,
                  caption: '${summary.sessionCount} sessions',
                  tone: MetricTone.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeTrailing extends StatelessWidget {
  const _PracticeTrailing({required this.summary});

  final PracticeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final score = summary.lastScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.hasInProgressSession) ...[
          const Pill(
            'In progress',
            tone: PillTone.secondary,
            icon: Icons.play_arrow,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          '${summary.questionCount} questions',
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          Pill(
            '${(score * 100).round()}%',
            tone: score >= 0.7 ? PillTone.success : PillTone.error,
          ),
        ],
        if (summary.practice.isDone) ...[
          const SizedBox(height: 2),
          const Pill('Done', tone: PillTone.success, icon: Icons.check),
        ],
      ],
    );
  }
}
