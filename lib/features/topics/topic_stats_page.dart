import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/domain/progress_math.dart';
import '../../core/domain/score_band.dart';
import '../../core/ui/score_band_style.dart';
import '../../core/ui/widgets.dart';

class TopicStatsPage extends ConsumerStatefulWidget {
  const TopicStatsPage({required this.topicId, super.key});

  final int topicId;

  @override
  ConsumerState<TopicStatsPage> createState() => _TopicStatsPageState();
}

class _TopicStatsPageState extends ConsumerState<TopicStatsPage> {
  bool _exporting = false;
  final Set<String> _selected = <String>{};
  final Set<int> _selectedSessions = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final summary = ref.watch(topicSummaryProvider(widget.topicId));
    final progress = ref.watch(topicProgressProvider(widget.topicId));
    final subtopics =
        ref.watch(topicSubtopicStatsProvider(widget.topicId)).value ??
        const <SubtopicStat>[];

    return AppPage(
      title: 'Statistics',
      showBack: true,
      variant: M3EAppBarVariant.small,
      actions: _sessionSelectionMode
          ? [
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.close),
                tooltip: 'Clear selection',
                onPressed: _clearSessionSelection,
              ),
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete sessions',
                onPressed: _deleteSelectedSessions,
              ),
            ]
          : _selectionMode
          ? [
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.close),
                tooltip: 'Clear selection',
                onPressed: _clearSelection,
              ),
              if (_selected.length == 1)
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Rename category',
                  onPressed: _renameSelected,
                ),
              if (_selected.length > 1)
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.merge_type),
                  tooltip: 'Merge categories',
                  onPressed: _mergeSelected,
                ),
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete category',
                onPressed: _deletableSelected.isEmpty ? null : _deleteSelected,
              ),
            ]
          : [
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export statistics',
                onPressed: _exporting ? null : _exportStatistics,
              ),
            ],
      children: [
        Text(
          summary.value?.topic.name ?? 'Topic',
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Progress from completed sessions in this topic.',
          style: theme.typography.baseline.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        progress.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
          error: (error, stackTrace) => EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load statistics',
            message: '$error',
          ),
          data: (points) {
            if (points.isEmpty) {
              return const EmptyState(
                icon: Icons.insights_outlined,
                title: 'No completed sessions yet',
                message: 'Finish a practice in this topic to start the progress line.',
              );
            }
            final ordered = orderedProgressPoints(points);
            final latest = ordered.last;
            final best = ordered.map((point) => point.score).reduce(math.max);
            final average = weightedAverageScore(ordered) ?? 0;
            final fit = fitProgressWeightedByQuestions(ordered);
            final trendValues = fit == null
                ? const <double>[]
                : [
                    for (final questions in cumulativeQuestionCounts(ordered))
                      fit.valueAt(questions.toDouble()),
                  ];
            final learningRatePer100 =
                learningRatePercentagePointsPer100Questions(ordered);
            final learningRatePerWeek = learningRatePercentagePointsPerWeek(
              ordered,
            );
            final hasSubtopics = subtopics.any((stat) => !stat.isUncategorized);
            final topic = summary.value?.topic;
            final minimumScore = topic?.minimumScore ?? 70;
            final targetScore = topic?.targetScore ?? 80;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendHero(
                  points: ordered,
                  latest: latest,
                  average: average,
                  best: best,
                  learningRatePer100: learningRatePer100,
                  learningRatePerWeek: learningRatePerWeek,
                  minimumScore: minimumScore,
                  targetScore: targetScore,
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  'Progress over time',
                  count: ordered.length,
                  supporting: 'Each point is one completed session.',
                ),
                _ProgressChart(
                  points: ordered,
                  trendValues: trendValues,
                  minimumScore: minimumScore,
                  targetScore: targetScore,
                ),
                if (hasSubtopics) ...[
                  const SizedBox(height: 24),
                  SectionTitle(
                    'By subtopic',
                    count: subtopics.length,
                    supporting:
                        'Accuracy and progress for each question group.',
                  ),
                  AppGroup(
                    children: [
                      for (final stat in subtopics)
                        _SubtopicRow(
                          stat: stat,
                          minimumScore: minimumScore,
                          targetScore: targetScore,
                          selected: _selected.contains(stat.subtopic),
                          onTap: _selectionMode
                              ? () => _toggleSubtopic(stat.subtopic)
                              : null,
                          onLongPress: () => _selectSubtopic(stat.subtopic),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const SectionTitle('Sessions'),
                AppGroup(
                  children: [
                    for (final point in ordered.reversed)
                      _ProgressRow(
                        key: ValueKey('session-row-${point.sessionId}'),
                        point: point,
                        minimumScore: minimumScore,
                        targetScore: targetScore,
                        selected: _selectedSessions.contains(point.sessionId),
                        onTap: _sessionSelectionMode
                            ? () => _toggleSession(point.sessionId)
                            : null,
                        onLongPress: () => _selectSession(point.sessionId),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool get _selectionMode => _selected.isNotEmpty;

  bool get _sessionSelectionMode => _selectedSessions.isNotEmpty;

  List<String> get _deletableSelected => [
    for (final subtopic in _selected)
      if (subtopic.trim().isNotEmpty) subtopic,
  ];

  void _selectSubtopic(String subtopic) {
    setState(() {
      _selectedSessions.clear();
      _selected.add(subtopic);
    });
  }

  void _toggleSubtopic(String subtopic) {
    setState(() {
      if (!_selected.remove(subtopic)) _selected.add(subtopic);
    });
  }

  void _clearSelection() {
    if (_selected.isEmpty || !mounted) return;
    setState(_selected.clear);
  }

  void _selectSession(int sessionId) {
    setState(() {
      _selected.clear();
      _selectedSessions.add(sessionId);
    });
  }

  void _toggleSession(int sessionId) {
    setState(() {
      if (!_selectedSessions.remove(sessionId)) {
        _selectedSessions.add(sessionId);
      }
    });
  }

  void _clearSessionSelection() {
    if (_selectedSessions.isEmpty || !mounted) return;
    setState(_selectedSessions.clear);
  }

  Future<void> _deleteSelectedSessions() async {
    final ids = _selectedSessions.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await confirmDialog(
      context,
      title: ids.length == 1 ? 'Delete session?' : 'Delete sessions?',
      message:
          'Deleting a completed session also removes its answers and any '
          'cards, highlights and skipped records captured by that session. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(sessionRepositoryProvider).deleteSessions(ids);
      _clearSessionSelection();
      if (mounted) {
        await showSnack(
          context,
          ids.length == 1 ? 'Session deleted.' : 'Sessions deleted.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete sessions: $error');
      }
    }
  }

  String _labelFor(String subtopic) {
    final trimmed = subtopic.trim();
    return trimmed.isEmpty ? 'Uncategorized' : trimmed;
  }

  Future<void> _renameSelected() async {
    if (_selected.length != 1) return;
    final from = _selected.single;
    final controller = TextEditingController(text: from);
    String? error;
    final saved = await M3EDialog.show<bool>(
      context,
      dialog: StatefulBuilder(
        builder: (context, setDialogState) {
          return M3EDialog(
            title: 'Rename category',
            content: M3ETextField(
              controller: controller,
              label: 'Name',
              isRequired: true,
              autofocus: true,
              errorText: error,
            ),
            actions: [
              M3EButton.text(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              M3EButton.filled(
                onPressed: () {
                  final trimmed = controller.text.trim();
                  if (trimmed.isEmpty) {
                    setDialogState(() => error = 'Name is required.');
                    return;
                  }
                  if (trimmed.length > 120) {
                    setDialogState(
                      () => error = 'Use 120 characters or fewer.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (saved != true || !mounted) return;
    try {
      await ref
          .read(topicRepositoryProvider)
          .renameSubtopic(widget.topicId, from, name);
      _clearSelection();
      if (mounted) await showSnack(context, 'Category renamed.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not rename category: $error');
      }
    }
  }

  Future<void> _deleteSelected() async {
    final names = _deletableSelected;
    if (names.isEmpty) {
      await showSnack(context, 'Uncategorized cannot be deleted.');
      return;
    }
    final label = names.length == 1
        ? '"${_labelFor(names.single)}"'
        : '${names.length} categories';
    final confirmed = await confirmDialog(
      context,
      title: names.length == 1 ? 'Delete category?' : 'Delete categories?',
      message:
          'The questions in $label move to Uncategorized. '
          'No question, answer or card is deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(topicRepositoryProvider)
          .deleteSubtopics(widget.topicId, names);
      _clearSelection();
      if (mounted) {
        await showSnack(
          context,
          names.length == 1
              ? 'Category moved to Uncategorized.'
              : 'Categories moved to Uncategorized.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete category: $error');
      }
    }
  }

  Future<void> _mergeSelected() async {
    if (_selected.length < 2) return;
    final selection = List<String>.of(_selected);
    final names = [
      for (final subtopic in selection)
        if (subtopic.trim().isNotEmpty) subtopic.trim(),
    ];
    if (names.isEmpty) {
      await showSnack(context, 'Select at least one named category to merge.');
      return;
    }
    final merged = await _showMergeDialog(names);
    if (merged == null || !mounted) return;
    try {
      await ref
          .read(topicRepositoryProvider)
          .mergeSubtopics(widget.topicId, selection, merged);
      _clearSelection();
      if (mounted) await showSnack(context, 'Categories merged into $merged.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not merge categories: $error');
      }
    }
  }

  Future<String?> _showMergeDialog(List<String> names) async {
    var selectedIndex = 0;
    final controller = TextEditingController();
    String? error;
    final result = await M3EDialog.show<String>(
      context,
      dialog: StatefulBuilder(
        builder: (context, setDialogState) {
          return M3EDialog(
            title: 'Merge categories',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep one name for every selected question.',
                    style: M3ETheme.of(context).typography.baseline.bodySmall
                        .copyWith(
                          color: M3ETheme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  M3ERadioGroup<int>(
                    groupValue: selectedIndex,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedIndex = value;
                        error = null;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < names.length; index++)
                          M3ERadio<int>(
                            value: index,
                            groupValue: selectedIndex,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedIndex = value;
                                error = null;
                              });
                            },
                            label: Text(names[index]),
                          ),
                        M3ERadio<int>(
                          value: -1,
                          groupValue: selectedIndex,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedIndex = value;
                              error = null;
                            });
                          },
                          label: const Text('New name'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  M3ETextField(
                    controller: controller,
                    label: 'New name',
                    enabled: selectedIndex == -1,
                    errorText: error,
                  ),
                ],
              ),
            ),
            actions: [
              M3EButton.text(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              M3EButton.filled(
                onPressed: () {
                  final name = selectedIndex == -1
                      ? controller.text.trim()
                      : names[selectedIndex];
                  if (name.isEmpty) {
                    setDialogState(
                      () => error = 'Enter a name for the merged category.',
                    );
                    return;
                  }
                  if (name.length > 120) {
                    setDialogState(
                      () => error = 'Use 120 characters or fewer.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(name);
                },
                child: const Text('Merge'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportStatistics() async {
    setState(() => _exporting = true);
    try {
      await ref
          .read(statisticsExportServiceProvider)
          .shareTopicStats(widget.topicId);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not export statistics: $error');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _TrendHero extends StatelessWidget {
  const _TrendHero({
    required this.points,
    required this.latest,
    required this.average,
    required this.best,
    required this.learningRatePer100,
    required this.learningRatePerWeek,
    required this.minimumScore,
    required this.targetScore,
  });

  final List<TopicProgressPoint> points;
  final TopicProgressPoint latest;
  final double average;
  final double best;
  final int minimumScore;
  final int targetScore;

  /// Percentage points per 100 answered questions, or null without a fit.
  final double? learningRatePer100;

  /// Percentage points per week, or null without a fit.
  final double? learningRatePerWeek;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final rate = learningRatePer100;
    final latestPercent = (latest.score * 100).round();
    final latestBand = scoreBandFor(
      latest.score,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
    final averageBand = scoreBandFor(
      average,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
    final bestBand = scoreBandFor(
      best,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
    return TonalBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(
                value: latest.score,
                label: '$latestPercent%',
                caption: 'Latest',
                size: 112,
                strokeWidth: 11,
                color: scoreBandColor(context, latestBand),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trendLabel(points),
                      style: theme.typography.emphasized.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: scoreSemanticsLabel(
                        subject: 'Latest score',
                        percent: latestPercent,
                        band: latestBand,
                      ),
                      excludeSemantics: true,
                      child: Pill(
                        scoreBandLabel(latestBand),
                        tone: scoreBandPillTone(latestBand),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${points.length} completed session${points.length == 1 ? '' : 's'}',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Best ${(best * 100).round()}% · '
                      'weighted average ${(average * 100).round()}%',
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Average',
                  value: '${(average * 100).round()}%',
                  caption:
                      '${scoreBandLabel(averageBand)} · weighted by questions',
                  icon: Icons.timeline,
                  tone: scoreBandMetricTone(averageBand),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Best',
                  value: '${(best * 100).round()}%',
                  caption: '${scoreBandLabel(bestBand)} · target $targetScore%',
                  icon: Icons.emoji_events_outlined,
                  tone: scoreBandMetricTone(bestBand),
                ),
              ),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: 8),
            MetricTile(
              label: 'Learning rate',
              value: _signedRate(rate, 'pp/100 questions'),
              caption: learningRatePerWeek == null
                  ? null
                  : _signedRate(learningRatePerWeek!, 'pp/week'),
              icon: rate < 0 ? Icons.trending_down : Icons.trending_up,
              tone: rate > 0
                  ? MetricTone.success
                  : rate < 0
                  ? MetricTone.error
                  : MetricTone.neutral,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            targetProjectionSentence(
              average: average,
              targetScore: targetScore,
              percentagePointsPerWeek: learningRatePerWeek,
            ),
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _signedRate(double rate, String suffix) {
    final rounded = (rate * 10).round() / 10;
    final prefix = rounded > 0 ? '+' : '';
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
    return '$prefix$text $suffix';
  }

  String _trendLabel(List<TopicProgressPoint> points) {
    if (points.length < 2) return 'First result recorded';
    final previous = points[points.length - 2].score;
    final delta = ((latest.score - previous) * 100).round();
    if (delta == 0) return 'Holding steady';
    return delta > 0 ? 'Up $delta points' : 'Down ${delta.abs()} points';
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({
    required this.points,
    required this.trendValues,
    required this.minimumScore,
    required this.targetScore,
  });

  final List<TopicProgressPoint> points;
  final List<double> trendValues;
  final int minimumScore;
  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final trendColor = theme.colorScheme.tertiary;
    return TonalBox(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _ProgressPainter(
                points: points,
                trendValues: trendValues,
                minimumScore: minimumScore,
                targetScore: targetScore,
                lineColor: theme.colorScheme.primary,
                trendColor: trendColor,
                gridColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.55,
                ),
                successColor: AppSuccess.foreground(context),
                errorColor: theme.colorScheme.error,
                labelColor: theme.colorScheme.onSurfaceVariant,
                textStyle: theme.typography.baseline.labelSmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.MMMd().format(points.first.finishedAt.toLocal()),
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                DateFormat.MMMd().format(points.last.finishedAt.toLocal()),
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Legend(color: theme.colorScheme.primary, label: 'Sessions'),
              if (trendValues.isNotEmpty)
                _Legend(color: trendColor, label: 'Trend (questions)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.points,
    required this.trendValues,
    required this.minimumScore,
    required this.targetScore,
    required this.lineColor,
    required this.trendColor,
    required this.gridColor,
    required this.successColor,
    required this.errorColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<TopicProgressPoint> points;
  final List<double> trendValues;
  final int minimumScore;
  final int targetScore;
  final Color lineColor;
  final Color trendColor;
  final Color gridColor;
  final Color successColor;
  final Color errorColor;
  final Color labelColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 12.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final value in const [0.0, 0.5, 1.0]) {
      final y = chart.bottom - chart.height * value;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _label(
        canvas,
        '${(value * 100).round()}',
        Offset(0, y - 7),
        textStyle.copyWith(color: labelColor),
      );
    }

    final count = points.length;
    double xFor(int index) {
      if (count == 1) return chart.center.dx;
      return chart.left + chart.width * index / (count - 1);
    }

    double yFor(double score) => chart.bottom - chart.height * score;

    canvas.save();
    canvas.clipRect(chart);

    final trend = trendValues;
    if (trend.length == count && count > 1) {
      final paint = Paint()
        ..color = trendColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var index = 1; index < count; index++) {
        _drawDashedLine(
          canvas,
          Offset(xFor(index - 1), yFor(trend[index - 1])),
          Offset(xFor(index), yFor(trend[index])),
          paint,
        );
      }
    }

    final path = Path();
    for (var index = 0; index < count; index++) {
      final point = Offset(xFor(index), yFor(points[index].score));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var index = 0; index < count; index++) {
      final score = points[index].score;
      final band = scoreBandFor(
        score,
        minimumScore: minimumScore,
        targetScore: targetScore,
      );
      final color = switch (band) {
        ScoreBand.targetMet => successColor,
        ScoreBand.onTrack => lineColor,
        ScoreBand.belowMinimum => errorColor,
      };
      final point = Offset(xFor(index), yFor(score));
      canvas.drawCircle(point, 4.5, Paint()..color = color);
    }

    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    var travelled = 0.0;
    while (travelled < distance) {
      final segmentEnd = math.min(travelled + dash, distance);
      canvas.drawLine(
        start + direction * travelled,
        start + direction * segmentEnd,
        paint,
      );
      travelled += dash + gap;
    }
  }

  void _label(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.trendValues != trendValues ||
        oldDelegate.minimumScore != minimumScore ||
        oldDelegate.targetScore != targetScore ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.successColor != successColor ||
        oldDelegate.errorColor != errorColor;
  }
}

class _SubtopicRow extends StatelessWidget {
  const _SubtopicRow({
    required this.stat,
    required this.minimumScore,
    required this.targetScore,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final SubtopicStat stat;
  final int minimumScore;
  final int targetScore;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = (stat.accuracy * 100).round();
    final band = stat.answeredCount == 0
        ? null
        : scoreBandFor(
            stat.accuracy,
            minimumScore: minimumScore,
            targetScore: targetScore,
          );
    final tone = band == null ? PillTone.neutral : scoreBandPillTone(band);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: band == null
                    ? '${stat.label}: no answers yet'
                    : scoreSemanticsLabel(
                        subject: '${stat.label} accuracy',
                        percent: accuracy,
                        band: band,
                      ),
                excludeSemantics: true,
                child: Pill('$accuracy% accuracy', tone: tone),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearScore(value: stat.progress),
          const SizedBox(height: 5),
          Text(
            '${stat.attemptedQuestionCount}/${stat.questionCount} questions · '
            '${stat.correctCount}/${stat.answeredCount} correct',
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: stat.label,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.point,
    required this.minimumScore,
    required this.targetScore,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final TopicProgressPoint point;
  final int minimumScore;
  final int targetScore;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final percent = (point.score * 100).round();
    final band = scoreBandFor(
      point.score,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: '${point.practiceName}, ${point.correct}/${point.total}',
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.practiceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.baseline.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMMd().add_Hm().format(
                          point.finishedAt.toLocal(),
                        ),
                        style: theme.typography.baseline.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: scoreSemanticsLabel(
                    subject: '${point.practiceName} score',
                    percent: percent,
                    band: band,
                  ),
                  excludeSemantics: true,
                  child: Pill(
                    '${point.correct}/${point.total} · $percent%',
                    tone: scoreBandPillTone(band),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
