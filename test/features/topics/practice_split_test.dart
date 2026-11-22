import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/data/practice_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('splitting 10 questions into 3 parts gives 4, 3 and 3', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 10,
    );
    final original = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      parts: 3,
      random: Random(7),
    );

    expect(result.parts.map((practice) => practice.name), [
      'TCP/IP Slice A',
      'TCP/IP Slice B',
      'TCP/IP Slice C',
    ]);
    final slices = <List<String>>[];
    for (final part in result.parts) {
      final questions = await harness.practices.questionsForPractice(part.id);
      expect(
        questions.map((question) => question.position),
        List<int>.generate(questions.length, (index) => index),
      );
      slices.add([for (final question in questions) question.prompt]);
    }
    expect(slices.map((slice) => slice.length), [4, 3, 3]);

    final prompts = [for (final slice in slices) ...slice];
    expect(prompts, hasLength(original.length));
    expect(prompts.toSet(), hasLength(original.length));
    expect(
      prompts,
      unorderedEquals(original.map((question) => question.prompt)),
    );
    expect(
      prompts,
      isNot(original.map((question) => question.prompt).toList()),
      reason: 'questions are dealt from a shuffled list',
    );

    final practices = await harness.practices.allPractices();
    expect(
      practices.map((practice) => practice.name),
      unorderedEquals(['TCP/IP Slice A', 'TCP/IP Slice B', 'TCP/IP Slice C']),
    );
    expect(await harness.practices.practiceById(seeded.practiceId), isNull);
  });

  test('splitting 6 questions into 2 parts keeps the old behavior', () async {
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

    expect(result.parts.map((practice) => practice.name), [
      'TCP/IP Slice A',
      'TCP/IP Slice B',
    ]);
    final sliceA = await harness.practices.questionsForPractice(
      result.parts[0].id,
    );
    final sliceB = await harness.practices.questionsForPractice(
      result.parts[1].id,
    );
    expect(sliceA, hasLength(3));
    expect(sliceB, hasLength(3));
    expect(sliceA.map((question) => question.position), [0, 1, 2]);
    expect(sliceB.map((question) => question.position), [0, 1, 2]);
    expect(
      [...sliceA, ...sliceB].map((question) => question.prompt),
      unorderedEquals(original.map((question) => question.prompt)),
    );
    expect(
      (await harness.practices.allPractices()).map((practice) => practice.name),
      unorderedEquals(['TCP/IP Slice A', 'TCP/IP Slice B']),
    );
  });

  test('splitting 7 questions into 3 parts gives 3, 2 and 2', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 7,
    );

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      parts: 3,
      random: Random(11),
    );

    final sizes = <int>[];
    final prompts = <String>[];
    for (final part in result.parts) {
      final questions = await harness.practices.questionsForPractice(part.id);
      sizes.add(questions.length);
      prompts.addAll(questions.map((question) => question.prompt));
    }
    expect(sizes, [3, 2, 2]);
    expect(prompts.toSet(), hasLength(7));
  });

  test('splitting works with an odd number of questions', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 5,
    );

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      random: Random(3),
    );

    final sizes = <int>[];
    for (final part in result.parts) {
      sizes.add((await harness.practices.questionsForPractice(part.id)).length);
    }
    expect(sizes, [3, 2]);
  });

  test('invalid part counts are blocked without changing data', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 7,
    );

    for (final parts in [0, 1, -2, 8]) {
      await expectLater(
        harness.practices.splitPractice(seeded.practiceId, parts: parts),
        throwsA(isA<PracticeSplitException>()),
      );
      expect(
        (await harness.practices.allPractices()).single.id,
        seeded.practiceId,
      );
      expect(
        await harness.practices.questionsForPractice(seeded.practiceId),
        hasLength(7),
      );
    }
  });

  test('splitting needs at least two questions', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 1,
    );

    await expectLater(
      harness.practices.splitPractice(seeded.practiceId),
      throwsA(isA<PracticeSplitException>()),
    );
    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(1),
    );
  });

  test('split names stay unique inside the topic', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 9,
    );
    for (final name in const ['TCP/IP Slice B', 'TCP/IP Slice B 2']) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: name,
        description: '',
        contentHash: 'existing-$name',
        importedAt: harness.clock.now().toUtc(),
      );
    }

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      parts: 3,
      random: Random(5),
    );

    expect(result.parts.map((practice) => practice.name), [
      'TCP/IP Slice A',
      'TCP/IP Slice B 3',
      'TCP/IP Slice C',
    ]);
  });

  test('parts past Z use a numeric slice name', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 27,
    );

    final result = await harness.practices.splitPractice(
      seeded.practiceId,
      parts: 27,
      random: Random(1),
    );

    expect(result.parts, hasLength(27));
    expect(result.parts[0].name, 'TCP/IP Slice A');
    expect(result.parts[25].name, 'TCP/IP Slice Z');
    expect(result.parts[26].name, 'TCP/IP Slice 27');
    expect(
      result.parts.map((practice) => practice.name).toSet(),
      hasLength(27),
    );
  });
}
