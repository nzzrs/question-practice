import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() {
    harness = TestHarness();
  });

  tearDown(() async {
    await harness.close();
  });

  test('defaults prefer web lookup and no dynamic color', () async {
    final settings = await harness.settings.load();
    expect(settings.lookupMode, LookupMode.web);
    expect(settings.webEngine, WebEngine.duckDuckGo);
    expect(settings.shuffleTopics, isFalse);
    expect(settings.dynamicColor, isFalse);
    expect(settings.ankiDeck, 'Question Practice');
  });

  test('settings round-trip without storing the API key in SQLite', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.groq,
        aiBaseUrl: 'https://api.groq.com/openai/v1',
        aiModel: 'model',
        shuffleTopics: true,
        dynamicColor: true,
        ankiDeck: 'My deck',
      ),
    );
    await harness.settings.saveApiKey('super-secret');

    final loaded = await harness.settings.load();
    expect(loaded.lookupMode, LookupMode.ai);
    expect(loaded.aiProvider, AiProvider.groq);
    expect(loaded.aiModel, 'model');
    expect(loaded.shuffleTopics, isTrue);
    expect(loaded.dynamicColor, isTrue);
    expect(loaded.ankiDeck, 'My deck');
    expect(await harness.settings.hasApiKey(), isTrue);

    final raw = await harness.database.settingsDao.getAll();
    expect(raw.values.join(' '), isNot(contains('super-secret')));
  });

  test('erasing all data clears content, settings and the key', () async {
    await harness.seedPractice(count: 1);
    await harness.settings.saveApiKey('key');
    await harness.settings.save(const AppSettings(shuffleTopics: true));

    await harness.database.clearAll();
    await harness.settings.deleteApiKey();

    expect(await harness.practices.watchTopicSummaries().first, isEmpty);
    expect(await harness.settings.load(), isA<AppSettings>());
    expect((await harness.settings.load()).shuffleTopics, isFalse);
    expect(await harness.settings.hasApiKey(), isFalse);
  });
}
