import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';

void main() {
  test('existing card texts include manual fronts and concept terms', () async {
    final createdAt = DateTime.utc(2026, 1, 1);
    final container = ProviderContainer(
      overrides: [
        allManualCardsProvider.overrideWith(
          (ref) => Stream.value([
            ManualCard(
              id: 1,
              sessionId: null,
              question: 'Which layer owns IP addresses?',
              answer: 'The network layer.',
              topicName: 'Topic',
              createdAt: createdAt,
              exportedAt: null,
            ),
          ]),
        ),
        allConceptsProvider.overrideWith(
          (ref) => Stream.value([
            Concept(
              id: 1,
              sessionId: null,
              questionId: null,
              term: 'VPC',
              definition: 'A private network.',
              extra: '',
              context: '',
              topicName: 'Topic',
              source: ConceptSource.manual,
              createdAt: createdAt,
              exportedAt: null,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final manualsReady = Completer<void>();
    final conceptsReady = Completer<void>();
    final manualsSub = container.listen(allManualCardsProvider, (_, next) {
      if (next.hasValue && !manualsReady.isCompleted) manualsReady.complete();
    });
    final conceptsSub = container.listen(allConceptsProvider, (_, next) {
      if (next.hasValue && !conceptsReady.isCompleted) conceptsReady.complete();
    });
    addTearDown(manualsSub.close);
    addTearDown(conceptsSub.close);
    await Future.wait([manualsReady.future, conceptsReady.future]);

    expect(
      container.read(existingCardTextsProvider),
      containsAll(<String>['Which layer owns IP addresses?', 'VPC']),
    );
  });
}
