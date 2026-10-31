import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('long pressing a practice renames it', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Rename'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(EditableText).last, 'TCP/IP basics');
    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TCP/IP basics'), findsOneWidget);
    expect(find.text('TCP/IP'), findsNothing);
  });

  testWidgets('long pressing a practice marks it done', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Mark as done'), findsOneWidget);

    await tester.tap(find.text('Mark as done'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a saved practice is marked in progress and asks to continue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(find.text('In progress'), findsOneWidget);

    await tester.ensureVisible(find.text('TCP/IP'));
    await tester.tap(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Continue this practice?'), findsOneWidget);
    expect(find.text('Discard and start another'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sessions = await harness.sessions.latestInProgress();
    expect(sessions!.id, start.session.id);
  });

  testWidgets('practices can be sorted by name or recency', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'Zeta',
      count: 1,
    );
    for (final entry in {
      'Alpha': const Duration(hours: 1),
      'Beta': const Duration(hours: 2),
    }.entries) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: entry.key,
        description: '',
        contentHash: 'hash-${entry.key}',
        importedAt: harness.clock.now().toUtc().add(entry.value),
      );
    }

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Alpha'), lessThan(top('Beta')));
    expect(top('Beta'), lessThan(top('Zeta')));

    Future<void> apply({required String sort, required String order}) async {
      await tester.ensureVisible(find.byIcon(Icons.sort));
      await tester.tap(find.byIcon(Icons.sort));
      await pumpFrames(tester);
      await tester.tap(find.text(sort));
      await tester.tap(find.text(order));
      await tester.tap(find.text('Apply'));
      await pumpFrames(tester);
    }

    await apply(sort: 'Name', order: 'Decreasing');
    expect(top('Zeta'), lessThan(top('Alpha')));

    await apply(sort: 'Recency', order: 'Decreasing');
    expect(top('Beta'), lessThan(top('Alpha')));

    await apply(sort: 'Recency', order: 'Increasing');
    expect(top('Zeta'), lessThan(top('Alpha')));
  });

  testWidgets('practice names sort numbers by value', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'Practice 1',
      count: 1,
    );
    for (final name in const ['Practice 12', 'Practice 2']) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: name,
        description: '',
        contentHash: 'hash-$name',
        importedAt: harness.clock.now().toUtc(),
      );
    }

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Practice 1'), lessThan(top('Practice 2')));
    expect(top('Practice 2'), lessThan(top('Practice 12')));
  });
}
