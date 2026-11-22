/// Canonical helpers for the learner's "What went wrong?" bullets.
///
/// The persisted value is one atomic bullet per line in `reasoning`, so the
/// editor, the error review and the card creator can all read the same text
/// without a second table.
abstract final class WrongAnswerBullets {
  /// Most bullets one attempt may keep.
  static const int maxBullets = 30;

  /// Longest single bullet, in characters.
  static const int maxBulletLength = 500;

  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');
  static final RegExp _marker = RegExp(r'^\s*(?:[-*•]\s+|\d+[.)]\s+)');
  static final RegExp _whitespaceOnly = RegExp(r'^\s*$');

  /// Splits [raw] into clean bullets.
  ///
  /// Handles LF, CRLF and CR, strips a pasted Logseq or numbered-list marker,
  /// trims each line, drops empty lines and applies both hard caps.
  static List<String> parse(String raw) {
    if (raw.isEmpty) return const [];
    final bullets = <String>[];
    for (final line in raw.split(_lineBreak)) {
      final bullet = _normalizeLine(line);
      if (bullet.isEmpty) continue;
      bullets.add(bullet);
      if (bullets.length == maxBullets) break;
    }
    return bullets;
  }

  /// Canonical persisted value: trimmed non-empty bullets joined by newlines.
  static String format(Iterable<String> bullets) {
    return normalize(bullets).join('\n');
  }

  /// Cleans each bullet, preserving order and duplicates.
  static List<String> normalize(Iterable<String> bullets) {
    final clean = <String>[];
    for (final bullet in bullets) {
      final value = _normalizeLine(bullet);
      if (value.isEmpty) continue;
      clean.add(value);
      if (clean.length == maxBullets) break;
    }
    return clean;
  }

  /// Removes one leading bullet marker from [line], if present.
  static String stripMarker(String line) {
    final trimmed = line.trim();
    return trimmed.replaceFirst(_marker, '').trim();
  }

  static String _normalizeLine(String line) {
    if (_whitespaceOnly.hasMatch(line)) return '';
    final stripped = stripMarker(line);
    if (stripped.length <= maxBulletLength) return stripped;
    return stripped.substring(0, maxBulletLength);
  }
}
