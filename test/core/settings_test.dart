import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/list_sort.dart';
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

  test('defaults prefer web lookup and wallpaper colors', () async {
    final settings = await harness.settings.load();
    expect(settings.lookupMode, LookupMode.web);
    expect(settings.webEngine, WebEngine.duckDuckGo);
    expect(settings.dynamicColor, isTrue);
    expect(settings.soundsEnabled, isTrue);
    expect(settings.soundVolume, 0.85);
    expect(settings.ankiDeck, 'Question Practice');
  });

  test('settings round-trip without storing the API key in SQLite', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.groq,
        aiBaseUrl: 'https://api.groq.com/openai/v1',
        aiModel: 'model',
        dynamicColor: true,
        soundsEnabled: false,
        soundVolume: 0.45,
        ankiDeck: 'My deck',
      ),
    );
    await harness.settings.saveApiKey('super-secret');

    final loaded = await harness.settings.load();
    expect(loaded.lookupMode, LookupMode.ai);
    expect(loaded.aiProvider, AiProvider.groq);
    expect(loaded.aiModel, 'model');
    expect(loaded.dynamicColor, isTrue);
    expect(loaded.soundsEnabled, isFalse);
    expect(loaded.soundVolume, 0.45);
    expect(loaded.ankiDeck, 'My deck');
    expect(await harness.settings.hasApiKey(), isTrue);

    final raw = await harness.database.settingsDao.getAll();
    expect(raw.values.join(' '), isNot(contains('super-secret')));
  });

  test('home topic sort is saved and defaults to the current order', () async {
    expect(await harness.settings.loadHomeTopicSort(), isNull);
    expect(await harness.settings.watchHomeTopicSort().first, isNull);

    const sort = ListSort(
      field: ListSortField.recency,
      direction: ListSortDirection.decreasing,
    );
    await harness.settings.saveHomeTopicSort(sort);

    expect(await harness.settings.loadHomeTopicSort(), sort);
    expect(await harness.settings.watchHomeTopicSort().first, sort);
    expect(
      await harness.settings.loadHomeTopicSort(),
      isNot(ListSort.defaultByName),
    );
  });

  test('practice sorts are stored per topic', () async {
    final first = await harness.seedPractice(
      topicName: 'First',
      practiceName: 'One',
      count: 1,
    );
    final second = await harness.seedPractice(
      topicName: 'Second',
      practiceName: 'Two',
      count: 1,
    );

    const firstSort = ListSort(
      field: ListSortField.name,
      direction: ListSortDirection.decreasing,
    );
    const secondSort = ListSort(
      field: ListSortField.recency,
      direction: ListSortDirection.increasing,
    );
    await harness.settings.saveTopicPracticeSort(first.topicId, firstSort);
    await harness.settings.saveTopicPracticeSort(second.topicId, secondSort);

    expect(
      await harness.settings.loadTopicPracticeSort(first.topicId),
      firstSort,
    );
    expect(
      await harness.settings.loadTopicPracticeSort(second.topicId),
      secondSort,
    );
    expect(
      await harness.settings.watchTopicPracticeSort(first.topicId).first,
      firstSort,
    );

    final fresh = await harness.practices.createTopic(
      name: 'Fresh',
      description: '',
      priority: null,
      createdAt: harness.clock.now().toUtc(),
    );
    expect(
      await harness.settings.loadTopicPracticeSort(fresh),
      ListSort.defaultByName,
    );
  });

  test('erasing all data clears content, settings and the key', () async {
    await harness.seedPractice(count: 1);
    await harness.settings.saveApiKey('key');
    await harness.settings.save(const AppSettings(soundsEnabled: false));

    await harness.database.clearAll();
    await harness.settings.deleteApiKey();

    expect(await harness.practices.watchTopicSummaries().first, isEmpty);
    expect(await harness.settings.load(), isA<AppSettings>());
    expect((await harness.settings.load()).soundsEnabled, isTrue);
    expect(await harness.settings.hasApiKey(), isFalse);
  });
}
