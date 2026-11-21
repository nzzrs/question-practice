import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/app_scaffold.dart';

import '../helpers/test_harness.dart';

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: M3EButton.filled(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const _AppPageChild(label: 'Child'),
            ),
          ),
          child: const Text('Open child'),
        ),
      ),
    );
  }
}

class _AppPageChild extends StatelessWidget {
  const _AppPageChild({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: label,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Open next page',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => _AppPageChild(label: '$label page'),
            ),
          ),
        ),
      ],
      children: [Text('$label body')],
    );
  }
}

void main() {
  testWidgets('a root AppPage never implies a back control', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(
      tester,
      home: const AppPage(title: 'Root', children: [Text('root body')]),
      harness: harness,
    );

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pushed AppPage keeps its implied back after a nested pop', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const _Host(), harness: harness);

    await tester.tap(find.text('Open child'));
    await pumpFrames(tester);
    expect(find.text('Child body'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await pumpFrames(tester);
    expect(find.text('Child page body'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester);
    expect(find.text('Child body'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
