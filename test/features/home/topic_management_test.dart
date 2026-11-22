import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/home/home_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Finder archivedButton() => find.byWidgetPredicate(
    (widget) => widget is M3EIconButton && widget.tooltip == 'Archived topics',
  );

  Finder shuffleFab() => find.byWidgetPredicate(
    (widget) => widget is M3EFab && widget.tooltip == 'Start shuffled practice',
  );

  testWidgets('archiving hides a topic and the archived sheet restores it', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
    );

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('Cloud'), findsOneWidget);

    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);
    expect(find.byType(OptionTile), findsNWidgets(3));
    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.text('Download topic JSON'), findsNothing);
    expect(find.text('Update topic JSON'), findsNothing);
    expect(find.text('Archive topic'), findsOneWidget);
    expect(find.text('Delete topic'), findsOneWidget);

    await tester.tap(find.text('Archive topic'));
    await pumpFrames(tester);
    expect(find.text('Cloud'), findsNothing);
    expect(find.text('No active topics'), findsOneWidget);
    expect(
      (await harness.practices.topicById(seeded.topicId))!.archived,
      isTrue,
    );
    expect(tester.widget<M3EIconButton>(archivedButton()).badgeValue, isNull);
    expect(find.byType(Badge), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    await tester.tap(archivedButton());
    await pumpFrames(tester);
    expect(find.text('Archived topics'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    await tester.tap(find.text('Cloud'));
    await pumpFrames(tester);
    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.text('Unarchive topic'), findsOneWidget);
    expect(find.text('Delete topic'), findsOneWidget);

    await tester.tap(find.text('Unarchive topic'));
    await pumpFrames(tester);
    expect(find.text('Cloud'), findsOneWidget);
    expect(
      (await harness.practices.topicById(seeded.topicId))!.archived,
      isFalse,
    );
  });

  testWidgets('long pressing a topic opens the edit dialog', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit topic'));
    await pumpFrames(tester);

    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.byType(OptionTile), findsNWidgets(8));
    expect(find.text('AnkiDroid deck'), findsOneWidget);
    expect(find.text('Download topic JSON'), findsOneWidget);
    expect(find.text('Update topic JSON'), findsOneWidget);
    expect(find.text('Browse decks'), findsNothing);
    await tester.ensureVisible(find.text('AnkiDroid deck'));
    await pumpFrames(tester);
    await tester.tap(find.text('AnkiDroid deck'));
    await pumpFrames(tester);
    expect(find.text('Browse decks'), findsOneWidget);
    await tester.tap(find.text('AnkiDroid deck'));
    await pumpFrames(tester);
    expect(find.text('Browse decks'), findsNothing);
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.text('Edit topic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the archived sheet explains when nothing is archived', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.tap(archivedButton());
    await pumpFrames(tester);

    expect(find.text('Archived topics'), findsOneWidget);
    expect(find.text('No archived topics'), findsOneWidget);
  });

  testWidgets('home topic sorting survives a page rebuild', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Alpha', practiceName: 'A', count: 1);
    await harness.seedPractice(topicName: 'Zeta', practiceName: 'Z', count: 1);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Alpha'), lessThan(top('Zeta')));

    await tester.tap(find.byIcon(Icons.sort));
    await pumpFrames(tester);
    await tester.tap(find.text('Name'));
    await tester.tap(find.text('Decreasing'));
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    expect(top('Zeta'), lessThan(top('Alpha')));

    await tester.pumpWidget(const SizedBox());
    await pumpFrames(tester);
    await pumpTestApp(tester, home: const HomePage(), harness: harness);

    expect(top('Zeta'), lessThan(top('Alpha')));
  });

  testWidgets('the shuffle FAB opens a start sheet and launches practice', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 2);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('Shuffle'), findsNothing);
    await tester.tap(shuffleFab());
    await pumpFrames(tester);

    expect(find.text('Start shuffled practice'), findsOneWidget);
    expect(
      find.text(
        'Mixed questions from every topic, unsolved and unskipped only, in '
        'random order.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Start practice'));
    await pumpFrames(tester);

    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shuffle sheet stays compact with no option rows', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 5);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.tap(shuffleFab());
    await pumpFrames(tester);

    expect(find.text('Every topic'), findsNothing);
    expect(find.text('Unsolved and unskipped only'), findsNothing);
    expect(find.text('Random order'), findsNothing);
    expect(find.text('Questions come from your whole library.'), findsNothing);
    expect(find.byType(OptionTile), findsNothing);
    expect(find.byIcon(Icons.public), findsNothing);
    expect(find.byIcon(Icons.filter_alt_off_outlined), findsNothing);
    expect(find.text('Questions'), findsWidgets);
    expect(find.text('Start practice'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shuffle-question-count')),
      findsOneWidget,
    );
  });

  testWidgets('the shuffle sheet reports when no question is eligible', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.tap(shuffleFab());
    await pumpFrames(tester);
    await tester.tap(find.text('Start practice'));
    await pumpFrames(tester);

    expect(
      find.text('No unsolved questions are left for shuffled practice.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
