import 'dart:convert';

import '../domain/models.dart';

/// Prefix shared by every session undo journal in the settings table.
const errorCardUndoKeyPrefix = 'error_card_undo_';

/// Settings key that stores the undo journal for one practice session.
///
/// The journal lives in the existing key-value settings table so this feature
/// needs no schema migration. Each entry is removed when the session finishes
/// or is discarded.
String errorCardUndoKey(int sessionId) => '$errorCardUndoKeyPrefix$sessionId';

/// True for settings rows that hold a session undo journal.
bool isErrorCardUndoKey(String key) => key.startsWith(errorCardUndoKeyPrefix);

/// Session id encoded in an undo-journal key, or null when it is malformed.
int? errorCardUndoSessionId(String key) {
  if (!isErrorCardUndoKey(key)) return null;
  return int.tryParse(key.substring(errorCardUndoKeyPrefix.length));
}

/// The parts of an error card that a practice session may change.
///
/// A session records this state before its first change to an existing card.
/// Discarding the session writes the state back, so earlier mistakes and the
/// learner's review history survive unchanged. Fields owned by other flows,
/// such as the card's question text or completed details, are not touched.
class ErrorCardUndoSnapshot {
  const ErrorCardUndoSnapshot({
    required this.cardId,
    required this.wrongIndexes,
    required this.reasoning,
    required this.lastWrongAt,
    required this.dueAt,
    required this.distracted,
    required this.exportedAt,
    required this.status,
    required this.resolvedAt,
  });

  factory ErrorCardUndoSnapshot.fromCard(ErrorCard card) {
    return ErrorCardUndoSnapshot(
      cardId: card.id,
      wrongIndexes: List<int>.unmodifiable(card.wrongIndexes),
      reasoning: card.reasoning,
      lastWrongAt: card.lastWrongAt.toUtc(),
      dueAt: card.dueAt.toUtc(),
      distracted: card.distracted,
      exportedAt: card.exportedAt?.toUtc(),
      status: card.status,
      resolvedAt: card.resolvedAt?.toUtc(),
    );
  }

  final int cardId;
  final List<int> wrongIndexes;
  final String reasoning;
  final DateTime lastWrongAt;
  final DateTime dueAt;
  final bool distracted;
  final DateTime? exportedAt;
  final ErrorCardStatus status;
  final DateTime? resolvedAt;

  Map<String, Object?> toJson() {
    return {
      'card_id': cardId,
      'wrong_indexes': wrongIndexes,
      'reasoning': reasoning,
      'last_wrong_at': lastWrongAt.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'distracted': distracted,
      'exported_at': exportedAt?.toIso8601String(),
      'status': status.name,
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  /// Reads one entry, or null when a field is missing or malformed.
  static ErrorCardUndoSnapshot? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final cardId = raw['card_id'];
      final wrongIndexes = raw['wrong_indexes'];
      final reasoning = raw['reasoning'];
      final lastWrongAt = raw['last_wrong_at'];
      final dueAt = raw['due_at'];
      final distracted = raw['distracted'];
      final exportedAt = raw['exported_at'];
      final status = raw['status'];
      final resolvedAt = raw['resolved_at'];
      if (cardId is! int ||
          wrongIndexes is! List ||
          reasoning is! String ||
          lastWrongAt is! String ||
          dueAt is! String ||
          distracted is! bool ||
          status is! String) {
        return null;
      }
      final indexes = <int>[];
      for (final value in wrongIndexes) {
        if (value is! int || value < 0) return null;
        indexes.add(value);
      }
      if (exportedAt != null && exportedAt is! String) return null;
      if (resolvedAt != null && resolvedAt is! String) return null;
      final parsedExportedAt = exportedAt is String
          ? DateTime.parse(exportedAt).toUtc()
          : null;
      final parsedResolvedAt = resolvedAt is String
          ? DateTime.parse(resolvedAt).toUtc()
          : null;
      return ErrorCardUndoSnapshot(
        cardId: cardId,
        wrongIndexes: List<int>.unmodifiable(indexes),
        reasoning: reasoning,
        lastWrongAt: DateTime.parse(lastWrongAt).toUtc(),
        dueAt: DateTime.parse(dueAt).toUtc(),
        distracted: distracted,
        exportedAt: parsedExportedAt,
        status: ErrorCardStatus.values.byName(status),
        resolvedAt: parsedResolvedAt,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}

const _errorCardUndoVersion = 1;

String encodeErrorCardUndo(Iterable<ErrorCardUndoSnapshot> snapshots) {
  final sorted = snapshots.toList()
    ..sort((a, b) => a.cardId.compareTo(b.cardId));
  return jsonEncode({
    'version': _errorCardUndoVersion,
    'cards': [for (final snapshot in sorted) snapshot.toJson()],
  });
}

/// Reads a stored journal. A missing value is empty; a malformed one is null.
List<ErrorCardUndoSnapshot>? tryDecodeErrorCardUndo(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['version'] != _errorCardUndoVersion) return null;
    final cards = decoded['cards'];
    if (cards is! List) return null;
    final snapshots = <ErrorCardUndoSnapshot>[];
    for (final rawCard in cards) {
      final snapshot = ErrorCardUndoSnapshot.tryFromJson(rawCard);
      if (snapshot == null) return null;
      snapshots.add(snapshot);
    }
    return snapshots;
  } on FormatException {
    return null;
  }
}
