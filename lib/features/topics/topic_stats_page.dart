import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';

class TopicStatsPage extends ConsumerWidget {
  const TopicStatsPage({required this.topicId, super.key});

  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final summary = ref.watch(topicSummaryProvider(topicId));
    final progress = ref.watch(topicProgressProvider(topicId));

    return AppPage(
      title: 'Statistics',
      showBack: true,
      variant: M3EAppBarVariant.small,
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendHero(
                  points: points,
                  latest: latest,
                  average: average,
                  best: best,
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  'Progress over time',
                  count: points.length,
                  supporting: 'Each point is one completed session.',
                ),
                _ProgressChart(points: points),
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
}

class _TrendHero extends StatelessWidget {
  const _TrendHero({
    required this.points,
    required this.latest,
    required this.average,
    required this.best,
  });

  final List<TopicProgressPoint> points;
  final TopicProgressPoint latest;
  final double average;
  final double best;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final strong = latest.score > 0.8;
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
        ],
      ),
    );
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
  const _ProgressChart({required this.points});

  final List<TopicProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
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
                lineColor: theme.colorScheme.primary,
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
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.successColor,
    required this.errorColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<TopicProgressPoint> points;
  final Color lineColor;
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
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.successColor != successColor ||
        oldDelegate.errorColor != errorColor;
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
