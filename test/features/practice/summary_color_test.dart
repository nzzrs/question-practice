import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/summary_page.dart';

import '../../helpers/test_harness.dart';

Future<SessionSummary> _complete(
  TestHarness harness, {
  required List<bool> correct,
}) async {
  final practice = await harness.seedPractice(count: correct.length);
  final service = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  final start = await service.startPractice(practice.practiceId);
  SessionSummary? summary;
  for (var index = 0; index < start.items.length; index++) {
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items[index],
      selectedIndexes: [correct[index] ? 0 : 1],
      reasoning: '',
      distracted: false,
    );
    summary = outcome.summary ?? summary;
  }
  return summary!;
}

void main() {
  testWidgets('results above 80 percent use the green score ring', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final summary = await _complete(harness, correct: const [true, true]);

    await pumpTestApp(
      tester,
      home: SummaryPage(summary: summary),
      harness: harness,
    );
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(ScoreRing));
    expect(ring.color, AppSuccess.foreground(context));
  });

  testWidgets('results at 80 percent keep the theme color', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final summary = await _complete(
      harness,
      correct: const [true, true, true, true, false],
    );

    await pumpTestApp(
      tester,
      home: SummaryPage(summary: summary),
      harness: harness,
    );
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    expect(ring.color, isNull);
  });
}
