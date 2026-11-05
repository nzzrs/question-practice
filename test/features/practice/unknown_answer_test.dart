import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/domain/review_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService service;

  setUp(() {
    harness = TestHarness();
    service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  test('marking a wrong answer as unknown removes its error card', () async {
    final seeded = await harness.seedPractice(count: 1);
    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: 'No idea really',
      distracted: false,
    );
    expect(await harness.cards.watchErrorCards().first, hasLength(1));

    final updated = await service.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );

    expect(updated.unknown, isTrue);
    expect(updated.isSkipped, isTrue);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
    final session = await harness.sessions.sessionById(start.session.id);
    expect(session!.skipped, 1);
    expect(session.correct, 0);

    final review = await ReviewService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    ).load(start.session.id);
    expect(review!.steps.whereType<SkippedReviewStep>(), hasLength(1));
  });

  test('unmarking unknown restores the error card and the score', () async {
    final seeded = await harness.seedPractice(count: 1);
    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await service.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );

    final restored = await service.setUnknown(
      start: start,
      item: start.items.single,
      unknown: false,
    );

    expect(restored.unknown, isFalse);
    expect(restored.isSkipped, isFalse);
    expect(await harness.cards.watchErrorCards().first, hasLength(1));
    final session = await harness.sessions.sessionById(start.session.id);
    expect(session!.skipped, 0);
    expect(session.total - session.correct - session.skipped, 1);
  });

  test('unknown and distracted stay exclusive', () async {
    final seeded = await harness.seedPractice(count: 1);
    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );

    await service.setDistracted(
      start: start,
      item: start.items.single,
      distracted: true,
    );
    final unknown = await service.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );
    expect(unknown.unknown, isTrue);
    expect(unknown.distracted, isFalse);

    final distracted = await service.setDistracted(
      start: start,
      item: start.items.single,
      distracted: true,
    );
    expect(distracted.distracted, isTrue);
    expect(distracted.unknown, isFalse);
  });
}
