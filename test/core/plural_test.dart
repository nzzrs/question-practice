import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/plural.dart';

void main() {
  test('formats singular and plural nouns', () {
    expect(formatCount(1, 'practice'), '1 practice');
    expect(formatCount(2, 'practice'), '2 practices');
    expect(formatCount(1, 'question'), '1 question');
    expect(formatCount(2, 'question'), '2 questions');
    expect(formatCount(0, 'card'), '0 cards');
  });

  test('accepts an explicit plural for irregular nouns', () {
    expect(formatCount(1, 'person', plural: 'people'), '1 person');
    expect(formatCount(3, 'person', plural: 'people'), '3 people');
  });
}
