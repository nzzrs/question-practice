import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/acronyms.dart';

void main() {
  test('recognises common acronym selections', () {
    for (final term in ['SRE', 'GCP', 'TCP/IP', 'HTTP/2', 'CI/CD', 'I/O']) {
      expect(looksLikeAcronym(term), isTrue, reason: term);
    }
  });

  test('does not treat ordinary words or sentences as acronyms', () {
    for (final term in [
      'Cloud Run',
      'A',
      'Sre',
      'service',
      'site reliability',
    ]) {
      expect(looksLikeAcronym(term), isFalse, reason: term);
    }
  });
}
