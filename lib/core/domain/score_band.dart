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
  if (average.isNaN || percentagePointsPerWeek == null) return null;
  final averagePercent = average * 100;
  if (averagePercent >= targetScore) return 0;
  if (percentagePointsPerWeek <= 0) return null;
  return (targetScore - averagePercent) / percentagePointsPerWeek;
}
