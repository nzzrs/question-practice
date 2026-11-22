import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';

void main() {
  test(
    'existing card texts include basic card fronts and concept terms',
    () async {
      final createdAt = DateTime.utc(2026, 1, 1);
      final container = ProviderContainer(
        overrides: [
          allBasicCardsProvider.overrideWith(
            (ref) => Stream.value([
              BasicCard(
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

      final basicsReady = Completer<void>();
      final conceptsReady = Completer<void>();
      final basicsSub = container.listen(allBasicCardsProvider, (_, next) {
        if (next.hasValue && !basicsReady.isCompleted) {
          basicsReady.complete();
        }
      });
      final conceptsSub = container.listen(allConceptsProvider, (_, next) {
        if (next.hasValue && !conceptsReady.isCompleted) {
          conceptsReady.complete();
        }
      });
      addTearDown(basicsSub.close);
      addTearDown(conceptsSub.close);
      await Future.wait([basicsReady.future, conceptsReady.future]);

      expect(
        container.read(existingCardTextsProvider),
        containsAll(<String>['Which layer owns IP addresses?', 'VPC']),
      );
    },
  );
}
