import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/data/practice_repository.dart';
import '../../core/domain/list_sort.dart';
import '../../core/domain/models.dart';
import '../../core/domain/natural_compare.dart';
import '../../core/domain/plural.dart';
import '../../core/domain/score_band.dart';
import '../../core/ui/score_band_style.dart';
import '../../core/ui/sort_dialog.dart';
import '../../core/ui/widgets.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import 'practice_actions.dart';
import 'topic_stats_page.dart';

enum _ResumeChoice { continueSession, discardAndStart }

/// App-bar title for a topic.
///
/// Long topic names get a second line instead of an early ellipsis. The title
/// scale is capped so two lines still fit the compact bar at platform text
/// sizes up to 2x; body copy keeps the learner's full scale.
class _TopicTitle extends StatelessWidget {
  const _TopicTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.baseline.titleLarge.copyWith(height: 1.2),
      ),
    );
  }
}

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
    final readiness = ref.watch(topicReadinessProvider(widget.topicId));
    final sort =
        ref.watch(topicPracticeSortProvider(widget.topicId)).value ??
        ListSort.defaultByName;
    final defaultDeck =
        ref.watch(settingsProvider).value?.ankiDeck ?? 'Question Practice';
    final topicName = summary.value?.topic.name;

    return AppPage(
      title: topicName ?? 'Topic',
      titleWidget: topicName == null ? null : _TopicTitle(name: topicName),
      // A compact bar gives the two-line title enough height at large text
      // sizes; the flexible large bar only leaves room for one ellipsized line.
      variant: M3EAppBarVariant.small,
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
                      formatCount(data.sessionCount, 'session'),
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
                _TopicHero(
                  summary: data,
                  readiness: readiness.value,
                  minimumScore: data.topic.minimumScore,
                  targetScore: data.topic.targetScore,
                ),
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
                            trailing: _PracticeTrailing(
                              summary: practice,
                              minimumScore: data.topic.minimumScore,
                              targetScore: data.topic.targetScore,
                            ),
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
        } on SessionException catch (error) {
          if (mounted) await showSnack(context, error.message);
          return;
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
    final parts = await showSplitPracticeDialog(context, questionCount: count);
    if (parts == null || !mounted) return;
    setState(() => _starting = true);
    try {
      final result = await ref
          .read(topicRepositoryProvider)
          .splitPractice(summary.practice.id, parts: parts);
      if (mounted) {
        final names = [for (final part in result.parts) part.name];
        await showSnack(
          context,
          'Split into ${formatCount(names.length, 'practice')}: '
          '${_summarizeSplitNames(names)}.',
        );
      }
    } on PracticeSplitException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

/// Asks how many parts to create and previews their question distribution.
Future<int?> showSplitPracticeDialog(
  BuildContext context, {
  required int questionCount,
}) {
  return M3EDialog.show<int>(
    context,
    dialog: _SplitPracticeDialog(questionCount: questionCount),
  );
}

/// Compact split form: one stepper, a distribution preview and one warning.
class _SplitPracticeDialog extends StatefulWidget {
  const _SplitPracticeDialog({required this.questionCount});

  final int questionCount;

  @override
  State<_SplitPracticeDialog> createState() => _SplitPracticeDialogState();
}

class _SplitPracticeDialogState extends State<_SplitPracticeDialog> {
  static const int _minParts = 2;

  int _parts = _minParts;

  int get _maxParts => widget.questionCount;

  bool get _hasRange => _maxParts >= _minParts;

  void _step(int delta) {
    final next = _parts + delta;
    if (next < _minParts || next > _maxParts) return;
    setState(() => _parts = next);
  }

  void _submit() {
    if (_hasRange) Navigator.of(context).pop(_parts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final sizes = _hasRange
        ? splitPartSizes(widget.questionCount, _parts)
        : null;
    return M3EDialog(
      title: 'Split practice',
      icon: const Icon(Icons.call_split),
      content: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Divide ${formatCount(widget.questionCount, 'question')} '
              'into parts.',
              key: const ValueKey('split-subtitle'),
              textAlign: TextAlign.center,
              style: theme.typography.baseline.bodyLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            if (_hasRange) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      M3EIconButton(
                        key: const ValueKey('split-parts-remove'),
                        icon: const Icon(Icons.remove),
                        semanticLabel: 'Remove a part',
                        tooltip: 'Remove a part',
                        variant: M3EIconButtonVariant.outlined,
                        size: M3EIconButtonSize.md,
                        onPressed: _parts > _minParts ? () => _step(-1) : null,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Semantics(
                              label: 'Parts',
                              value: '$_parts',
                              liveRegion: true,
                              excludeSemantics: true,
                              child: Text(
                                '$_parts',
                                key: const ValueKey('split-parts-value'),
                                maxLines: 1,
                                style: theme.typography.emphasized.displaySmall
                                    .copyWith(color: theme.colorScheme.primary),
                              ),
                            ),
                          ),
                        ),
                      ),
                      M3EIconButton(
                        key: const ValueKey('split-parts-add'),
                        icon: const Icon(Icons.add),
                        semanticLabel: 'Add a part',
                        tooltip: 'Add a part',
                        variant: M3EIconButtonVariant.outlined,
                        size: M3EIconButtonSize.md,
                        onPressed: _parts < _maxParts ? () => _step(1) : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                key: const ValueKey('split-distribution'),
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < sizes!.length; index++)
                    _PartSizeChip(part: index + 1, questions: sizes[index]),
                ],
              ),
            ] else
              Row(
                key: const ValueKey('split-range-error'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A split needs at least two questions.',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.error,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: theme.colorScheme.warning,
                    semanticLabel: 'Warning',
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Original session history will be removed.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        M3EButton.text(
          key: const ValueKey('split-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          key: const ValueKey('split-confirm'),
          onPressed: _hasRange ? _submit : null,
          child: const Text('Split'),
        ),
      ],
    );
  }
}

