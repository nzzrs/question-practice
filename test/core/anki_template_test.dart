import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Anki export uses only built-in note types', () async {
    final source = await File(
      'android/app/src/main/kotlin/link/nzrs/questionpractice/AnkiBridge.kt',
    ).readAsString();

    // Concepts use AnkiDroid's Cloze note type and everything else Basic.
    expect(source, contains('findClozeModel()'));
    expect(source, contains('addNewBasicModel'));
    // The custom monolithic error model was removed.
    expect(source, isNot(contains('Question Practice: Error v2')));
    expect(source, isNot(contains('ensureErrorModel')));
    expect(source, isNot(contains('ERROR_FIELDS')));
    expect(source, isNot(contains('Flawed Assumption (Bias):')));
    expect(source, isNot(contains('Vaccine (Rule / Protocol):')));
  });
}
