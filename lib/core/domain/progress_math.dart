import 'models.dart';

/// A least-squares line fitted through progress points.
class LinearProgressFit {
  const LinearProgressFit({required this.slope, required this.intercept});

  final double slope;
  final double intercept;

  double valueAt(double x) => intercept + slope * x;
}

/// Orders progress points oldest first, breaking ties by session id.
List<TopicProgressPoint> orderedProgressPoints(
  Iterable<TopicProgressPoint> points,
) {
  return List<TopicProgressPoint>.of(points)..sort((a, b) {
    final byTime = a.finishedAt.compareTo(b.finishedAt);
    return byTime != 0 ? byTime : a.sessionId.compareTo(b.sessionId);
  });
}

/// Questions answered up to and including each session, oldest first.
List<int> cumulativeQuestionCounts(List<TopicProgressPoint> points) {
  final ordered = orderedProgressPoints(points);
  var answered = 0;
  return [for (final point in ordered) answered += point.total];
}

/// Average score weighted by the questions answered in each session.
///
/// A plain mean of session percentages would let a one-question session count
/// as much as a fifty-question one. Returns null when no question was answered.
double? weightedAverageScore(List<TopicProgressPoint> points) {
  var answered = 0;
  var correct = 0;
  for (final point in points) {
    answered += point.total;
    correct += point.correct;
  }
  if (answered == 0) return null;
  return correct / answered;
}

/// Fits score against cumulative questions answered with question weights.
///
/// Each session's weight is its own question count, and its x value is the
/// number of questions answered through that session. The slope is the score
/// change per answered question. Returns null with fewer than two points, no
/// total weight, or no weighted variance in x.
LinearProgressFit? fitProgressWeightedByQuestions(
  List<TopicProgressPoint> points,
) {
  final ordered = orderedProgressPoints(points);
  if (ordered.length < 2) return null;

  final xs = cumulativeQuestionCounts(ordered);
  final ys = [for (final point in ordered) point.score];
  final weights = [for (final point in ordered) point.total.toDouble()];

  var totalWeight = 0.0;
  var weightedX = 0.0;
  var weightedY = 0.0;
  for (var index = 0; index < ordered.length; index++) {
    totalWeight += weights[index];
    weightedX += weights[index] * xs[index];
    weightedY += weights[index] * ys[index];
  }
  if (totalWeight == 0) return null;

  final meanX = weightedX / totalWeight;
  final meanY = weightedY / totalWeight;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var index = 0; index < ordered.length; index++) {
    final dx = xs[index] - meanX;
    numerator += weights[index] * dx * (ys[index] - meanY);
    denominator += weights[index] * dx * dx;
  }
  if (denominator == 0) return null;

  final slope = numerator / denominator;
  return LinearProgressFit(slope: slope, intercept: meanY - slope * meanX);
}

/// Distinct local calendar dates among completed sessions.
///
/// Returns zero without sessions, otherwise at least one.
int activeStudyDays(List<TopicProgressPoint> points) {
  final dates = <DateTime>{
    for (final point in points) _localDate(point.finishedAt.toLocal()),
  };
  return dates.length;
}

DateTime _localDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// Weighted score change in percentage points per 100 answered questions.
double? learningRatePercentagePointsPer100Questions(
  List<TopicProgressPoint> points,
) {
  final fit = fitProgressWeightedByQuestions(points);
  if (fit == null) return null;
  return fit.slope * 100 * 100;
}

/// Weighted score change in percentage points per week.
///
/// The weekly pace comes from the answered questions divided by the active
/// study days, so a burst of sessions in one day does not fake a week of
/// history. Returns null without a fit or an active day.
double? learningRatePercentagePointsPerWeek(List<TopicProgressPoint> points) {
  final fit = fitProgressWeightedByQuestions(points);
  if (fit == null) return null;
  final days = activeStudyDays(points);
  if (days == 0) return null;
  final answered = points.fold<int>(0, (sum, point) => sum + point.total);
  final questionsPerDay = answered / days;
  if (questionsPerDay == 0) return null;
  return fit.slope * questionsPerDay * 7 * 100;
}
