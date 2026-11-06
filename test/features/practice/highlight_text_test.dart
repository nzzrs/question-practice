import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/selectable_linkified_text.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('a saved phrase is painted with a highlight background', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: SelectableLinkifiedText(
          text: 'This is a managed service for containers.',
          style: const TextStyle(fontSize: 16),
          highlights: const ['managed service'],
          onDefine: (_, _) {},
          onOpenUrl: (_) {},
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(SelectableLinkifiedText),
        matching: find.byType(RichText),
      ),
    );
    expect(_hasHighlight(richText.text), isTrue);
  });
}

bool _hasHighlight(InlineSpan span) {
  if (span is! TextSpan) return false;
  if (span.style?.backgroundColor != null) return true;
  return span.children?.any(_hasHighlight) ?? false;
}
