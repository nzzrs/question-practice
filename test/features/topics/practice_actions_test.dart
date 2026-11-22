import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Split practice?'), findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('split-parts-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '2');
    expect(find.text('2 practices with 3 + 3 questions.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('split-parts-add')));
    await pumpFrames(tester);
    expect(find.text('3 practices with 2 + 2 + 2 questions.'), findsOneWidget);
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
    expect(find.text('Split practice?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);

    expect(find.text('Split practice?'), findsNothing);
    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(4),
    );
  });

  testWidgets('the split dialog rejects parts outside the valid range', (
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

    final field = find.byKey(const ValueKey('split-parts-field'));
    await tester.enterText(field, '1');
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);
    expect(find.text('Use at least 2 parts.'), findsOneWidget);
    expect(find.text('Split practice?'), findsOneWidget);

    await tester.enterText(field, '5');
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);
    expect(find.text('Use at most 4 parts, one per question.'), findsOneWidget);

    await tester.enterText(field, '');
    await tester.tap(find.text('Split'));
    await pumpFrames(tester);
    expect(find.text('Enter how many parts.'), findsOneWidget);

    final practices = await harness.practices.allPractices();
    expect(practices.single.id, seeded.practiceId);
    expect(
      await harness.practices.questionsForPractice(seeded.practiceId),
      hasLength(4),
    );
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

    expect(find.text('Split practice?'), findsNothing);
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

    expect(find.text('Split practice?'), findsNothing);
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

    expect(find.text('Split practice?'), findsOneWidget);
    expect(find.text('2 practices with 3 + 2 questions.'), findsOneWidget);
    expect(
      find.textContaining(
        'Questions are shuffled, so each part gets a random mix',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Sessions, answers and error cards for the original practice are removed',
      ),
      findsOneWidget,
    );
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
      home: const _SplitDialogHost(practiceName: 'TCP/IP', questionCount: 6),
      harness: harness,
    );
    await pumpFrames(tester);

    expect(find.text('Split practice?'), findsOneWidget);
    expect(find.text('2 practices with 3 + 3 questions.'), findsOneWidget);
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
      home: const _SplitDialogHost(practiceName: 'TCP/IP', questionCount: 6),
      harness: harness,
    );
    await pumpFrames(tester);

    expect(find.text('Split practice?'), findsOneWidget);
    expect(find.text('2 practices with 3 + 3 questions.'), findsOneWidget);
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
  const _SplitDialogHost({
    required this.practiceName,
    required this.questionCount,
  });

  final String practiceName;
  final int questionCount;

  @override
  State<_SplitDialogHost> createState() => _SplitDialogHostState();
}

class _SplitDialogHostState extends State<_SplitDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSplitPracticeDialog(
        context,
        practiceName: widget.practiceName,
        questionCount: widget.questionCount,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
