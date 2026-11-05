/// Returns true when [term] looks like an acronym or initialism.
///
/// Acronyms are uppercase-only selections with at least two letters. Common
/// separators such as `TCP/IP`, `CI/CD`, `HTTP/2` and `I/O` are accepted.
bool looksLikeAcronym(String term) {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return false;
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9/&+._-]*$').hasMatch(trimmed)) {
    return false;
  }
  if (RegExp(r'[a-z]').hasMatch(trimmed)) return false;
  return RegExp(r'[A-Z]').allMatches(trimmed).length >= 2;
}
