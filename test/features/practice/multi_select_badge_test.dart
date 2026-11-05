import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

Future<SeededPractice> _seedQuestion(
  TestHarness harness, {
  required List<int> correctIndexes,
}) async {
  final now = harness.clock.now().toUtc();
  final topicId = await harness.practices.createTopic(
    name: 'Topic',
    description: '',
    priority: 1,
    createdAt: now,
  );
  final practiceId = await harness.practices.createPractice(
    topicId: topicId,
    name: 'Practice',
    description: '',
    contentHash: 'badge-${correctIndexes.join('-')}',
    importedAt: now,
  );
  await harness.practices.createQuestions(practiceId, [
    QuestionDraft(
      prompt: 'Pick the correct alternatives?',
      alternatives: const ['First', 'Second', 'Third'],
      correctIndexes: correctIndexes,
      explanation: 'Explanation.',
      alternativeExplanations: const ['One', 'Two', 'Three'],
    ),
  ]);
  return SeededPractice(topicId: topicId, practiceId: practiceId);
}

Future<void> _showLetters(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.visibility_off_outlined));
  await pumpFrames(tester);
}

void main() {
  testWidgets('multi-answer alternatives use square letter badges', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedQuestion(harness, correctIndexes: const [0, 2]);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await _showLetters(tester);

    for (final index in [0, 1, 2]) {
      final badge = tester.widget<Container>(
        find.byKey(ValueKey('alternative-letter-badge-$index')),
      );
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(8),
        reason: 'multi-select alternatives should show a square badge',
      );
    }
  });

  testWidgets('single-answer alternatives keep circular letter badges', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedQuestion(harness, correctIndexes: const [0]);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await _showLetters(tester);

    final badge = tester.widget<Container>(
      find.byKey(const ValueKey('alternative-letter-badge-0')),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.borderRadius, isNull);
  });
}
