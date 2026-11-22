import 'package:flutter/foundation.dart';

import '../../core/domain/models.dart';

/// One draft card waiting to be saved by the host's single Save action.
sealed class CardCreatorDraft {
  const CardCreatorDraft();

  CardTemplate get template;

  String? get sourceBulletId;
}

class CardCreatorBasicDraft extends CardCreatorDraft {
  const CardCreatorBasicDraft({
    required this.front,
    required this.back,
    required this.template,
    this.sourceBulletId,
  });

  final String front;
  final String back;

  @override
  final CardTemplate template;

  @override
  final String? sourceBulletId;
}

class CardCreatorConceptDraft extends CardCreatorDraft {
  const CardCreatorConceptDraft({
    required this.term,
    required this.definition,
    required this.extra,
    required this.source,
    this.sourceBulletId,
  });

  final String term;
  final String definition;
  final String extra;
  final ConceptSource source;

  @override
  final String? sourceBulletId;

  @override
  CardTemplate get template => CardTemplate.definition;
}

/// One AI variant in a saved creator session.
class CardCreatorAiVariantData {
  const CardCreatorAiVariantData({
    required this.front,
    required this.back,
    required this.selected,
  });

  final String front;
  final String back;
  final bool selected;
}

/// One AI idea in a saved creator session.
class CardCreatorAiIdeaData {
  const CardCreatorAiIdeaData({required this.template, required this.variants});

  final CardTemplate template;
  final List<CardCreatorAiVariantData> variants;
}

/// A creator session captured when its sheet closes.
///
/// The review page keeps one snapshot per review item, so closing the sheet,
/// moving between steps and reopening the same item restore the typed text,
/// selected template, drafts, AI results and seed progress. Transient loading
/// flags are intentionally left out: a request that was in flight when the
/// sheet closed cannot update a surface that no longer exists.
class CardCreatorSnapshot {
  const CardCreatorSnapshot({
    required this.front,
    required this.back,
    required this.definitionCloze,
    required this.template,
    required this.appliedScaffoldFront,
    required this.appliedScaffoldBack,
    required this.appliedDefinitionCloze,
    required this.drafts,
    required this.ideas,
    required this.aiError,
    required this.aiPanelOpen,
    required this.aiUnavailable,
    required this.appliedSeedRevision,
    required this.seedBulletId,
    required this.seedNote,
    required this.noteToConvert,
    required this.seedInitialFront,
    required this.seedInitialBack,
    required this.seedInitialCloze,
    required this.seedSuggestion,
    required this.seedTouched,
    required this.seedHint,
    required this.seedError,
    required this.composerDirty,
    required this.canAddDraft,
    required this.composerHasText,
  });

  final String front;
  final String back;
  final String definitionCloze;
  final CardTemplate? template;
  final String appliedScaffoldFront;
  final String appliedScaffoldBack;
  final String appliedDefinitionCloze;
  final List<CardCreatorDraft> drafts;
  final List<CardCreatorAiIdeaData>? ideas;
  final String? aiError;
  final bool aiPanelOpen;
  final bool aiUnavailable;
  final int appliedSeedRevision;
  final String? seedBulletId;
  final Note? seedNote;
  final Note? noteToConvert;
  final String seedInitialFront;
  final String seedInitialBack;
  final String seedInitialCloze;
  final SuggestedCard? seedSuggestion;
  final bool seedTouched;
  final bool seedHint;
  final String? seedError;
  final bool composerDirty;
  final bool canAddDraft;
  final bool composerHasText;

  bool get hasDrafts => drafts.isNotEmpty;

  /// Whether reopening the creator would show work the dock Save could discard.
  ///
  /// Covers typed text, a seeded draft and an AI suggestion that was not yet
  /// accepted. Plain template defaults and request prefills stay out.
  bool get hasUnsavedComposerWork =>
      (composerHasText && (composerDirty || seedTouched)) ||
      seedSuggestion != null;

  /// Whether closing the review would lose work worth guarding.
  bool get hasPendingWork =>
      drafts.isNotEmpty ||
      (composerDirty && composerHasText) ||
      seedHint ||
      seedError != null ||
      seedSuggestion != null ||
      (ideas?.isNotEmpty ?? false);

  int get draftCount => drafts.length;

  CardCreatorSnapshot withDrafts(List<CardCreatorDraft> remaining) {
    return CardCreatorSnapshot(
      front: front,
      back: back,
      definitionCloze: definitionCloze,
      template: template,
      appliedScaffoldFront: appliedScaffoldFront,
      appliedScaffoldBack: appliedScaffoldBack,
      appliedDefinitionCloze: appliedDefinitionCloze,
      drafts: List<CardCreatorDraft>.unmodifiable(remaining),
      ideas: ideas,
      aiError: aiError,
      aiPanelOpen: aiPanelOpen,
      aiUnavailable: aiUnavailable,
      appliedSeedRevision: appliedSeedRevision,
      seedBulletId: seedBulletId,
      seedNote: seedNote,
      noteToConvert: noteToConvert,
      seedInitialFront: seedInitialFront,
      seedInitialBack: seedInitialBack,
      seedInitialCloze: seedInitialCloze,
      seedSuggestion: seedSuggestion,
      seedTouched: seedTouched,
      seedHint: seedHint,
      seedError: seedError,
      composerDirty: composerDirty,
      canAddDraft: canAddDraft,
      composerHasText: composerHasText,
    );
  }
}

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
///
/// Review pages also keep one [CardCreatorSnapshot] per item on this
/// controller. Closing the creator sheet writes a snapshot; reopening the same
/// item restores it. [resetForStep] clears only the live seed and bullet state,
/// never the stored snapshots, so moving between steps keeps every draft.
class CardCreatorController extends ChangeNotifier {
  CardCreatorSeed? _seed;
  int _seedRevision = 0;
  String? _activeBulletId;
  final Set<String> _addedBulletIds = <String>{};
  bool _seedDirty = false;
  bool _disposed = false;
  final Map<String, CardCreatorSnapshot> _snapshots = {};

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
    if (_disposed || _activeBulletId == null) return;
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

  /// Restores the chips for bullets already present in a cached draft list.
  void markDraftsAdded(Iterable<String?> bulletIds) {
    var changed = false;
    for (final bulletId in bulletIds) {
      if (bulletId == null) continue;
      changed = _addedBulletIds.add(bulletId) || changed;
    }
    if (changed) notifyListeners();
  }

  /// The creator snapshot stored for [itemKey], when the sheet was closed.
  CardCreatorSnapshot? snapshotFor(String itemKey) => _snapshots[itemKey];

  /// Replaces the creator snapshot for [itemKey].
  void storeSnapshot(String itemKey, CardCreatorSnapshot snapshot) {
    _snapshots[itemKey] = snapshot;
  }

  void clearSnapshot(String itemKey) {
    if (_snapshots.remove(itemKey) != null) notifyListeners();
  }

  /// Drops every stored creator session after a successful review exit.
  void clearSnapshots() {
    if (_snapshots.isEmpty) return;
    _snapshots.clear();
    notifyListeners();
  }

  bool get hasPendingWork =>
      _snapshots.values.any((snapshot) => snapshot.hasPendingWork);

  int get pendingDraftCount => _snapshots.values.fold(
    0,
    (total, snapshot) => total + snapshot.draftCount,
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
