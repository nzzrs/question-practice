import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

/// Always picks the first slot, which reverses small alternative lists.
class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

void main() {
  test('session items carry a shuffled alternative order', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
      random: _ZeroRandom(),
    );

    final start = await service.startPractice(seeded.practiceId);

    expect(start.items.single.alternativeOrder, [1, 0]);
  });

  testWidgets('original letters stay hidden until the eye or feedback', (
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
      random: _ZeroRandom(),
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await pumpFrames(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Wrong 1')).dy,
      lessThan(tester.getTopLeft(find.text('Correct 1')).dy),
    );

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await pumpFrames(tester);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('B')).dy,
      lessThan(tester.getTopLeft(find.text('A')).dy),
    );
  });
}
