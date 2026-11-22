/// Maximum number of ids bound in a single SQL `IN` clause.
///
/// Some Android versions ship SQLite with the historical limit of 999 bound
/// variables per statement, so batches stay below it.
const int maxIdsPerQuery = 900;

/// Unique [ids] split into batches small enough for one SQL `IN` clause.
Iterable<List<int>> idBatches(Iterable<int> ids) sync* {
  final values = ids.toSet().toList(growable: false);
  for (var start = 0; start < values.length; start += maxIdsPerQuery) {
    final end = start + maxIdsPerQuery;
    yield values.sublist(start, end < values.length ? end : values.length);
  }
}
