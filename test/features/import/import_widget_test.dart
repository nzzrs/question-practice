import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/import/import_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('imports the bundled sample after a preview', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const ImportPage(), harness: harness);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('Load sample'), findsOneWidget);

    await tester.tap(find.text('Load sample'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to import'), findsOneWidget);
    expect(find.text('2 topics · 3 practices · 8 questions'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await pumpFrames(tester);
    await tester.tap(find.text('Import'));
    await pumpFrames(tester);
    expect(find.textContaining('Practice imported'), findsOneWidget);
  });
}
