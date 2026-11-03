import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/data/practice_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('splitting creates two evenly sized practices', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 6,
    );
    final original = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      random: Random(7),
    );

    expect(result.sliceA.name, 'TCP/IP Slice A');
    expect(result.sliceB.name, 'TCP/IP Slice B');
    final practices = await harness.practices.allPractices();
    expect(
      practices.map((practice) => practice.name),
      unorderedEquals(['TCP/IP Slice A', 'TCP/IP Slice B']),
    );

    final sliceA = await harness.practices.questionsForPractice(
      result.sliceA.id,
    );
    final sliceB = await harness.practices.questionsForPractice(
      result.sliceB.id,
    );
    expect(sliceA, hasLength(3));
    expect(sliceB, hasLength(3));
    expect(sliceA.map((question) => question.position), [0, 1, 2]);
    expect(sliceB.map((question) => question.position), [0, 1, 2]);
    expect(
      [...sliceA, ...sliceB].map((question) => question.prompt),
      unorderedEquals(original.map((question) => question.prompt)),
    );
  });

  test('splitting needs an even number of questions', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 5,
    );

    await expectLater(
      harness.practices.splitPractice(seeded.practiceId),
      throwsA(isA<PracticeSplitException>()),
    );
    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(5),
    );
  });

  test('split names stay unique inside the topic', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );
    await harness.practices.createPractice(
      topicId: seeded.topicId,
      name: 'TCP/IP Slice A',
      description: '',
      contentHash: 'existing-slice',
      importedAt: harness.clock.now().toUtc(),
    );

    final result = await harness.practices.splitPractice(seeded.practiceId);

    expect(result.sliceA.name, 'TCP/IP Slice A 2');
    expect(result.sliceB.name, 'TCP/IP Slice B');
  });
}
