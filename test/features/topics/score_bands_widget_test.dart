import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/app_metrics.dart';
import 'package:question_practice/core/ui/app_sections.dart';
import 'package:question_practice/core/ui/app_success.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/topics/topic_page.dart';
import 'package:question_practice/features/topics/topic_stats_page.dart';

import '../../helpers/test_harness.dart';

class _ScoredPractice {
  const _ScoredPractice({
    required this.practiceId,
    required this.total,
    required this.correct,
  });

  final int practiceId;
  final int total;
  final int correct;
}

Future<int> _seedTopic(TestHarness harness) {
  return harness.practices.createTopic(
    name: 'Scores',
    description: 'Score bands',
    priority: null,
    minimumScore: 70,
    targetScore: 80,
    createdAt: harness.clock.now().toUtc(),
  );
}

Future<_ScoredPractice> _addPractice(
  TestHarness harness,
  int topicId, {
  required String name,
  required int total,
  required int correct,
  String subtopic = '',
}) async {
  final practiceId = await harness.practices.createPractice(
    topicId: topicId,
    name: name,
    description: '',
    contentHash: 'hash-$name-$total',
    importedAt: harness.clock.now().toUtc(),
  );
  await harness.practices.createQuestions(practiceId, [
    for (var index = 0; index < total; index++)
      QuestionDraft(
        prompt: '$name question ${index + 1}?',
        alternatives: const ['Right', 'Wrong'],
        correctIndexes: const [0],
        explanation: 'Right is correct.',
        alternativeExplanations: const ['Correct.', 'Wrong.'],
        subtopic: subtopic,
      ),
  ]);
  return _ScoredPractice(
    practiceId: practiceId,
    total: total,
    correct: correct,
  );
}

Future<void> _complete(TestHarness harness, _ScoredPractice practice) async {
  final sessions = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  final start = await sessions.startPractice(practice.practiceId);
  for (var index = 0; index < start.items.length; index++) {
    await sessions.submitAnswer(
      start: start,
      item: start.items[index],
      selectedIndexes: [index < practice.correct ? 0 : 1],
      reasoning: '',
      distracted: false,
    );
  }
}

Pill _pill(WidgetTester tester, String text) {
  return tester.widget<Pill>(find.widgetWithText(Pill, text));
}

void main() {
  testWidgets('practice last scores use the topic score bands', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final topicId = await _seedTopic(harness);
    final below = await _addPractice(
      harness,
      topicId,
      name: 'Alpha',
      total: 2,
      correct: 1,
      subtopic: 'Alpha',
    );
    final track = await _addPractice(
      harness,
      topicId,
      name: 'Beta',
      total: 4,
      correct: 3,
      subtopic: 'Beta',
    );
    final met = await _addPractice(
      harness,
      topicId,
      name: 'Gamma',
      total: 4,
      correct: 4,
      subtopic: 'Gamma',
    );
    await _complete(harness, below);
    await _complete(harness, track);
    await _complete(harness, met);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: topicId),
      harness: harness,
    );

    expect(_pill(tester, '50%').tone, PillTone.error);
    expect(_pill(tester, '75%').tone, PillTone.neutral);
    expect(_pill(tester, '100%').tone, PillTone.success);

    // Readiness is 8/10, at the target.
    expect(_pill(tester, 'Target met').tone, PillTone.success);
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(TopicPage));
    expect(ring.color, AppSuccess.foreground(context));
    expect(tester.takeException(), isNull);
  });

  testWidgets('readiness names a score below the minimum', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final topicId = await _seedTopic(harness);
    final below = await _addPractice(
      harness,
      topicId,
      name: 'Alpha',
      total: 2,
      correct: 1,
    );
    await _complete(harness, below);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: topicId),
      harness: harness,
    );

    expect(_pill(tester, 'Below minimum').tone, PillTone.error);
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(TopicPage));
    expect(ring.color, M3ETheme.of(context).colorScheme.error);
  });

  testWidgets('readiness names an on-track score in the normal color', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final topicId = await _seedTopic(harness);
    final track = await _addPractice(
      harness,
      topicId,
      name: 'Beta',
      total: 4,
      correct: 3,
    );
    await _complete(harness, track);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: topicId),
      harness: harness,
    );

    expect(_pill(tester, 'On track').tone, PillTone.neutral);
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(TopicPage));
    expect(ring.color, M3ETheme.of(context).colorScheme.primary);
  });

  testWidgets('statistics pills and rings follow the topic bands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final topicId = await _seedTopic(harness);
    final below = await _addPractice(
      harness,
      topicId,
      name: 'Alpha',
      total: 2,
      correct: 1,
      subtopic: 'Alpha',
    );
    final track = await _addPractice(
      harness,
      topicId,
      name: 'Beta',
      total: 4,
      correct: 3,
      subtopic: 'Beta',
    );
    final met = await _addPractice(
      harness,
      topicId,
      name: 'Gamma',
      total: 4,
      correct: 4,
      subtopic: 'Gamma',
    );
    await _complete(harness, below);
    await _complete(harness, track);
    await _complete(harness, met);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: topicId),
      harness: harness,
    );

    expect(_pill(tester, '1/2 · 50%').tone, PillTone.error);
    expect(_pill(tester, '3/4 · 75%').tone, PillTone.neutral);
    expect(_pill(tester, '4/4 · 100%').tone, PillTone.success);

    expect(_pill(tester, '50% accuracy').tone, PillTone.error);
    expect(_pill(tester, '75% accuracy').tone, PillTone.neutral);
    expect(_pill(tester, '100% accuracy').tone, PillTone.success);

    expect(_pill(tester, 'Target met').tone, PillTone.success);
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(TopicStatsPage));
    expect(ring.color, AppSuccess.foreground(context));

    // The weighted average is 8/10, so the average tile is a met target.
    final averageTile = tester.widget<MetricTile>(
      find.ancestor(
        of: find.text('Average'),
        matching: find.byType(MetricTile),
      ),
    );
    expect(averageTile.tone, MetricTone.success);
    expect(find.textContaining('weighted by questions'), findsOneWidget);
    expect(find.text('The target score is already reached.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics shows a below-minimum average and on-track latest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final topicId = await _seedTopic(harness);
    final below = await _addPractice(
      harness,
      topicId,
      name: 'Alpha',
      total: 2,
      correct: 1,
    );
    final track = await _addPractice(
      harness,
      topicId,
      name: 'Beta',
      total: 4,
      correct: 3,
    );
    await _complete(harness, below);
    await _complete(harness, track);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: topicId),
      harness: harness,
    );

    expect(_pill(tester, 'On track').tone, PillTone.neutral);
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    final context = tester.element(find.byType(TopicStatsPage));
    expect(ring.color, M3ETheme.of(context).colorScheme.primary);

    final averageTile = tester.widget<MetricTile>(
      find.ancestor(
        of: find.text('Average'),
        matching: find.byType(MetricTile),
      ),
    );
    final bestTile = tester.widget<MetricTile>(
      find.ancestor(of: find.text('Best'), matching: find.byType(MetricTile)),
    );
    expect(averageTile.tone, MetricTone.error);
    expect(bestTile.tone, MetricTone.neutral);
    expect(averageTile.caption, contains('Below minimum'));
    expect(bestTile.caption, contains('On track'));

    expect(
      find.textContaining('you will average the target score'),
      findsOneWidget,
    );
  });
}
