import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() {
    harness = TestHarness();
  });

  tearDown(() async {
    await harness.close();
  });

  test('topic deck is stored and can be cleared', () async {
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      ankiDeck: 'Cloud deck',
    );
    var summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.topic.ankiDeck, 'Cloud deck');

    await harness.practices.updateTopic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Updated',
      priority: 1,
      ankiDeck: null,
    );
    summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.topic.ankiDeck, isNull);
    expect(summary.topic.description, 'Updated');
  });
}
