import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/review/domain/card_litmus.dart';

void main() {
  test('binary front is flagged', () {
    final report = checkCardLitmus(
      front: 'Is a managed service the right choice?',
      back: 'It removes host maintenance.',
      template: CardTemplate.contrast,
    );

    expect(report.issues, contains(LitmusIssue.binary));
    expect(report.isClean, isFalse);
  });

  test('front of exactly 30 words is clean; 31 words is longFront', () {
    final thirty = List.filled(30, 'alpha').join(' ');
    final thirtyOne = List.filled(31, 'alpha').join(' ');

    expect(
      checkCardLitmus(
        front: thirty,
        back: 'One answer.',
        template: CardTemplate.mechanism,
      ).issues,
      isEmpty,
    );
    expect(
      checkCardLitmus(
        front: thirtyOne,
        back: 'One answer.',
        template: CardTemplate.mechanism,
      ).issues,
      contains(LitmusIssue.longFront),
    );
  });

  test('card of exactly 50 words is clean; 51 words is longCard', () {
    final front = List.filled(25, 'alpha').join(' ');
    final back = List.filled(25, 'beta').join(' ');

    expect(
      checkCardLitmus(
        front: front,
        back: back,
        template: CardTemplate.mechanism,
      ).issues,
      isEmpty,
    );
    expect(
      checkCardLitmus(
        front: List.filled(26, 'alpha').join(' '),
        back: back,
        template: CardTemplate.mechanism,
      ).issues,
      contains(LitmusIssue.longCard),
    );
  });

  test('clue phrases are flagged', () {
    for (final front in [
      'Which protocol works because it retries?',
      'Which of the following describes a subnet?',
      'Hint: pick the network layer.',
    ]) {
      final report = checkCardLitmus(
        front: front,
        back: 'A short answer.',
        template: CardTemplate.contrast,
      );
      expect(report.issues, contains(LitmusIssue.syntacticClue), reason: front);
    }
  });

  test('the mandated heuristic template is clean', () {
    final report = checkCardLitmus(
      front:
          'If a scenario asks for isolation but restricts with cost, which '
          'option is always discarded?',
      back: 'Discard Z because rule.',
      template: CardTemplate.heuristic,
    );

    expect(report.issues, isEmpty);
    expect(report.isClean, isTrue);
    expect(report.label, 'Ready');
  });

  test('heuristic template mismatch is flagged', () {
    final report = checkCardLitmus(
      front: 'How should a managed service be patched?',
      back: 'Let the provider patch the host.',
      template: CardTemplate.heuristic,
    );

    expect(report.issues, contains(LitmusIssue.heuristicTemplate));
    expect(report.detail, contains('required prompt structure'));
  });

  test('procedure front must contain before and end with ?', () {
    expect(
      checkCardLitmus(
        front: 'In process X, what must be true before step Y?',
        back: 'Condition.',
        template: CardTemplate.procedure,
      ).issues,
      isEmpty,
    );
    expect(
      checkCardLitmus(
        front: 'In process X, what must be true next?',
        back: 'Condition.',
        template: CardTemplate.procedure,
      ).issues,
      contains(LitmusIssue.procedureTemplate),
    );
    expect(
      checkCardLitmus(
        front: 'In process X, what must be true before step Y',
        back: 'Condition.',
        template: CardTemplate.procedure,
      ).issues,
      contains(LitmusIssue.procedureTemplate),
    );
  });

  test('definition with an empty meaning is missingDefinition', () {
    final report = checkCardLitmus(
      front: 'VPC',
      back: '',
      template: CardTemplate.definition,
    );

    expect(report.issues, contains(LitmusIssue.missingDefinition));
    expect(report.issues, isNot(contains(LitmusIssue.missingBack)));
  });

  test('definition repeating the term is repeatsTerm', () {
    final report = checkCardLitmus(
      front: 'VPC',
      back: 'A VPC is a private network.',
      template: CardTemplate.definition,
    );

    expect(report.issues, contains(LitmusIssue.repeatsTerm));
  });

  test('definition that does not repeat the term is clean', () {
    final report = checkCardLitmus(
      front: 'VPC',
      back: 'A private network owned by the account.',
      template: CardTemplate.definition,
    );

    expect(report.issues, isEmpty);
  });

  test('empty front/back produce missingFront/missingBack', () {
    expect(
      checkCardLitmus(
        front: '',
        back: 'An answer.',
        template: CardTemplate.contrast,
      ).issues,
      contains(LitmusIssue.missingFront),
    );
    expect(
      checkCardLitmus(
        front: 'A question?',
        back: '',
        template: CardTemplate.contrast,
      ).issues,
      contains(LitmusIssue.missingBack),
    );
  });

  test('detail joins labels with " · "', () {
    final report = checkCardLitmus(
      front: 'Is a VPC public because it is private?',
      back: 'No.',
      template: CardTemplate.contrast,
    );

    expect(report.detail, contains(' · '));
    expect(report.detail.split(' · '), hasLength(greaterThanOrEqualTo(2)));
  });
}
