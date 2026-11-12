import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/export/new_card_dialog.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets(
    'new card fields can be edited and summarize explains a missing key',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      NewCardDraft? draft;

      await pumpTestApp(
        tester,
        harness: harness,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: M3EButton.filled(
                onPressed: () async {
                  draft = await showNewCardDialog(
                    context,
                    contextText: 'Which service spreads requests?',
                    initialQuestion: 'A very long imported question?',
                    initialAnswer: 'A long imported answer.',
                  );
                },
                label: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await pumpFrames(tester);
      expect(find.byKey(const ValueKey('new-card-question')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('new-card-question-summarize')),
      );
      await pumpFrames(tester, frames: 24);
      expect(
        find.text(
          'Summarizing needs an AI provider. Add an API key in Settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await pumpFrames(tester, frames: 24);
      await tester.enterText(
        find.byKey(const ValueKey('new-card-question')),
        'Shorter question?',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-card-answer')),
        'Short answer.',
      );
      await tester.tap(find.text('Create'));
      await pumpFrames(tester);

      expect(draft, isNotNull);
      expect(draft!.question, 'Shorter question?');
      expect(draft!.answer, 'Short answer.');
    },
  );
}
