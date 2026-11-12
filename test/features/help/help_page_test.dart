import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/help/help_json_example.dart';
import 'package:question_practice/features/help/help_page.dart';
import 'package:question_practice/features/import/domain/import_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('help covers current screens and drops stale copy', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const HelpPage(), harness: harness);

    final texts = <String>{};
    void collectVisibleText() {
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final data = widget.data;
        if (data != null) texts.add(data);
      }
    }

    collectVisibleText();
    for (var index = 0; index < 40; index++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump();
      collectVisibleText();
    }

    expect(
      texts,
      containsAll([
        'What you can do',
        'Home',
        'Import',
        'Practice',
        'Feedback and error cards',
        'Past errors',
        'Cards',
        'Highlights',
        'AnkiDroid export',
        'Practice JSON',
        'Subtopics and statistics',
        'Lookup and Ask',
        'Backup and data',
        'Shuffled practice',
        'JSON example',
        'Copy JSON example',
      ]),
    );
    expect(texts.any((text) => text.contains('shuffle button')), isFalse);
    expect(
      texts.any((text) => text.contains('A quiet loop for practice')),
      isFalse,
    );
    expect(texts.any((text) => text.contains('SQLite')), isFalse);
    expect(texts.any((text) => text.contains('chat completions')), isFalse);
    expect(texts.any((text) => text.contains('native API')), isFalse);
    expect(texts.any((text) => text.contains('database')), isFalse);
  });

  testWidgets('copy example puts valid JSON with every format feature on the '
      'clipboard', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments as Map<Object?, Object?>;
        copied = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpTestApp(tester, home: const HelpPage(), harness: harness);
    await tester.scrollUntilVisible(
      find.text('Copy JSON example'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Copy JSON example'));
    await pumpFrames(tester);

    expect(find.text('JSON example copied.'), findsOneWidget);
    final example = jsonDecode(copied!) as Map<String, dynamic>;
    expect(example['formatVersion'], 1);

    final topics = example['topics'] as List<dynamic>;
    expect(topics, hasLength(2));
    final cloud = topics.first as Map<String, dynamic>;
    expect(cloud['description'], isNotEmpty);

    final practices = cloud['practices'] as List<dynamic>;
    final compute = practices.first as Map<String, dynamic>;
    expect(compute['description'], isNotEmpty);

    final questions = compute['questions'] as List<dynamic>;
    expect(questions, hasLength(2));

    final single = questions.first as Map<String, dynamic>;
    expect(single['sourceId'], '101');
    expect(single['subtopic'], 'Serverless');
    expect(single['correctIndex'], 1);
    expect(single.containsKey('correctIndexes'), isFalse);

    final multi = questions.last as Map<String, dynamic>;
    expect(multi['sourceId'], '102');
    expect(multi['subtopic'], 'Serverless');
    expect(multi['correctIndexes'], [0, 2]);
    expect(multi.containsKey('correctIndex'), isFalse);

    for (final question in questions.cast<Map<String, dynamic>>()) {
      expect(
        (question['alternativeExplanations'] as List<dynamic>),
        hasLength((question['alternatives'] as List<dynamic>).length),
      );
    }
  });

  test('help example matches the bundled format example', () async {
    final asset = await rootBundle.loadString(
      'assets/samples/practice_format_example.json',
    );
    expect(jsonDecode(asset), jsonDecode(helpJsonExample));
  });

  test(
    'help example imports with subtopics and a multi-answer question',
    () async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final service = ImportService(
        repository: harness.practices,
        clock: harness.clock,
        bundle: rootBundle,
      );

      final preview = await service.previewText(
        helpJsonExample,
        fileName: 'help_example.json',
      );
      expect(preview.topicCount, 2);
      expect(preview.practiceCount, 2);
      expect(preview.questionCount, 3);
      expect(preview.notes, isEmpty);

      final result = await service.import(preview);
      expect(result.topicsCreated, 2);
      expect(result.practicesImported, 2);
      expect(result.questionsImported, 3);

      final topics = await harness.practices.allTopics();
      expect(
        topics.map((topic) => topic.name),
        containsAll(['Cloud', 'Networking']),
      );
      expect(topics.first.description, isNotEmpty);

      final practices = await harness.practices.allPractices();
      final compute = practices.singleWhere(
        (practice) => practice.name == 'Compute',
      );
      expect(compute.description, isNotEmpty);

      final questions = await harness.practices.questionsForPractice(
        compute.id,
      );
      expect(questions, hasLength(2));
      expect(questions.first.subtopic, 'Serverless');
      expect(questions.first.correctIndexes, [1]);
      expect(questions.last.correctIndexes, [0, 2]);
      expect(questions.last.allowsMultiple, isTrue);
      for (final question in questions) {
        expect(
          question.alternativeExplanations,
          hasLength(question.alternatives.length),
        );
      }
    },
  );
}
