import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_harness.dart';

import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/features/topics/anki_deck_picker.dart';
import 'package:question_practice/features/topics/topic_page.dart';

class _PickerHost extends ConsumerStatefulWidget {
  const _PickerHost();

  @override
  ConsumerState<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends ConsumerState<_PickerHost> {
  String _result = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3EButton.filled(
              onPressed: () async {
                final result = await showAnkiDeckPicker(context, ref);
                if (!mounted) return;
                setState(() => _result = result ?? 'cancelled');
              },
              child: const Text('open'),
            ),
            Text(_result),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('deck picker builds a tree and adds a child', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness(
      anki: FakeAnkiGateway(
        availableDecks: const [
          'Infrastructure',
          'Infrastructure::AWS',
          'Infrastructure::AWS::VPC',
          'Languages',
          'This is a very long deck name for a narrow phone::Child deck with a long name',
        ],
      ),
    );
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const _PickerHost(), harness: harness);
    await tester.tap(find.text('open'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Infrastructure'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('VPC'), findsOneWidget);
    expect(find.text('Languages'), findsOneWidget);
    final rootAdd = find.descendant(
      of: find
          .ancestor(of: find.text('Infrastructure'), matching: find.byType(Row))
          .first,
      matching: find.byIcon(Icons.add),
    );
    expect(rootAdd, findsOneWidget);

    expect(tester.takeException(), isNull);

    final addDeck = tester.widget<M3EButton>(
      find
          .ancestor(of: find.text('Add deck'), matching: find.byType(M3EButton))
          .first,
    );
    addDeck.onPressed!();
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(EditableText).last, 'Lambda');
    final addButton = tester.widget<M3EButton>(
      find
          .ancestor(of: find.text('Add'), matching: find.byType(M3EButton))
          .first,
    );
    addButton.onPressed!();
    await pumpFrames(tester);

    expect(find.text('Lambda'), findsOneWidget);
  });

  testWidgets('topic edit browse decks opens the shared picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness(
      anki: FakeAnkiGateway(
        availableDecks: const [
          'Infrastructure',
          'Infrastructure::AWS',
          'Infrastructure::AWS::VPC',
        ],
      ),
    );
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
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await pumpFrames(tester);
    expect(find.text('Edit topic'), findsOneWidget);

    await tester.tap(find.text('Browse decks'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Infrastructure'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('VPC'), findsOneWidget);

    await tester.tap(find.text('AWS'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.text('Infrastructure::AWS'), findsOneWidget);
  });
}
