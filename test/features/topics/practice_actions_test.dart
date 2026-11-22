import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('long pressing a practice opens edit and renames it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.byType(OptionTile), findsNWidgets(4));
    expect(find.text('Edit practice'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Split into two'), findsNothing);
    expect(find.text('Rename'), findsNothing);

    await tester.tap(find.text('Edit practice'));
    await pumpFrames(tester);
    expect(find.byType(OptionTile), findsNWidgets(4));
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Edit description'), findsOneWidget);
    expect(find.text('Download practice JSON'), findsOneWidget);
    expect(find.text('Update practice JSON'), findsOneWidget);
    expect(find.text('AnkiDroid deck'), findsNothing);

    await tester.tap(find.text('Rename'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(EditableText).last, 'TCP/IP basics');
    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TCP/IP basics'), findsOneWidget);
    expect(find.text('TCP/IP'), findsNothing);
  });

  testWidgets('the edit menu changes a practice description', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit practice'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit description'));
    await pumpFrames(tester);
    await tester.enterText(
      find.byType(EditableText).last,
      'Ports, handshakes and retransmission.',
    );
    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ports, handshakes and retransmission.'), findsOneWidget);
    final practice = await harness.practices.practiceById(seeded.practiceId);
    expect(practice!.description, 'Ports, handshakes and retransmission.');
  });

  testWidgets('long pressing a practice marks it done', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Mark as done'), findsOneWidget);

    await tester.tap(find.text('Mark as done'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the split dialog creates the requested number of practices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 6,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Split'), findsOneWidget);

    await tester.tap(find.text('Split'));
    await pumpFrames(tester);
    expect(find.text('Split practice'), findsOneWidget);
    expect(find.text('Divide 6 questions into parts.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('split-parts-value'))).data,
      '2',
    );
    expect(find.text('Part 1 · 3'), findsOneWidget);
    expect(find.text('Part 2 · 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('split-parts-add')));
    await pumpFrames(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('split-parts-value'))).data,
      '3',
    );
    expect(find.text('Part 1 · 2'), findsOneWidget);
    expect(find.text('Part 2 · 2'), findsOneWidget);
    expect(find.text('Part 3 · 2'), findsOneWidget);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TCP/IP Slice A'), findsOneWidget);
    expect(find.text('TCP/IP Slice B'), findsOneWidget);
    expect(find.text('TCP/IP Slice C'), findsOneWidget);
    expect(
      find.text(
        'Split into 3 practices: TCP/IP Slice A, TCP/IP Slice B and TCP/IP Slice C.',
      ),
      findsOneWidget,
    );
    final practices = await harness.practices.allPractices();
    expect(practices, hasLength(3));
    for (final practice in practices) {
      final questions = await harness.practices.questionsForPractice(
        practice.id,
      );
      expect(questions, hasLength(2));
    }
  });

  testWidgets('canceling the split dialog leaves the practice untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 4,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);
    expect(find.text('Split practice'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsNothing);
    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(4),
    );
  });

  testWidgets('the split stepper stays within the valid range', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 4,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);

    M3EIconButton stepperButton(String key) =>
        tester.widget<M3EIconButton>(find.byKey(ValueKey(key)));

    expect(stepperButton('split-parts-remove').onPressed, isNull);
    expect(stepperButton('split-parts-add').onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('split-parts-add')));
    await tester.tap(find.byKey(const ValueKey('split-parts-add')));
    await pumpFrames(tester);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('split-parts-value'))).data,
      '4',
    );
    expect(stepperButton('split-parts-remove').onPressed, isNotNull);
    expect(stepperButton('split-parts-add').onPressed, isNull);
    expect(find.text('Part 1 · 1'), findsOneWidget);
    expect(find.text('Part 4 · 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('split-parts-add')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('split-parts-value'))).data,
      '4',
    );

    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the split dialog explains an impossible range', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpTestApp(
      tester,
      home: const _SplitDialogHost(questionCount: 1),
      harness: harness,
    );
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-range-error')), findsOneWidget);
    expect(find.text('A split needs at least two questions.'), findsOneWidget);
    expect(
      tester
          .widget<M3EButton>(find.byKey(const ValueKey('split-confirm')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a split is blocked while a session is in progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 4,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    await tester.ensureVisible(find.text('TCP/IP'));
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsNothing);
    expect(
      find.textContaining('session in progress before splitting'),
      findsOneWidget,
    );
    expect(
      (await harness.practices.allPractices()).single.id,
      seeded.practiceId,
    );
  });

  testWidgets('a split is blocked with fewer than two questions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 1,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsNothing);
    expect(find.text('A split needs at least two questions.'), findsOneWidget);
    expect(
      (await harness.practices.allPractices()).single.id,
      seeded.practiceId,
    );
  });

  testWidgets('a saved practice is marked in progress and asks to continue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(find.text('In progress'), findsOneWidget);

    await tester.ensureVisible(find.text('TCP/IP'));
    await tester.tap(find.text('TCP/IP'));
    await pumpFrames(tester);
    expect(find.text('Continue this practice?'), findsOneWidget);
    expect(find.text('Discard and start another'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sessions = await harness.sessions.latestInProgress();
    expect(sessions!.id, start.session.id);
  });

  testWidgets(
    'a failed discard keeps the session and does not start another practice',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(
        topicName: 'Networking',
        practiceName: 'TCP/IP',
        count: 2,
      );
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).first;
      final baselineId = await harness.cards.createErrorCard(
        questionId: question.id,
        sessionId: null,
        question: question.prompt,
        alternatives: question.alternatives,
        correctIndexes: question.correctIndexes,
        wrongIndexes: const [1],
        reasoning: 'Original reasoning',
        explanation: question.explanation,
        alternativeExplanations: question.alternativeExplanations,
        topicName: 'Networking',
        practiceName: 'TCP/IP',
        lastWrongAt: DateTime.utc(2025, 12, 1, 8),
        dueAfter: const Duration(hours: 48),
      );
      final service = SessionService(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );
      final start = await service.startPractice(seeded.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.first,
        selectedIndexes: const [1],
        reasoning: 'Changed before the conflict',
        distracted: false,
      );
      await harness.cards.resolveError(baselineId, harness.clock.now().toUtc());
      await harness.cards.createErrorCard(
        questionId: question.id,
        sessionId: null,
        question: question.prompt,
        alternatives: question.alternatives,
        correctIndexes: question.correctIndexes,
        wrongIndexes: const [1],
        reasoning: 'Conflicting active card',
        explanation: question.explanation,
        alternativeExplanations: question.alternativeExplanations,
        topicName: 'Networking',
        practiceName: 'TCP/IP',
        lastWrongAt: DateTime.utc(2025, 12, 1, 9),
        dueAfter: const Duration(hours: 48),
      );

      await pumpTestApp(
        tester,
        home: TopicPage(topicId: seeded.topicId),
        harness: harness,
      );
      await tester.ensureVisible(find.text('TCP/IP'));
      await tester.tap(find.text('TCP/IP'));
      await pumpFrames(tester);
      await tester.tap(find.text('Discard and start another'));
      await pumpFrames(tester);

      expect(
        find.textContaining('Could not discard this session'),
        findsOneWidget,
      );
      expect(find.text('Continue this practice?'), findsNothing);
      expect(find.text('Question 1 of 2'), findsNothing);
      expect((await harness.sessions.latestInProgress())!.id, start.session.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('practices can be sorted by name or recency', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'Zeta',
      count: 1,
    );
    for (final entry in {
      'Alpha': const Duration(hours: 1),
      'Beta': const Duration(hours: 2),
    }.entries) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: entry.key,
        description: '',
        contentHash: 'hash-${entry.key}',
        importedAt: harness.clock.now().toUtc().add(entry.value),
      );
    }

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Alpha'), lessThan(top('Beta')));
    expect(top('Beta'), lessThan(top('Zeta')));

    Future<void> apply({required String sort, required String order}) async {
      await tester.ensureVisible(find.byIcon(Icons.sort));
      await tester.tap(find.byIcon(Icons.sort));
      await pumpFrames(tester);
      await tester.tap(find.text(sort));
      await tester.tap(find.text(order));
      await tester.tap(find.text('Apply'));
      await pumpFrames(tester);
    }

    await apply(sort: 'Name', order: 'Decreasing');
    expect(top('Zeta'), lessThan(top('Alpha')));

    await apply(sort: 'Recency', order: 'Decreasing');
    expect(top('Beta'), lessThan(top('Alpha')));

    await apply(sort: 'Recency', order: 'Increasing');
    expect(top('Zeta'), lessThan(top('Alpha')));
  });

  testWidgets('practice names sort numbers by value', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'Practice 1',
      count: 1,
    );
    for (final name in const ['Practice 12', 'Practice 2']) {
      await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: name,
        description: '',
        contentHash: 'hash-$name',
        importedAt: harness.clock.now().toUtc(),
      );
    }

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Practice 1'), lessThan(top('Practice 2')));
    expect(top('Practice 2'), lessThan(top('Practice 12')));
  });

  testWidgets('the split dialog previews distribution and removal copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 5,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await pumpFrames(tester);
    await tester.longPress(find.text('TCP/IP'));
    await pumpFrames(tester);
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsOneWidget);
    expect(find.text('Divide 5 questions into parts.'), findsOneWidget);
    expect(find.text('Part 1 · 3'), findsOneWidget);
    expect(find.text('Part 2 · 2'), findsOneWidget);
    expect(
      find.text('Original session history will be removed.'),
      findsOneWidget,
    );
    expect(find.textContaining('This replaces'), findsNothing);
    expect(find.textContaining('Questions are shuffled'), findsNothing);
    expect(find.textContaining('even'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the split dialog fits 320 dp at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpTestApp(
      tester,
      home: const _SplitDialogHost(questionCount: 6),
      harness: harness,
    );
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsOneWidget);
    expect(find.text('Divide 6 questions into parts.'), findsOneWidget);
    expect(find.text('Part 1 · 3'), findsOneWidget);
    expect(find.text('Split').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('split-parts-add')));
    await pumpFrames(tester);
    expect(
      find.byKey(const ValueKey('split-parts-add')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the split dialog fits a landscape window', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpTestApp(
      tester,
      home: const _SplitDialogHost(questionCount: 6),
      harness: harness,
    );
    await pumpFrames(tester);

    expect(find.text('Split practice'), findsOneWidget);
    expect(find.text('Divide 6 questions into parts.'), findsOneWidget);
    expect(find.text('Part 1 · 3'), findsOneWidget);
    expect(find.text('Split').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('split-parts-add')));
    await pumpFrames(tester);
    expect(
      find.byKey(const ValueKey('split-parts-add')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _SplitDialogHost extends StatefulWidget {
  const _SplitDialogHost({required this.questionCount});

  final int questionCount;

  @override
  State<_SplitDialogHost> createState() => _SplitDialogHostState();
}

class _SplitDialogHostState extends State<_SplitDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSplitPracticeDialog(context, questionCount: widget.questionCount);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
