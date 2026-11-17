/// Reading-time estimation for card fronts.
///
/// The estimate is deliberately rough: it counts whitespace-separated words,
/// assumes an average reading speed of 200 words per minute and reports the
/// time in five-second steps so the badge stays discreet.
const int _wordsPerMinute = 200;
const int _stepSeconds = 5;

/// Estimates how long [text] takes to read.
///
/// The result is rounded up to the next [_stepSeconds] seconds with a
/// [_stepSeconds]-second minimum, so even an empty front reads as five
/// seconds rather than a misleading zero.
Duration estimateReadingTime(String text) {
  final trimmed = text.trim();
  final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  final seconds = (words * 60 / _wordsPerMinute).ceil();
  final rounded = ((seconds + _stepSeconds - 1) ~/ _stepSeconds) * _stepSeconds;
  return Duration(seconds: rounded < _stepSeconds ? _stepSeconds : rounded);
}

/// Formats a reading-time estimate such as `~15 s read`.
String formatReadingTime(Duration duration) => '~${duration.inSeconds} s read';

/// Estimates and formats the reading time for [text] in one step.
String readingTimeLabel(String text) =>
    formatReadingTime(estimateReadingTime(text));
