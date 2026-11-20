import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/selectable_linkified_text.dart';

import '../../helpers/test_harness.dart';

final _richTextFinder = find.descendant(
  of: find.byType(SelectableLinkifiedText),
  matching: find.byType(RichText),
);

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

  testWidgets('tapping a saved phrase reports it through onHighlightTap', (
    tester,
  ) async {
    String? tapped;
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: SelectableLinkifiedText(
          text: 'This is a managed service for containers.',
          style: const TextStyle(fontSize: 16),
          highlights: const ['managed service'],
          onHighlightTap: (value) => tapped = value,
          onDefine: (_, _) {},
          onOpenUrl: (_) {},
        ),
      ),
    );

    final render = tester.renderObject<RenderParagraph>(_richTextFinder);
    final boxes = render.getBoxesForSelection(
      const TextSelection(baseOffset: 10, extentOffset: 25),
    );
    await tester.tapAt(render.localToGlobal(boxes.first.toRect().center));
    await tester.pump();
    expect(tapped, 'managed service');
  });

  testWidgets('a link inside a highlight keeps its URL action', (tester) async {
    String? opened;
    String? tapped;
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: SelectableLinkifiedText(
          text: 'See https://example.com for a managed service.',
          style: const TextStyle(fontSize: 16),
          highlights: const ['https://example.com'],
          onHighlightTap: (value) => tapped = value,
          onDefine: (_, _) {},
          onOpenUrl: (value) => opened = value,
        ),
      ),
    );

    final span = _highlightedSpan(_richText(tester).text)!;
    expect(span.recognizer, isA<TapGestureRecognizer>());
    (span.recognizer! as TapGestureRecognizer).onTap!();
    expect(opened, 'https://example.com');
    expect(tapped, isNull);
  });
}

RichText _richText(WidgetTester tester) => tester.widget<RichText>(
  find.descendant(
    of: find.byType(SelectableLinkifiedText),
    matching: find.byType(RichText),
  ),
);

TextSpan? _highlightedSpan(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.style?.backgroundColor != null && span.text != null) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final found = _highlightedSpan(child);
    if (found != null) return found;
  }
  return null;
}

bool _hasHighlight(InlineSpan span) {
  if (span is! TextSpan) return false;
  if (span.style?.backgroundColor != null) return true;
  return span.children?.any(_hasHighlight) ?? false;
}
