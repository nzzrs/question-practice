import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/domain/progress_math.dart';
import '../../core/ui/widgets.dart';

class TopicStatsPage extends ConsumerStatefulWidget {
  const TopicStatsPage({required this.topicId, super.key});

  final int topicId;

  @override
  ConsumerState<TopicStatsPage> createState() => _TopicStatsPageState();
}

class _TopicStatsPageState extends ConsumerState<TopicStatsPage> {
  bool _exporting = false;

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
      actions: [
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
            final latest = points.last;
            final best = points.map((point) => point.score).reduce(math.max);
            final average =
                points.map((point) => point.score).reduce((a, b) => a + b) /
                points.length;
            final fit = fitProgressBySession([
              for (final point in points) point.score,
            ]);
            final learningRate = learningRatePercentagePointsPerWeek(points);
            final hasSubtopics = subtopics.any((stat) => !stat.isUncategorized);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendHero(
                  points: points,
                  latest: latest,
                  average: average,
                  best: best,
                  learningRate: learningRate,
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  'Progress over time',
                  count: points.length,
                  supporting: 'Each point is one completed session.',
                ),
                _ProgressChart(points: points, fit: fit),
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
                      for (final stat in subtopics) _SubtopicRow(stat: stat),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const SectionTitle('Sessions'),
                AppGroup(
                  children: [
                    for (final point in points.reversed)
                      _ProgressRow(point: point),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
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
    required this.learningRate,
  });

  final List<TopicProgressPoint> points;
  final TopicProgressPoint latest;
  final double average;
  final double best;

  /// Percentage points per week, or null until the history spans a week.
  final double? learningRate;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final strong = latest.score > 0.8;
    final rate = learningRate;
    return TonalBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(
                value: latest.score,
                label: '${(latest.score * 100).round()}%',
                caption: 'Latest',
                size: 112,
                strokeWidth: 11,
                color: strong ? AppSuccess.foreground(context) : null,
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
                    Text(
                      '${points.length} completed session${points.length == 1 ? '' : 's'}',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Best ${(best * 100).round()}% · average ${(average * 100).round()}%',
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
                  icon: Icons.timeline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Best',
                  value: '${(best * 100).round()}%',
                  icon: Icons.emoji_events_outlined,
                  tone: best > 0.8 ? MetricTone.success : MetricTone.neutral,
                ),
              ),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: 8),
            MetricTile(
              label: 'Learning rate',
              value: _learningRateLabel(rate),
              caption: 'Average change per week',
              icon: rate < 0 ? Icons.trending_down : Icons.trending_up,
              tone: rate > 0
                  ? MetricTone.success
                  : rate < 0
                  ? MetricTone.error
                  : MetricTone.neutral,
            ),
          ],
        ],
      ),
    );
  }

  String _learningRateLabel(double rate) {
    final rounded = rate.round();
    final prefix = rounded > 0 ? '+' : '';
    return '$prefix$rounded pp/week';
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
  const _ProgressChart({required this.points, required this.fit});

  final List<TopicProgressPoint> points;
  final LinearProgressFit? fit;

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
                fit: fit,
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
              if (fit != null) _Legend(color: trendColor, label: 'Trend'),
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
    required this.fit,
    required this.lineColor,
    required this.trendColor,
    required this.gridColor,
    required this.successColor,
    required this.errorColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<TopicProgressPoint> points;
  final LinearProgressFit? fit;
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

    final trend = fit;
    if (trend != null && count > 1) {
      _drawDashedLine(
        canvas,
        Offset(xFor(0), yFor(trend.valueAt(0))),
        Offset(xFor(count - 1), yFor(trend.valueAt(count - 1))),
        Paint()
          ..color = trendColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
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
      final color = score > 0.8
          ? successColor
          : score < 0.5
          ? errorColor
          : lineColor;
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
        oldDelegate.fit != fit ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.successColor != successColor ||
        oldDelegate.errorColor != errorColor;
  }
}

class _SubtopicRow extends StatelessWidget {
  const _SubtopicRow({required this.stat});

  final SubtopicStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = (stat.accuracy * 100).round();
    final tone = stat.answeredCount == 0
        ? PillTone.neutral
        : stat.accuracy > 0.8
        ? PillTone.success
        : stat.accuracy < 0.5
        ? PillTone.error
        : PillTone.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Pill('$accuracy% accuracy', tone: tone),
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
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.point});

  final TopicProgressPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final percent = (point.score * 100).round();
    final tone = point.score > 0.8
        ? PillTone.success
        : point.score < 0.5
        ? PillTone.error
        : PillTone.neutral;
    return Padding(
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
          Pill('${point.correct}/${point.total} · $percent%', tone: tone),
        ],
      ),
    );
  }
}