/// One part in the distribution preview, e.g. `Part 2 · 3`.
class _PartSizeChip extends StatelessWidget {
  const _PartSizeChip({required this.part, required this.questions});

  final int part;
  final int questions;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Semantics(
      label: 'Part $part, ${formatCount(questions, 'question')}',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('split-part-$part'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Part $part · $questions',
          style: theme.typography.baseline.labelLarge.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

String _summarizeSplitNames(List<String> names) {
  if (names.length <= 3) return _joinNames(names);
  return '${names.first} to ${names.last}';
}

String _joinNames(List<String> names) {
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

class _TopicHero extends StatelessWidget {
  const _TopicHero({
    required this.summary,
    required this.readiness,
    required this.minimumScore,
    required this.targetScore,
  });

  final TopicSummary summary;
  final TopicReadiness? readiness;
  final int minimumScore;
  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final hasAnswers = readiness?.hasAnswers ?? false;
    final readinessLabel = hasAnswers
        ? '${(readiness!.value * 100).round()}%'
        : '—';
    final band = hasAnswers
        ? scoreBandFor(
            readiness!.value,
            minimumScore: minimumScore,
            targetScore: targetScore,
          )
        : null;
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScoreRing(
                    value: hasAnswers ? readiness!.value : 0,
                    label: readinessLabel,
                    caption: 'Readiness',
                    size: 132,
                    strokeWidth: 11,
                    color: band == null ? null : scoreBandColor(context, band),
                  ),
                  if (band != null) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      label: scoreSemanticsLabel(
                        subject: 'Readiness',
                        percent: (readiness!.value * 100).round(),
                        band: band,
                      ),
                      excludeSemantics: true,
                      child: Pill(
                        scoreBandLabel(band),
                        tone: scoreBandPillTone(band),
                      ),
                    ),
                  ],
                ],
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
                  caption: formatCount(summary.sessionCount, 'session'),
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
  const _PracticeTrailing({
    required this.summary,
    required this.minimumScore,
    required this.targetScore,
  });

  final PracticeSummary summary;
  final int minimumScore;
  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final score = summary.lastScore;
    final band = score == null
        ? null
        : scoreBandFor(
            score,
            minimumScore: minimumScore,
            targetScore: targetScore,
          );
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
          formatCount(summary.questionCount, 'question'),
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          Semantics(
            label: scoreSemanticsLabel(
              subject: 'Last score',
              percent: (score * 100).round(),
              band: band!,
            ),
            excludeSemantics: true,
            child: Pill(
              '${(score * 100).round()}%',
              tone: scoreBandPillTone(band),
            ),
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
