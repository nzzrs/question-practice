import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('feedback offers "I didn\'t know this" for wrong answers', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
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

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await pumpFrames(tester);

    expect(find.text('I was distracted or read too fast'), findsOneWidget);
    expect(find.text("I didn't know this"), findsOneWidget);
  });
}
