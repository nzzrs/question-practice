import 'models.dart';

/// A least-squares line fitted through progress points.
class LinearProgressFit {
  const LinearProgressFit({required this.slope, required this.intercept});

  final double slope;
  final double intercept;

  double valueAt(double x) => intercept + slope * x;
}

/// Fits a line through scores ordered by session index.
///
/// Returns null when there are fewer than two points or every index is equal,
/// which happens only for an empty or single-point series.
LinearProgressFit? fitProgressBySession(List<double> scores) {
  if (scores.length < 2) return null;
  final xs = [
    for (var index = 0; index < scores.length; index++) index.toDouble(),
  ];
  return _leastSquares(xs, scores);
}

/// Fits a line through progress points using elapsed days as the x axis.
LinearProgressFit? fitProgressByTime(List<TopicProgressPoint> points) {
  final timed = _timedPoints(points);
  if (timed == null) return null;
  return _leastSquares(timed.days, timed.scores);
}

/// Average percentage-point change per week from the progress history.
///
/// The value comes from the least-squares slope of score against elapsed days,
/// multiplied by seven. It returns null until the history spans at least one
/// week, so a single session or a short burst never reports a rate.
double? learningRatePercentagePointsPerWeek(List<TopicProgressPoint> points) {
  final timed = _timedPoints(points);
  if (timed == null) return null;
  final span = timed.lastDay - timed.days.first;
  if (span < 7) return null;
  final fit = _leastSquares(timed.days, timed.scores);
  if (fit == null) return null;
  return fit.slope * 7 * 100;
}

class _TimedPoints {
  const _TimedPoints({
    required this.days,
    required this.scores,
    required this.lastDay,
  });

  final List<double> days;
  final List<double> scores;
  final double lastDay;
}

_TimedPoints? _timedPoints(List<TopicProgressPoint> points) {
  if (points.length < 2) return null;
  final sorted = List<TopicProgressPoint>.of(points)
    ..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));
  final first = sorted.first.finishedAt.toUtc();
  final days = <double>[];
  final scores = <double>[];
  for (final point in sorted) {
    final elapsed = point.finishedAt.toUtc().difference(first);
    days.add(elapsed.inMicroseconds / Duration.microsecondsPerDay);
    scores.add(point.score);
  }
  return _TimedPoints(days: days, scores: scores, lastDay: days.last);
}

LinearProgressFit? _leastSquares(List<double> xs, List<double> ys) {
  if (xs.length < 2 || xs.length != ys.length) return null;
  final count = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / count;
  final meanY = ys.reduce((a, b) => a + b) / count;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var index = 0; index < count; index++) {
    final dx = xs[index] - meanX;
    numerator += dx * (ys[index] - meanY);
    denominator += dx * dx;
  }
  if (denominator == 0) return null;
  final slope = numerator / denominator;
  return LinearProgressFit(slope: slope, intercept: meanY - slope * meanX);
}
