import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/theme.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../../helpers/test_harness.dart';

const _narrowPortrait = Size(320, 640);
const _widePortrait = Size(360, 800);
const _landscape = Size(640, 360);

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required TestHarness harness,
  required Size size,
  double textScale = 2,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = harness.container();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: M3EMaterialApp(
        title: 'Question Practice',
        data: appThemeData(),
        fontFamily: 'Roboto',
        autoTheming: false,
        dynamicColoring: false,
        debugShowCheckedModeBanner: false,
        appBuilder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    ),
  );
  await pumpFrames(tester);
}

Future<void> _seedPendingError(
  TestHarness harness,
  SeededPractice seeded,
) async {
  final question = (await harness.practices.questionsForPractice(
    seeded.practiceId,
  )).first;
  await harness.cards.createErrorCard(
    questionId: question.id,
    sessionId: null,
    question: question.prompt,
    alternatives: question.alternatives,
    correctIndexes: question.correctIndexes,
    wrongIndexes: const [1],
    reasoning: 'Reasoning',
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Topic',
    practiceName: 'Practice',
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await pumpFrames(tester);
}

void _expectNoLayoutErrors(WidgetTester tester) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: error is FlutterError ? error.message : error?.toString(),
  );
}

void _expectTextScale(WidgetTester tester, Finder text, double expected) {
  final scaler = MediaQuery.textScalerOf(tester.element(text));
  expect(scaler.scale(16), closeTo(expected, 0.01));
}

void _expectReadable(WidgetTester tester, String label) {
  final text = find.text(label);
  expect(
    text,
    findsOneWidget,
    reason: '$label must stay on screen at large text',
  );
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '$label must not be clipped at large text',
  );
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('empty home fits 320x640 at 2x text', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await _pumpHome(tester, harness: harness, size: _narrowPortrait);

    expect(find.text('Review past errors'), findsOneWidget);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('No practices yet'));
    expect(find.text('No practices yet'), findsOneWidget);
    expect(find.text('Import a practice'), findsOneWidget);
    _expectTextScale(tester, find.text('No practices yet'), 32);
    _expectNoLayoutErrors(tester);
  });

  testWidgets('home fits 320x640 at 2x text with a pending badge', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Google Professional Cloud Architect',
      count: 5,
    );
    await _seedPendingError(harness, seeded);

    await _pumpHome(tester, harness: harness, size: _narrowPortrait);

    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('Review past errors'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    _expectTextScale(tester, find.text('Review past errors'), 32);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('1 pending'));
    expect(find.text('1 pending'), findsOneWidget);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('Google Professional Cloud Architect'));
    _expectReadable(tester, 'Google Professional Cloud Architect');
    expect(find.text('1 practice · 5 questions'), findsOneWidget);
    _expectNoLayoutErrors(tester);
  });

  testWidgets('home fits 360x800 at 2x text with a paused session', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Google Professional Cloud Architect',
      practiceName: 'A very long practice name for a narrow phone',
      count: 3,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(seeded.practiceId);

    await _pumpHome(tester, harness: harness, size: _widePortrait);

    expect(find.text('1 session paused'), findsOneWidget);
    expect(find.text('Session in progress'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    _expectTextScale(tester, find.text('Session in progress'), 32);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('Google Professional Cloud Architect'));
    _expectReadable(tester, 'Google Professional Cloud Architect');
    _expectNoLayoutErrors(tester);
  });

  testWidgets('home fits 360x800 at 1.3 text with a paused session', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Google Professional Cloud Architect',
      count: 3,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(seeded.practiceId);

    await _pumpHome(
      tester,
      harness: harness,
      size: _widePortrait,
      textScale: 1.3,
    );

    expect(find.text('Session in progress'), findsOneWidget);
    _expectNoLayoutErrors(tester);
  });

  testWidgets('home fits 640x360 landscape at 2x text', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Google Professional Cloud Architect',
      practiceName: 'A very long practice name for a narrow phone',
      count: 4,
    );
    await _seedPendingError(harness, seeded);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(seeded.practiceId);

    await _pumpHome(tester, harness: harness, size: _landscape);

    expect(find.text('1 session paused'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('Review past errors'));
    expect(find.text('Review past errors'), findsOneWidget);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('1 pending'));
    expect(find.text('1 pending'), findsOneWidget);
    _expectNoLayoutErrors(tester);

    await _scrollTo(tester, find.text('Google Professional Cloud Architect'));
    _expectReadable(tester, 'Google Professional Cloud Architect');
    _expectNoLayoutErrors(tester);
  });
}
