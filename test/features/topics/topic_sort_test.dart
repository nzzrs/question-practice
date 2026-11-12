import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('practice sort is restored when the topic page rebuilds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'Alpha',
      count: 1,
    );
    for (final name in const ['Beta', 'Gamma']) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: name,
        description: '',
        contentHash: 'hash-$name',
        importedAt: harness.clock.now().toUtc(),
      );
    }

    Future<void> showTopic() async {
      await tester.pumpWidget(const SizedBox());
      await pumpFrames(tester);
      await pumpTestApp(
        tester,
        home: TopicPage(topicId: seeded.topicId),
        harness: harness,
      );
    }

    Future<void> applySort(String field, String order) async {
      final button = find.byIcon(Icons.sort);
      await tester.ensureVisible(button);
      await pumpFrames(tester);
      await tester.tap(button);
      await pumpFrames(tester);
      await tester.tap(find.text(field));
      await tester.tap(find.text(order));
      await tester.tap(find.text('Apply'));
      await pumpFrames(tester);
    }

    await showTopic();
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Alpha'), lessThan(top('Beta')));
    expect(top('Beta'), lessThan(top('Gamma')));

    await applySort('Name', 'Decreasing');
    expect(top('Gamma'), lessThan(top('Alpha')));

    await showTopic();
    expect(top('Gamma'), lessThan(top('Alpha')));
  });

  testWidgets('two topics keep independent practice sorts', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await harness.seedPractice(
      topicName: 'First',
      practiceName: 'Alpha',
      count: 1,
    );
    await harness.practices.createPractice(
      topicId: first.topicId,
      name: 'Beta',
      description: '',
      contentHash: 'hash-first-beta',
      importedAt: harness.clock.now().toUtc(),
    );
    final second = await harness.seedPractice(
      topicName: 'Second',
      practiceName: 'Alpha',
      count: 1,
    );
    await harness.practices.createPractice(
      topicId: second.topicId,
      name: 'Zeta',
      description: '',
      contentHash: 'hash-second-zeta',
      importedAt: harness.clock.now().toUtc().add(const Duration(hours: 1)),
    );

    Future<void> showTopic(int topicId) async {
      await tester.pumpWidget(const SizedBox());
      await pumpFrames(tester);
      await pumpTestApp(
        tester,
        home: TopicPage(topicId: topicId),
        harness: harness,
      );
    }

    Future<void> applySort(String field, String order) async {
      final button = find.byIcon(Icons.sort);
      await tester.ensureVisible(button);
      await pumpFrames(tester);
      await tester.tap(button);
      await pumpFrames(tester);
      await tester.tap(find.text(field));
      await tester.tap(find.text(order));
      await tester.tap(find.text('Apply'));
      await pumpFrames(tester);
    }

    double top(String name) => tester.getTopLeft(find.text(name)).dy;

    await showTopic(first.topicId);
    await applySort('Name', 'Decreasing');
    expect(top('Beta'), lessThan(top('Alpha')));

    await showTopic(second.topicId);
    await applySort('Recency', 'Decreasing');
    expect(top('Zeta'), lessThan(top('Alpha')));

    await showTopic(first.topicId);
    expect(top('Beta'), lessThan(top('Alpha')));

    await showTopic(second.topicId);
    expect(top('Zeta'), lessThan(top('Alpha')));
  });
}
