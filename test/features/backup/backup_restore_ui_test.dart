import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/backup/domain/backup_service.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/topics/topic_actions.dart';

import '../../helpers/test_harness.dart';

class _TopicEditHost extends ConsumerWidget {
  const _TopicEditHost({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: M3EButton.filled(
          onPressed: () => showEditTopicDialog(context, ref, topic),
          child: const Text('edit'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('a restored topic deck shows in Home and topic editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      ankiDeck: 'Cloud deck',
    );
    final service = BackupService(
      database: harness.database,
      clock: harness.clock,
    );
    final encoded = await service.encode();
    await harness.practices.updateTopic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Topic description',
      priority: 1,
      ankiDeck: null,
    );

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('Cloud'), findsOneWidget);

    await harness.database.clearAll();
    await service.restoreText(encoded);
    await pumpFrames(tester);

    final stored = (await harness.practices.allTopics()).single;
    expect(stored.ankiDeck, 'Cloud deck');
    final summaries = await harness.practices.watchTopicSummaries().first;
    expect(summaries.single.topic.ankiDeck, 'Cloud deck');

    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit topic'));
    await pumpFrames(tester);

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text)
        .toList();
    expect(fields, contains('Cloud deck'));
  });

  testWidgets('topic editing re-reads the topic so a stale snapshot cannot '
      'clear the deck', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      ankiDeck: 'Cloud deck',
    );
    // A summary captured before a restore or another database replacement.
    final stale = Topic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Stale description',
      priority: null,
      ankiDeck: null,
      createdAt: harness.clock.now().toUtc(),
      archived: false,
    );

    await pumpTestApp(
      tester,
      home: _TopicEditHost(topic: stale),
      harness: harness,
    );
    await tester.tap(find.text('edit'));
    await pumpFrames(tester);

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text)
        .toList();
    expect(fields, contains('Cloud deck'));
    expect(fields, contains('Topic description'));

    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    final stored = (await harness.practices.allTopics()).single;
    expect(stored.ankiDeck, 'Cloud deck');
  });
}
