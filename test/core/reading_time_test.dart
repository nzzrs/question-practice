import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/reading_time.dart';

void main() {
  test('empty and very short text still reads as five seconds', () {
    expect(estimateReadingTime(''), const Duration(seconds: 5));
    expect(estimateReadingTime('   '), const Duration(seconds: 5));
    expect(estimateReadingTime('one'), const Duration(seconds: 5));
  });

  test('counts whitespace-separated words and rounds up to five seconds', () {
    // 10 words at 200 wpm is 3 seconds, rounded up to 5.
    expect(
      estimateReadingTime(List.filled(10, 'word').join(' ')),
      const Duration(seconds: 5),
    );
    // 17 words is 5.1 seconds, rounded up to 10.
    expect(
      estimateReadingTime(List.filled(17, 'word').join(' ')),
      const Duration(seconds: 10),
    );
    // Newlines and repeated spaces do not create extra words.
    expect(
      estimateReadingTime('one   two\nthree\tfour'),
      const Duration(seconds: 5),
    );
  });

  test('longer fronts scale with the 200 words per minute estimate', () {
    expect(
      estimateReadingTime(List.filled(200, 'word').join(' ')),
      const Duration(seconds: 60),
    );
    expect(
      estimateReadingTime(List.filled(201, 'word').join(' ')),
      const Duration(seconds: 65),
    );
  });

  test('formats the estimate for a discreet badge', () {
    expect(formatReadingTime(const Duration(seconds: 15)), '~15 s read');
    expect(readingTimeLabel(List.filled(20, 'word').join(' ')), '~10 s read');
  });
}
