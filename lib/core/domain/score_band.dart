import 'package:intl/intl.dart';

/// How a score compares with a topic's minimum approval and target scores.
enum ScoreBand {
  /// Below the minimum approval score: the learner should revisit it.
  belowMinimum,

  /// At or above the minimum but below the target: acceptable progress.
  onTrack,

  /// At or above the target: the topic goal is met.
  targetMet,
}

/// Classifies a 0..1 score using integer percentages from the topic.
ScoreBand scoreBandFor(
  double score, {
  required int minimumScore,
  required int targetScore,
}) {
  if (score.isNaN) return ScoreBand.belowMinimum;
  final percent = score * 100;
  if (percent >= targetScore) return ScoreBand.targetMet;
  if (percent >= minimumScore) return ScoreBand.onTrack;
  return ScoreBand.belowMinimum;
}

/// Weeks until the average reaches [targetScore] at the current pace.
///
/// Returns zero when the target is already reached, and null when the pace is
/// missing, flat or falling: in those cases no future average is implied.
double? weeksToTarget({
  required double average,
  required int targetScore,
  required double? percentagePointsPerWeek,
}) {
  if (average.isNaN) return null;
  final averagePercent = average * 100;
  if (averagePercent >= targetScore) return 0;
  if (percentagePointsPerWeek == null) return null;
  if (percentagePointsPerWeek <= 0) return null;
  return (targetScore - averagePercent) / percentagePointsPerWeek;
}

/// Sentence shown under the learning rate for the topic's target score.
///
/// [now] is the page's clock, so the projected date stays deterministic in
/// tests. Whole days are rounded up: a pace that needs a fraction of a day
/// still lands on the next date rather than today.
String targetProjectionSentence({
  required double average,
  required int targetScore,
  required double? percentagePointsPerWeek,
  required DateTime now,
}) {
  final weeks = weeksToTarget(
    average: average,
    targetScore: targetScore,
    percentagePointsPerWeek: percentagePointsPerWeek,
  );
  if (weeks == 0) return 'The target score is already reached.';
  if (weeks == null) {
    return 'At this rate, the target score is not yet in reach.';
  }
  final days = (weeks * 7).ceil();
  final date = DateFormat.yMMMd().format(now.add(Duration(days: days)));
  return 'At this rate, you will average the target score by $date.';
}

/// Short label that names a band without relying on its color.
String scoreBandLabel(ScoreBand band) {
  return switch (band) {
    ScoreBand.belowMinimum => 'Below minimum',
    ScoreBand.onTrack => 'On track',
    ScoreBand.targetMet => 'Target met',
  };
}
