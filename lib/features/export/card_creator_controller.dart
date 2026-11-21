import 'package:flutter/foundation.dart';

import '../../core/domain/models.dart';

/// Content pushed from the feedback pane into the embedded card creator.
sealed class CardCreatorSeed {
  const CardCreatorSeed();
}

/// A read-only wrong-answer bullet the learner asked to turn into a card.
class BulletCardSeed extends CardCreatorSeed {
  const BulletCardSeed({required this.bulletId, required this.bullet});

  final String bulletId;
  final String bullet;
}

/// A saved note the learner asked to turn into a card.
class NoteCardSeed extends CardCreatorSeed {
  const NoteCardSeed(this.note);

  final Note note;
}

/// Page-scoped bridge between the feedback pane and the embedded creator.
///
/// The feedback pane calls [seedFromBullet] or [seedFromNote]. The creator
/// applies a seed only when [seedRevision] changes, so ordinary rebuilds never
/// overwrite text the learner is typing. The same controller carries the
/// short-lived chip state back to the feedback pane.
class CardCreatorController extends ChangeNotifier {
  CardCreatorSeed? _seed;
  int _seedRevision = 0;
  String? _activeBulletId;
  final Set<String> _addedBulletIds = <String>{};
  bool _seedDirty = false;

  /// The latest requested seed, or null when there is nothing to apply.
  CardCreatorSeed? get seed => _seed;

  /// Increases on every new seed request.
  int get seedRevision => _seedRevision;

  /// The bullet that is currently being drafted, if any.
  String? get activeBulletId => _activeBulletId;

  /// Bullets whose drafts are already in the creator list.
  Set<String> get addedBulletIds => Set.unmodifiable(_addedBulletIds);

  /// True when the learner changed the composer after the last seed.
  ///
  /// The feedback pane uses it before replacing a draft the learner started.
  bool get seedDirty => _seedDirty;

  void seedFromBullet({required String bulletId, required String bullet}) {
    _seed = BulletCardSeed(bulletId: bulletId, bullet: bullet);
    _seedRevision++;
    _activeBulletId = bulletId;
    _seedDirty = false;
    notifyListeners();
  }

  void seedFromNote(Note note) {
    _seed = NoteCardSeed(note);
    _seedRevision++;
    _activeBulletId = null;
    _seedDirty = false;
    notifyListeners();
  }

  void clearSeed() {
    if (_seed == null && _activeBulletId == null) return;
    _seed = null;
    _seedRevision++;
    _activeBulletId = null;
    _seedDirty = false;
    notifyListeners();
  }

  /// Marks the AI request or manual seed as finished.
  ///
  /// Edits made while the request was in flight stay dirty, so the next seed
  /// still asks before replacing them.
  void markSeedSettled() {
    if (_activeBulletId == null) return;
    _activeBulletId = null;
    notifyListeners();
  }

  /// Records that the learner edited the seeded composer.
  void markSeedDirty() {
    if (_seedDirty) return;
    _seedDirty = true;
  }

  /// Clears every short-lived state before showing another review step.
  ///
  /// Bullet ids are stable per card, so the added-chip state must not survive
  /// a step change or the next card would mark the same bullets as added.
  void resetForStep() {
    final changed =
        _seed != null ||
        _activeBulletId != null ||
        _seedDirty ||
        _addedBulletIds.isNotEmpty;
    _seed = null;
    _seedRevision++;
    _activeBulletId = null;
    _seedDirty = false;
    _addedBulletIds.clear();
    if (changed) notifyListeners();
  }

  void markDraftAdded(String bulletId) {
    if (_addedBulletIds.add(bulletId)) notifyListeners();
  }

  void markDraftRemoved(String bulletId) {
    if (_addedBulletIds.remove(bulletId)) notifyListeners();
  }
}
