import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/domain/progress_math.dart';

void main() {
  TopicProgressPoint point({
    required DateTime finishedAt,
    required int correct,
    required int total,
    int sessionId = 0,
  }) {
    return TopicProgressPoint(
      sessionId: sessionId,
      finishedAt: finishedAt,
      practiceName: 'Practice',
      correct: correct,
      total: total,
    );
  }

  final jan1 = DateTime(2026, 1, 1, 10);
  final jan2 = DateTime(2026, 1, 2, 10);
  final jan5 = DateTime(2026, 1, 5, 10);

  group('weightedAverageScore', () {
    test('weights session scores by the questions answered', () {
      // A plain mean of the session percentages would report 75%.
      final average = weightedAverageScore([
        point(finishedAt: jan1, correct: 5, total: 10),
        point(finishedAt: jan2, correct: 30, total: 30),
      ]);

      expect(average, isNotNull);
      expect(average!, closeTo(35 / 40, 1e-9));
    });

    test('has no average without answered questions', () {
      expect(weightedAverageScore(const []), isNull);
      expect(
        weightedAverageScore([point(finishedAt: jan1, correct: 0, total: 0)]),
        isNull,
      );
    });
  });

  group('fitProgressWeightedByQuestions', () {
    test('fits score against cumulative questions with question weights', () {
      final fit = fitProgressWeightedByQuestions([
        point(finishedAt: jan1, correct: 5, total: 10),
        point(finishedAt: jan2, correct: 30, total: 30),
      ]);

      expect(fit, isNotNull);
      expect(fit!.slope, closeTo(1 / 60, 1e-9));
      expect(fit.intercept, closeTo(1 / 3, 1e-9));
      expect(fit.valueAt(10), closeTo(0.5, 1e-9));
      expect(fit.valueAt(40), closeTo(1, 1e-9));
    });

    test('orders points by finish time before accumulating questions', () {
      final late = point(
        finishedAt: jan2,
        correct: 30,
        total: 30,
        sessionId: 2,
      );
      final early = point(
        finishedAt: jan1,
        correct: 5,
        total: 10,
        sessionId: 1,
      );

      final fit = fitProgressWeightedByQuestions([late, early]);

      expect(fit, isNotNull);
      expect(fit!.slope, closeTo(1 / 60, 1e-9));
    });

    test('a flat history has a zero slope', () {
      final fit = fitProgressWeightedByQuestions([
        point(finishedAt: jan1, correct: 5, total: 10),
        point(finishedAt: jan2, correct: 15, total: 30),
      ]);

      expect(fit, isNotNull);
      expect(fit!.slope, closeTo(0, 1e-12));
      expect(fit.valueAt(10), closeTo(0.5, 1e-12));
      expect(fit.valueAt(40), closeTo(0.5, 1e-12));
    });

    test('fewer than two points produce no line', () {
      expect(fitProgressWeightedByQuestions(const []), isNull);
      expect(
        fitProgressWeightedByQuestions([
          point(finishedAt: jan1, correct: 5, total: 10),
        ]),
        isNull,
      );
    });

    test('zero total weights produce no line', () {
      final fit = fitProgressWeightedByQuestions([
        point(finishedAt: jan1, correct: 0, total: 0),
        point(finishedAt: jan2, correct: 0, total: 0),
      ]);

      expect(fit, isNull);
    });
  });

  group('learning rates', () {
    final points = [
      point(finishedAt: jan1, correct: 5, total: 10),
      point(finishedAt: jan2, correct: 30, total: 30),
    ];

    test('converts the weighted slope to points per 100 questions', () {
      final rate = learningRatePercentagePointsPer100Questions(points);

      expect(rate, isNotNull);
      expect(rate!, closeTo(10000 / 60, 1e-9));
    });

    test('converts the weighted slope to points per week', () {
      // Two active days and 40 answered questions: 20 questions per day.
      final rate = learningRatePercentagePointsPerWeek(points);

      expect(rate, isNotNull);
      expect(rate!, closeTo((1 / 60) * 20 * 7 * 100, 1e-9));
    });

    test('two sessions on the same day use one active day', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(finishedAt: jan1, correct: 5, total: 10),
        point(
          finishedAt: jan1.add(const Duration(hours: 2)),
          correct: 30,
          total: 30,
        ),
      ]);

      expect(rate, isNotNull);
      expect(rate!, closeTo((1 / 60) * 40 * 7 * 100, 1e-9));
    });

    test('needs a fit', () {
      expect(
        learningRatePercentagePointsPer100Questions([
          point(finishedAt: jan1, correct: 5, total: 10),
        ]),
        isNull,
      );
      expect(
        learningRatePercentagePointsPerWeek([
          point(finishedAt: jan1, correct: 0, total: 0),
          point(finishedAt: jan2, correct: 0, total: 0),
        ]),
        isNull,
      );
    });

    test('reports a negative rate when scores fall', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(finishedAt: jan1, correct: 30, total: 30),
        point(finishedAt: jan2, correct: 5, total: 10),
      ]);

      expect(rate, isNotNull);
      expect(rate!, lessThan(0));
    });
  });

  group('activeStudyDays', () {
    test('counts distinct local calendar dates', () {
      expect(
        activeStudyDays([
          point(finishedAt: jan1, correct: 1, total: 2),
          point(
            finishedAt: jan1.add(const Duration(hours: 8)),
            correct: 1,
            total: 2,
          ),
          point(finishedAt: jan2, correct: 1, total: 2),
          point(finishedAt: jan5, correct: 1, total: 2),
        ]),
        3,
      );
    });

    test('is zero without sessions', () {
      expect(activeStudyDays(const []), 0);
    });
  });
}
