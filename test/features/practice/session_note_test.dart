import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/selectable_linkified_text.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('a saved note opens actions and can be deleted', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);
    final item = start.items.single;
    await harness.cards.createNote(
      sessionId: start.session.id,
      questionId: item.question.id,
      text: 'Question 1',
      context: item.question.prompt,
      topicName: item.topicName,
      practiceName: item.practiceName,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    final prompt = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableLinkifiedText &&
          widget.text == item.question.prompt,
    );
    final richText = tester.widget<RichText>(
      find.descendant(of: prompt, matching: find.byType(RichText)),
    );
    final span = _noteSpan(richText.text)!;
    (span.recognizer! as TapGestureRecognizer).onTap!();
    await pumpFrames(tester);

    expect(find.text('Define'), findsOneWidget);
    expect(find.text('Delete note'), findsOneWidget);

    await tester.tap(find.text('Delete note'));
    await pumpFrames(tester);

    expect(find.text('Note deleted.'), findsOneWidget);
    expect(await harness.cards.notesForQuestion(item.question.id), isEmpty);
  });
}

TextSpan? _noteSpan(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.style?.backgroundColor != null &&
      span.recognizer is TapGestureRecognizer) {
    return span;
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    final found = _noteSpan(child);
    if (found != null) return found;
  }
  return null;
}
