import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/review/domain/card_litmus.dart';

void main() {
  test('a yes or no front is marked binary', () {
    final report = checkCardLitmus(
      front: 'Is a managed service the right choice?',
      back: 'It removes host maintenance.',
      cognitiveType: CognitiveType.contrast,
    );

    expect(report.issues, contains(LitmusIssue.binary));
    expect(report.isClean, isFalse);
  });

  test('a front longer than 30 words is marked long', () {
    final front = '${List.filled(31, 'alpha').join(' ')}?';
    final report = checkCardLitmus(
      front: front,
      back: 'One answer.',
      cognitiveType: CognitiveType.fact,
    );

    expect(report.issues, contains(LitmusIssue.longFront));
  });

  test('a syntactic clue in the front is flagged', () {
    final report = checkCardLitmus(
      front: 'Which of the following describes a managed service?',
      back: 'A provider runs the host.',
      cognitiveType: CognitiveType.contrast,
    );

    expect(report.issues, contains(LitmusIssue.syntacticClue));
  });

  test('a heuristic using the rule template is clean', () {
    final report = checkCardLitmus(
      front: 'Given requirement X with restriction Y, what rule applies?',
      back: 'Apply the matching rule.',
      cognitiveType: CognitiveType.heuristic,
    );

    expect(report.issues, isEmpty);
    expect(report.isClean, isTrue);
    expect(report.label, 'Ready');
  });

  test('a heuristic without the rule template is flagged', () {
    final report = checkCardLitmus(
      front: 'How should a managed service be patched?',
      back: 'Let the provider patch the host.',
      cognitiveType: CognitiveType.heuristic,
    );

    expect(report.issues, contains(LitmusIssue.missingTemplate));
    expect(report.detail, contains('rule template'));
  });
}
