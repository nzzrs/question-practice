import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/score_band.dart';

void main() {
  group('scoreBandFor', () {
    test('classifies scores against the topic thresholds', () {
      expect(
        scoreBandFor(0.69, minimumScore: 70, targetScore: 80),
        ScoreBand.belowMinimum,
      );
      expect(
        scoreBandFor(0.7, minimumScore: 70, targetScore: 80),
        ScoreBand.onTrack,
      );
      expect(
        scoreBandFor(0.79, minimumScore: 70, targetScore: 80),
        ScoreBand.onTrack,
      );
      expect(
        scoreBandFor(0.8, minimumScore: 70, targetScore: 80),
        ScoreBand.targetMet,
      );
      expect(
        scoreBandFor(1, minimumScore: 70, targetScore: 80),
        ScoreBand.targetMet,
      );
    });

    test('honours custom thresholds', () {
      expect(
        scoreBandFor(0.4, minimumScore: 50, targetScore: 90),
        ScoreBand.belowMinimum,
      );
      expect(
        scoreBandFor(0.5, minimumScore: 50, targetScore: 90),
        ScoreBand.onTrack,
      );
      expect(
        scoreBandFor(0.9, minimumScore: 50, targetScore: 90),
        ScoreBand.targetMet,
      );
    });

    test('treats a missing score as below the minimum', () {
      expect(
        scoreBandFor(double.nan, minimumScore: 70, targetScore: 80),
        ScoreBand.belowMinimum,
      );
    });
  });

  group('weeksToTarget', () {
    test('is zero when the average already reaches the target', () {
      expect(
        weeksToTarget(
          average: 0.85,
          targetScore: 80,
          percentagePointsPerWeek: 2,
        ),
        0,
      );
    });

    test('is null without a rising pace', () {
      expect(
        weeksToTarget(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: 0,
        ),
        isNull,
      );
      expect(
        weeksToTarget(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: -2,
        ),
        isNull,
      );
      expect(
        weeksToTarget(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: null,
        ),
        isNull,
      );
    });

    test('divides the remaining points by the weekly pace', () {
      expect(
        weeksToTarget(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: 5,
        ),
        closeTo(6, 1e-9),
      );
    });
  });

  group('targetProjectionSentence', () {
    final now = DateTime(2026, 11, 20);

    test('names an already reached target', () {
      expect(
        targetProjectionSentence(
          average: 0.82,
          targetScore: 80,
          percentagePointsPerWeek: null,
          now: now,
        ),
        'The target score is already reached.',
      );
    });

    test('does not promise a target without a rising pace', () {
      expect(
        targetProjectionSentence(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: -1,
          now: now,
        ),
        'At this rate, the target score is not yet in reach.',
      );
    });

    test('projects the target score onto a readable date', () {
      expect(
        targetProjectionSentence(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: 5,
          now: now,
        ),
        'At this rate, you will average the target score by Jan 1, 2027.',
      );
      expect(
        targetProjectionSentence(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: 2,
          now: now,
        ),
        'At this rate, you will average the target score by Mar 5, 2027.',
      );
    });

    test('rounds a partial day up to the next date', () {
      expect(
        targetProjectionSentence(
          average: 0.5,
          targetScore: 80,
          percentagePointsPerWeek: 50,
          now: now,
        ),
        'At this rate, you will average the target score by Nov 25, 2026.',
      );
    });
  });

  test('scoreBandLabel names each band', () {
    expect(scoreBandLabel(ScoreBand.belowMinimum), 'Below minimum');
    expect(scoreBandLabel(ScoreBand.onTrack), 'On track');
    expect(scoreBandLabel(ScoreBand.targetMet), 'Target met');
  });
}
