import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  test(
    'archived topics leave the normal list but keep their content',
    () async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final active = await harness.seedPractice(
        topicName: 'Active',
        practiceName: 'Core',
        count: 2,
      );
      final archived = await harness.seedPractice(
        topicName: 'Archived',
        practiceName: 'Legacy',
        count: 2,
      );

      await harness.practices.setTopicArchived(archived.topicId, true);

      final normal = await harness.practices.watchTopicSummaries().first;
      expect(normal.map((summary) => summary.topic.name), ['Active']);

      final all = await harness.practices
          .watchTopicSummaries(includeArchived: true)
          .first;
      expect(all, hasLength(2));

      final archivedOnly = await harness.practices
          .watchArchivedTopicSummaries()
          .first;
      expect(archivedOnly.single.topic.id, archived.topicId);
      expect(archivedOnly.single.topic.archived, isTrue);
      expect(archivedOnly.single.practiceCount, 1);
      expect(archivedOnly.single.questionCount, 2);

      final topic = await harness.practices.topicById(archived.topicId);
      expect(topic, isNotNull);
      expect(topic!.archived, isTrue);
      expect(
        await harness.practices.questionsForPractice(archived.practiceId),
        hasLength(2),
      );

      await harness.practices.setTopicArchived(archived.topicId, false);
      final restored = await harness.practices.watchTopicSummaries().first;
      expect(
        restored.map((summary) => summary.topic.id),
        contains(archived.topicId),
      );
      expect(
        restored
            .firstWhere((summary) => summary.topic.id == active.topicId)
            .topic
            .archived,
        isFalse,
      );
    },
  );
}
