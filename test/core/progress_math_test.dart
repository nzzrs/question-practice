import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/domain/progress_math.dart';

void main() {
  TopicProgressPoint point(int day, double score) {
    return TopicProgressPoint(
      sessionId: day + 1,
      finishedAt: DateTime.utc(2026, 1, 1).add(Duration(days: day)),
      practiceName: 'Practice',
      correct: (score * 10).round(),
      total: 10,
    );
  }

  group('fitProgressBySession', () {
    test('a flat history has a zero slope', () {
      final fit = fitProgressBySession(const [0.5, 0.5, 0.5]);

      expect(fit, isNotNull);
      expect(fit!.slope, 0);
      expect(fit.valueAt(0), 0.5);
      expect(fit.valueAt(2), 0.5);
    });

    test('an upward history has a positive slope', () {
      final fit = fitProgressBySession(const [0.2, 0.4, 0.6]);

      expect(fit, isNotNull);
      expect(fit!.slope, closeTo(0.2, 1e-9));
      expect(fit.intercept, closeTo(0.2, 1e-9));
      expect(fit.valueAt(2), closeTo(0.6, 1e-9));
    });

    test('a downward history has a negative slope', () {
      final fit = fitProgressBySession(const [0.9, 0.6, 0.3]);

      expect(fit, isNotNull);
      expect(fit!.slope, closeTo(-0.3, 1e-9));
      expect(fit.valueAt(2), closeTo(0.3, 1e-9));
    });

    test('fewer than two points produce no line', () {
      expect(fitProgressBySession(const []), isNull);
      expect(fitProgressBySession(const [0.7]), isNull);
    });
  });

  group('learningRatePercentagePointsPerWeek', () {
    test('reports the average points gained per week', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(0, 0.2),
        point(7, 0.4),
        point(14, 0.6),
      ]);

      expect(rate, isNotNull);
      expect(rate!, closeTo(20, 1e-9));
    });

    test('reports a negative rate when scores fall', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(0, 0.8),
        point(7, 0.6),
        point(14, 0.4),
      ]);

      expect(rate, isNotNull);
      expect(rate!, closeTo(-20, 1e-9));
    });

    test('needs at least one week of history', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(0, 0.2),
        point(3, 0.5),
        point(6, 0.8),
      ]);

      expect(rate, isNull);
    });

    test('a single point has no rate', () {
      expect(learningRatePercentagePointsPerWeek([point(0, 0.5)]), isNull);
      expect(learningRatePercentagePointsPerWeek(const []), isNull);
    });

    test('the same timestamp twice has no measurable rate', () {
      final rate = learningRatePercentagePointsPerWeek([
        point(0, 0.2),
        point(0, 0.8),
      ]);

      expect(rate, isNull);
    });
  });
}
