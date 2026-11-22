/// Formats a count with the matching singular or plural noun.
///
/// Use it for every user-visible count so copy such as `1 practices` never
/// reaches the screen. Pass [plural] only for nouns that do not simply take
/// an `s`, such as `person` and `people`.
String formatCount(int count, String singular, {String? plural}) {
  final noun = count == 1 ? singular : (plural ?? '${singular}s');
  return '$count $noun';
}
