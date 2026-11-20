import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/score_band.dart';
import 'app_metrics.dart';
import 'app_sections.dart';
import 'app_success.dart';

/// Maps a [ScoreBand] to the app's compact status tone.
///
/// Only a met target is green. An on-track score uses the neutral pill and
/// metric surfaces so the normal state never reads as success.
PillTone scoreBandPillTone(ScoreBand band) {
  return switch (band) {
    ScoreBand.targetMet => PillTone.success,
    ScoreBand.onTrack => PillTone.neutral,
    ScoreBand.belowMinimum => PillTone.error,
  };
}

/// Maps a [ScoreBand] to a metric tile tone with the same success rule.
MetricTone scoreBandMetricTone(ScoreBand band) {
  return switch (band) {
    ScoreBand.targetMet => MetricTone.success,
    ScoreBand.onTrack => MetricTone.neutral,
    ScoreBand.belowMinimum => MetricTone.error,
  };
}

/// The accent color for a score ring or chart dot in [band].
///
/// The normal band uses the theme's primary color; it is deliberately not the
/// success green.
Color scoreBandColor(BuildContext context, ScoreBand band) {
  final scheme = M3ETheme.of(context).colorScheme;
  return switch (band) {
    ScoreBand.targetMet => AppSuccess.foreground(context),
    ScoreBand.onTrack => scheme.primary,
    ScoreBand.belowMinimum => scheme.error,
  };
}

/// Builds a screen-reader sentence for a percentage score in its band.
String scoreSemanticsLabel({
  required String subject,
  required int percent,
  required ScoreBand band,
}) {
  return '$subject: $percent percent, ${scoreBandLabel(band).toLowerCase()}';
}
