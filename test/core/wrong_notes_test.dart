import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/feedback/domain/wrong_notes.dart';

void main() {
  group('WrongNotes.parse', () {
    test('splits LF, CRLF and CR and trims blank lines', () {
      expect(WrongNotes.parse('one\r\ntwo\rthree\n\n  four  '), [
        'one',
        'two',
        'three',
        'four',
      ]);
    });

    test('strips pasted bullet and numbered markers', () {
      expect(
        WrongNotes.parse('- first\n* second\n• third\n1. fourth\n2) fifth'),
        ['first', 'second', 'third', 'fourth', 'fifth'],
      );
    });

    test('preserves order and duplicates', () {
      expect(WrongNotes.parse('same\nother\nsame'), ['same', 'other', 'same']);
    });

    test('keeps a legacy paragraph as one bullet', () {
      expect(WrongNotes.parse('A long legacy paragraph.'), [
        'A long legacy paragraph.',
      ]);
    });

    test('caps the number of bullets at 30', () {
      final raw = [for (var index = 0; index < 40; index++) 'note $index'];
      expect(WrongNotes.parse(raw.join('\n')), hasLength(30));
    });

    test('truncates one bullet at 500 characters', () {
      final parsed = WrongNotes.parse('x' * 520);
      expect(parsed.single, hasLength(500));
    });

    test('an empty value has no bullets', () {
      expect(WrongNotes.parse(''), isEmpty);
      expect(WrongNotes.parse(' \n\t\n'), isEmpty);
    });
  });

  group('WrongNotes.format', () {
    test('trims, drops empty values and joins with newlines', () {
      expect(
        WrongNotes.format([' one ', '', 'two', '   ', 'three']),
        'one\ntwo\nthree',
      );
    });

    test('round-trips the canonical value', () {
      const stored = 'first bullet\nsecond bullet';
      expect(WrongNotes.format(WrongNotes.parse(stored)), stored);
    });

    test('normalize keeps a bullet with an embedded marker intact', () {
      expect(WrongNotes.normalize(['-  leading space']), ['leading space']);
      expect(WrongNotes.normalize(['a - b']), ['a - b']);
    });

    test('marker stripping can be called directly', () {
      expect(WrongNotes.stripMarker('* item'), 'item');
      expect(WrongNotes.stripMarker('12. item'), 'item');
      expect(WrongNotes.stripMarker('no marker'), 'no marker');
    });
  });
}
