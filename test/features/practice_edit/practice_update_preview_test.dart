import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/practice_edit/domain/practice_edit_service.dart';
import 'package:question_practice/features/practice_edit/domain/practice_update_models.dart';
import 'package:question_practice/features/practice_edit/practice_update_preview_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;
  late PracticeEditService service;

  setUp(() {
    harness = TestHarness();
    service = PracticeEditService(
      practices: harness.practices,
      importService: ImportService(
        repository: harness.practices,
        clock: harness.clock,
        bundle: rootBundle,
      ),
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  Future<PracticeUpdatePreview> buildPreview({
    required int practiceId,
    required String prompt,
  }) async {
    final payload = await service.buildPracticePayload(practiceId);
    final topics = payload['topics'] as List<dynamic>;
    final topic = topics.first as Map<String, dynamic>;
    final practices = topic['practices'] as List<dynamic>;
    final practice = practices.first as Map<String, dynamic>;
    final questions = practice['questions'] as List<dynamic>;
    (questions.first as Map<String, dynamic>)['prompt'] = prompt;
    return service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'edited.json',
      practiceId: practiceId,
    );
  }

  testWidgets('preview shows counts and Cancel leaves the practice unchanged', (
    tester,
  ) async {
    final seeded = await harness.seedPractice(count: 1);
    final preview = (await tester.runAsync(
      () => buildPreview(
        practiceId: seeded.practiceId,
        prompt: 'An edited prompt?',
      ),
    ))!;

    await pumpTestApp(
      tester,
      home: _PreviewLauncher(preview: preview),
      harness: harness,
    );
    await tester.tap(find.text('Open preview'));
    await pumpFrames(tester);

    expect(find.textContaining('0 new · 1 modified'), findsOneWidget);
    expect(find.text('An edited prompt?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);

    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    expect(questions.single.prompt, 'Question 1?');
    expect(find.text('Open preview'), findsOneWidget);
  });

  testWidgets('preview Apply writes the update and closes', (tester) async {
    final seeded = await harness.seedPractice(count: 1);
    final preview = (await tester.runAsync(
      () => buildPreview(
        practiceId: seeded.practiceId,
        prompt: 'An applied prompt?',
      ),
    ))!;

    await pumpTestApp(
      tester,
      home: _PreviewLauncher(preview: preview),
      harness: harness,
    );
    await tester.tap(find.text('Open preview'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply changes'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    expect(questions.single.prompt, 'An applied prompt?');
    expect(find.text('Open preview'), findsOneWidget);
  });
}

class _PreviewLauncher extends StatelessWidget {
  const _PreviewLauncher({required this.preview});

  final PracticeUpdatePreview preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: M3EButton.filled(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (context) => PracticeUpdatePreviewPage(preview: preview),
            ),
          ),
          label: const Text('Open preview'),
        ),
      ),
    );
  }
}
