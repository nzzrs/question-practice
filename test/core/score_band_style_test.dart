import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/score_band.dart';
import 'package:question_practice/core/ui/app_metrics.dart';
import 'package:question_practice/core/ui/app_sections.dart';
import 'package:question_practice/core/ui/score_band_style.dart';

void main() {
  test('pill tones use success only for a met target', () {
    expect(scoreBandPillTone(ScoreBand.targetMet), PillTone.success);
    expect(scoreBandPillTone(ScoreBand.onTrack), PillTone.neutral);
    expect(scoreBandPillTone(ScoreBand.belowMinimum), PillTone.error);
  });

  test('metric tones use success only for a met target', () {
    expect(scoreBandMetricTone(ScoreBand.targetMet), MetricTone.success);
    expect(scoreBandMetricTone(ScoreBand.onTrack), MetricTone.neutral);
    expect(scoreBandMetricTone(ScoreBand.belowMinimum), MetricTone.error);
  });

  test('semantics name the score and its band', () {
    expect(
      scoreSemanticsLabel(
        subject: 'Readiness',
        percent: 75,
        band: ScoreBand.onTrack,
      ),
      'Readiness: 75 percent, on track',
    );
  });
}
