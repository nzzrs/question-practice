import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/app_scaffold.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _pumpNarrow(
  WidgetTester tester, {
  required Widget home,
  required TestHarness harness,
  Size size = const Size(360, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpTestApp(tester, home: home, harness: harness, fontFamily: 'Roboto');
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('a long topic title wraps instead of truncating at 2x text', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    const name = 'Cloud Fundamentals and Networking';
    final seeded = await harness.seedPractice(
      topicName: name,
      practiceName: 'Core',
      count: 1,
    );

    await _pumpNarrow(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    final title = find.text(name);
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).maxLines, 2);
    expect(tester.getSize(title).height, greaterThan(50));
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
    );
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    expect(
      tester.widget<AppPage>(find.byType(AppPage)).variant,
      M3EAppBarVariant.small,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long topic title fits in landscape at 2x text', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    const name = 'Cloud Fundamentals and Networking';
    final seeded = await harness.seedPractice(
      topicName: name,
      practiceName: 'Core',
      count: 1,
    );

    await _pumpNarrow(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
      size: const Size(720, 360),
    );

    expect(find.text(name), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines,
      isFalse,
    );
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
