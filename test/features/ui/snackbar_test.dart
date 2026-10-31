import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('a success snackbar closes itself', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(
      tester,
      harness: harness,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () => showSnack(context, 'Saved.'),
              label: const Text('Show message'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show message'));
    await pumpFrames(tester);
    expect(find.text('Saved.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    expect(find.text('Saved.'), findsNothing);
  });
}
