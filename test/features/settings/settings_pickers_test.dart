import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/features/settings/settings_page.dart';

import '../../helpers/test_harness.dart';

class _CountingAnkiGateway extends FakeAnkiGateway {
  int statusCalls = 0;

  @override
  Future<AnkiStatus> status() async {
    statusCalls++;
    return super.status();
  }
}

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

  testWidgets('AnkiDroid has no open action and refresh reloads the status', (
    tester,
  ) async {
    final gateway = _CountingAnkiGateway();
    final harness = TestHarness(anki: gateway);
    addTearDown(harness.close);
    await pumpSettings(tester, harness, settings: const AppSettings());

    expect(find.text('Open AnkiDroid'), findsNothing);

    final refresh = find.byKey(const ValueKey('anki-check-again'));
    await tester.scrollUntilVisible(
      refresh,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);

    final button = tester.widget<M3EIconButton>(refresh);
    expect(button.tooltip, 'Check again');
    expect(button.semanticLabel, 'Check again');
    expect(
      find.descendant(of: refresh, matching: find.byIcon(Icons.refresh)),
      findsOneWidget,
    );

    final callsBefore = gateway.statusCalls;
    await tester.tap(refresh);
    await pumpFrames(tester);

    expect(gateway.statusCalls, callsBefore + 1);
    expect(find.text('Open AnkiDroid'), findsNothing);
  });

  testWidgets('provider picker has one solid choice and persists another', (
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

    final field = find.byKey(const ValueKey('ai-provider-field'));
    await tester.ensureVisible(field);
    await pumpFrames(tester);
    expect(find.text('OpenAI'), findsOneWidget);

    await tester.tap(field);
    await pumpFrames(tester);

    final rows = <String, Finder>{
      for (final provider in AiProvider.values)
        provider.name: find.byKey(
          ValueKey('ai-provider-option-${provider.name}'),
        ),
    };
    for (final row in rows.values) {
      expect(row, findsOneWidget);
    }

    final scheme = M3ETheme.of(tester.element(rows['openai']!)).colorScheme;
    final materials = [
      for (final row in rows.values)
        tester.widget<Material>(
          find.descendant(of: row, matching: find.byType(Material)).first,
        ),
    ];
    expect(
      materials.where((material) => material.color == scheme.primaryContainer),
      hasLength(1),
    );
    expect(
      find.descendant(of: rows['openai']!, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(rows['groq']!);
    await pumpFrames(tester);

    expect(rows['groq'], findsNothing);
    expect(find.text('Groq'), findsOneWidget);
    expect((await harness.settings.load()).aiProvider, AiProvider.groq);
  });

  testWidgets('model search stays filtered after scrolling and selects', (
    tester,
  ) async {
    final models = [
      for (var index = 1; index <= 30; index++) 'gpt-$index',
      'llama-3',
      'claude-3',
    ];
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': [
            for (final model in models) {'id': model},
          ],
        }),
        200,
      );
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.saveApiKey('sk-test');
    await pumpSettings(
      tester,
      harness,
      settings: const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.openai,
        aiModel: 'gpt-5',
      ),
    );

    final field = find.byKey(const ValueKey('ai-model-field'));
    await tester.ensureVisible(field);
    await pumpFrames(tester);
    expect(find.text('gpt-5'), findsOneWidget);

    await tester.tap(field);
    await pumpFrames(tester);

    final search = find.byKey(const ValueKey('ai-model-search'));
    expect(search, findsOneWidget);
    await tester.enterText(search, 'gpt');
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('ai-model-option-llama-3')), findsNothing);
    expect(
      find.byKey(const ValueKey('ai-model-option-claude-3')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ai-model-option-gpt-1')), findsOneWidget);

    final target = find.byKey(const ValueKey('ai-model-option-gpt-20'));
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('ai-model-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await pumpFrames(tester);

    final searchField = tester.widget<M3ETextField>(search);
    expect(searchField.controller!.text, 'gpt');
    expect(find.byKey(const ValueKey('ai-model-option-llama-3')), findsNothing);

    await tester.tap(target);
    await pumpFrames(tester);

    expect(search, findsNothing);
    expect(find.text('gpt-20'), findsOneWidget);
    expect((await harness.settings.load()).aiModel, 'gpt-20');
  });
}
