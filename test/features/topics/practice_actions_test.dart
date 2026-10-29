import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('long pressing a practice marks it done', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(tester.takeException(), isNull);

    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Mark as done'), findsOneWidget);

    await tester.tap(find.text('Mark as done'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
  });
}
