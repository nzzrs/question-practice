import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/app/theme.dart';
import 'package:question_practice/core/data/card_repository.dart';
import 'package:question_practice/core/data/practice_repository.dart';
import 'package:question_practice/core/data/session_repository.dart';
import 'package:question_practice/core/data/settings_repository.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/core/platform/secure_key_store.dart';
import 'package:question_practice/core/platform/web_launcher.dart';

class TestClock extends Clock {
  TestClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class TestHarness {
  TestHarness({
    DateTime? now,
    SecureKeyStore? keyStore,
    WebLauncher? webLauncher,
    AnkiGateway? anki,
  }) : clock = TestClock(now ?? DateTime.utc(2026, 1, 1, 12)),
       database = AppDatabase(NativeDatabase.memory()),
       keyStore = keyStore ?? InMemorySecureKeyStore(),
       webLauncher = webLauncher ?? RecordingWebLauncher(),
       anki = anki ?? FakeAnkiGateway() {
    practices = PracticeRepository(database, clock);
    sessions = SessionRepository(database);
    cards = CardRepository(database, clock);
    settings = SettingsRepository(database.settingsDao, this.keyStore);
  }

  final TestClock clock;
  final AppDatabase database;
  final SecureKeyStore keyStore;
  final WebLauncher webLauncher;
  final AnkiGateway anki;
  late final PracticeRepository practices;
  late final SessionRepository sessions;
  late final CardRepository cards;
  late final SettingsRepository settings;

  Future<void> close() => database.close();

  /// Seeds a topic, practice and [count] questions with two alternatives.
  Future<SeededPractice> seedPractice({
    String topicName = 'Topic',
    String practiceName = 'Practice',
    int count = 2,
    int? priority = 1,
    String? ankiDeck,
  }) async {
    final topicId = await practices.createTopic(
      name: topicName,
      description: 'Topic description',
      priority: priority,
      ankiDeck: ankiDeck,
      createdAt: clock.now().toUtc(),
    );
    final practiceId = await practices.createPractice(
      topicId: topicId,
      name: practiceName,
      description: 'Practice description',
      contentHash: 'hash-$practiceName-$count',
      importedAt: clock.now().toUtc(),
    );
    final questions = <QuestionDraft>[];
    for (var index = 0; index < count; index++) {
      questions.add(
        QuestionDraft(
          prompt: 'Question ${index + 1}?',
          alternatives: ['Correct ${index + 1}', 'Wrong ${index + 1}'],
          correctIndex: 0,
          explanation: 'Because ${index + 1} is correct.',
          alternativeExplanations: [
            'Correct: ${index + 1} is the right answer.',
            'Wrong: ${index + 1} is a distractor.',
          ],
        ),
      );
    }
    await practices.createQuestions(practiceId, questions);
    return SeededPractice(topicId: topicId, practiceId: practiceId);
  }

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        webLauncherProvider.overrideWithValue(webLauncher),
        ankiGatewayProvider.overrideWithValue(anki),
      ],
    );
  }
}

class SeededPractice {
  const SeededPractice({required this.topicId, required this.practiceId});

  final int topicId;
  final int practiceId;
}

class TestAppBundle {
  TestAppBundle({required this.widget, required this.container});

  final Widget widget;
  final ProviderContainer container;
}

TestAppBundle testAppBundle({required Widget home, TestHarness? harness}) {
  final suite = harness ?? TestHarness();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(suite.database),
      clockProvider.overrideWithValue(suite.clock),
      secureKeyStoreProvider.overrideWithValue(suite.keyStore),
      webLauncherProvider.overrideWithValue(suite.webLauncher),
      ankiGatewayProvider.overrideWithValue(suite.anki),
    ],
  );
  return TestAppBundle(
    container: container,
    widget: UncontrolledProviderScope(
      container: container,
      child: M3EMaterialApp(
        title: 'Question Practice test',
        data: appThemeData(),
        autoTheming: false,
        dynamicColoring: false,
        home: home,
      ),
    ),
  );
}

Future<void> pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var index = 0; index < frames; index++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpTestApp(
  WidgetTester tester, {
  required Widget home,
  TestHarness? harness,
}) async {
  final bundle = testAppBundle(home: home, harness: harness);
  await tester.pumpWidget(bundle.widget);
  await pumpFrames(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    bundle.container.dispose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
