import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/practice_sound_player.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';
import 'package:question_practice/features/practice/summary_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('correct and wrong answers play their sounds', (tester) async {
    final harness = TestHarness(soundPlayer: RecordingPracticeSoundPlayer());
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 2);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    expect(
      (harness.soundPlayer as RecordingPracticeSoundPlayer).played,
      contains(PracticeSound.correct),
    );

    await tester.tap(find.text('Next question'));
    await pumpFrames(tester);
    await tester.tap(find.text('Wrong 2'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    expect(
      (harness.soundPlayer as RecordingPracticeSoundPlayer).played,
      contains(PracticeSound.wrong),
    );
  });

  testWidgets('finished practice plays the completion sound', (tester) async {
    final harness = TestHarness(soundPlayer: RecordingPracticeSoundPlayer());
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: SummaryPage(summary: outcome.summary!),
      harness: harness,
    );
    expect(
      (harness.soundPlayer as RecordingPracticeSoundPlayer).played,
      contains(PracticeSound.finished),
    );
  });

  testWidgets('disabling practice sounds keeps the session silent', (
    tester,
  ) async {
    final harness = TestHarness(soundPlayer: RecordingPracticeSoundPlayer());
    addTearDown(harness.close);
    await harness.settings.save(const AppSettings(soundsEnabled: false));
    final practice = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    expect(
      (harness.soundPlayer as RecordingPracticeSoundPlayer).played,
      isEmpty,
    );
  });
}
