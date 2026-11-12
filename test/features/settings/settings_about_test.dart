import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/app_build_info.dart';
import 'package:question_practice/features/settings/settings_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('About shows the version and the detected build type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const SettingsPage(), harness: harness);
    await tester.scrollUntilVisible(
      find.text('About'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);

    expect(find.text('$appName $appVersion'), findsOneWidget);
    expect(find.text('Debug build'), findsOneWidget);
    expect(
      find.text('Local-first practice with error cards and Anki export.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
