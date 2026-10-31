import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/settings/settings_page.dart';

import '../../helpers/test_harness.dart';

Finder _apiKeyField() => find.byWidgetPredicate(
  (widget) =>
      widget is M3ETextField && (widget.label ?? '').contains('API key'),
);

void main() {
  Future<void> pumpSettings(
    WidgetTester tester,
    TestHarness harness, {
    required AppSettings settings,
  }) async {
    await harness.settings.save(settings);
    tester.view.physicalSize = const Size(420, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestApp(tester, home: const SettingsPage(), harness: harness);
  }

  testWidgets('AI settings keep one action and hide the base URL', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpSettings(
      tester,
      harness,
      settings: const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.openai,
        aiModel: 'gpt-test',
      ),
    );

    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Save key'), findsNothing);
    expect(find.text('Remove key'), findsNothing);
    expect(find.text('Save AI settings'), findsNothing);
    expect(find.text('Load models'), findsNothing);
    expect(find.text('Base URL'), findsNothing);
  });

  testWidgets('custom provider shows the base URL', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpSettings(
      tester,
      harness,
      settings: const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.custom,
        aiBaseUrl: 'https://example.com/v1',
      ),
    );

    expect(find.text('Base URL'), findsOneWidget);
  });

  testWidgets('the API key saves and clears without buttons', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpSettings(
      tester,
      harness,
      settings: const AppSettings(lookupMode: LookupMode.ai),
    );

    await tester.ensureVisible(_apiKeyField());
    await tester.enterText(_apiKeyField(), 'sk-test-key');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpFrames(tester);

    expect(await harness.settings.hasApiKey(), isTrue);
    expect(await harness.settings.readApiKey(), 'sk-test-key');

    await tester.enterText(_apiKeyField(), '');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpFrames(tester);

    expect(await harness.settings.hasApiKey(), isFalse);
  });
}
