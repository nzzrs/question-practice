import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Anki error note uses the revised problem template', () async {
    final source = await File(
      'android/app/src/main/kotlin/link/nzrs/questionpractice/AnkiBridge.kt',
    ).readAsString();

    expect(source, contains('class="field-container discarded"'));
    expect(source, contains('Right answer discarded:'));
    expect(source, contains('{{#Correct Solution}}'));
    expect(
      source,
      contains('What was the <strong>flawed assumption</strong>?'),
    );
    expect(source, contains('<hr id="answer">'));
    expect(source, contains('Flawed Assumption (Bias):'));
    expect(source, contains('Vaccine (Rule / Protocol):'));
    expect(source, contains('min-height: 100%;'));
    expect(source, contains('html {'));
    expect(source, isNot(contains('min-height: 100vh')));
  });
}
