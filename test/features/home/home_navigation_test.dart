import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/home/home_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('home shows no back control after returning from a page', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', practiceName: 'Core');
    final homeKey = GlobalKey<_RebuildableHomeState>();

    await pumpTestApp(
      tester,
      home: _RebuildableHome(key: homeKey),
      harness: harness,
    );
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    Future<void> openAndReturn(Finder target) async {
      await tester.tap(target);
      await pumpFrames(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      // Providers update Home while another route covers it; that rebuild
      // used to capture canPop == true and leave a stale back arrow behind.
      homeKey.currentState!.rebuild();
      await pumpFrames(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await pumpFrames(tester);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
    }

    await openAndReturn(find.byIcon(Icons.settings_outlined));
    await openAndReturn(find.text('Cloud'));
    await openAndReturn(find.text('Cards'));
  });
}

/// Lets the test rebuild Home while another route covers it.
class _RebuildableHome extends StatefulWidget {
  const _RebuildableHome({super.key});

  @override
  State<_RebuildableHome> createState() => _RebuildableHomeState();
}

class _RebuildableHomeState extends State<_RebuildableHome> {
  int _generation = 0;

  void rebuild() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: ValueKey(_generation), child: const HomePage());
  }
}
