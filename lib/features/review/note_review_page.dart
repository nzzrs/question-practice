import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_controller.dart';
import '../export/card_creator_sheet.dart';
import 'note_review_view.dart';
import 'review_shell.dart';

/// Reviews saved notes one at a time.
///
/// Opened from Cards with every visible note, or with a single note
/// when its row is tapped. Notes are read live from the database, so a card
/// made here is reflected without closing the review.
class NoteReviewPage extends ConsumerStatefulWidget {
  const NoteReviewPage({
    required this.notes,
    this.initialNoteId,
    this.title = 'Review notes',
    super.key,
  });

  final List<Note> notes;
  final int? initialNoteId;
  final String title;

  @override
  ConsumerState<NoteReviewPage> createState() => _NoteReviewPageState();
}

class _NoteReviewPageState extends ConsumerState<NoteReviewPage> {
  final _scroll = ScrollController();
  final _creator = CardCreatorController();
  late final Set<int> _ids;
  final _keptIds = <int>{};
  late int _index;
  int _kept = 0;
  int _cards = 0;
  bool _busy = false;
  bool _finished = false;
  final _completionPending = <String>{};

  @override
  void initState() {
    super.initState();
    _ids = {for (final note in widget.notes) note.id};
    final initialId = widget.initialNoteId;
    final found = initialId == null
        ? -1
        : widget.notes.indexWhere((note) => note.id == initialId);
    _index = found < 0 ? 0 : found;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _creator.dispose();
    super.dispose();
  }

  void _advanceFrom(int index, int length) {
    if (index + 1 >= length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index = index + 1;
      _creator.resetForStep();
    });
    _resetScroll();
  }

  void _goBack(int index) {
    if (index == 0) return;
    setState(() {
      _index = index - 1;
      _creator.resetForStep();
    });
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _itemKey(Note note) => 'note-review-${note.id}';

  CardCreatorRequest _requestFor(Note note) {
    return CardCreatorRequest(
      title: 'Create cards',
      sessionId: note.sessionId,
      questionId: note.questionId,
      questionContext: note.context,
      topicName: note.topicName,
      subtopic: note.subtopic,
      initialTemplate: CardTemplate.definition,
      initialTerm: note.text,
      existingFronts: ref.read(existingCardTextsProvider),
      note: note,
      itemKey: _itemKey(note),
    );
  }

  Future<void> _openCreator(Note note) async {
    if (_busy) return;
    await showReviewCardCreator(
      context,
      request: _requestFor(note),
      controller: _creator,
    );
  }

  Future<bool> _saveCachedDrafts(Note note) async {
    final snapshot = _creator.snapshotFor(_itemKey(note));
    if (snapshot == null) return true;
    if (snapshot.hasUnsavedComposerWork) {
      await showSnack(context, 'Add this card to the list before saving.');
      if (!mounted) return false;
      await _openCreator(note);
      return false;
    }
    final key = _itemKey(note);
    final retryCompletion =
        !snapshot.hasDrafts && _completionPending.contains(key);
    if (!snapshot.hasDrafts && !retryCompletion) return true;
    setState(() => _busy = true);
    try {
      final result = await saveCardCreatorDrafts(
        request: _requestFor(note),
        drafts: snapshot.drafts,
        service: ref.read(reviewServiceProvider),
        noteToConvertId: snapshot.noteToConvert?.id,
        retryCompletion: retryCompletion,
      );
      if (!mounted) return false;
      if (result.failure != null) {
        _creator.storeSnapshot(key, snapshot.withDrafts(result.remaining));
        if (result.completionPending) {
          _completionPending.add(key);
        } else {
          _completionPending.remove(key);
        }
        _cards += result.created;
        await showSnack(context, cardCreatorSaveFailureMessage(result));
        return false;
      }
      _completionPending.remove(key);
      _creator.clearSnapshot(key);
      _creator.clearSeed();
      _cards += result.created;
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNote(Note note, int index, int length) async {
    if (_busy) return;
    if (!await _saveCachedDrafts(note)) return;
    if (!mounted) return;
    if (!note.isKept && !_keptIds.contains(note.id)) {
      setState(() => _busy = true);
      try {
        await ref.read(reviewServiceProvider).keepNote(note.id);
        _keptIds.add(note.id);
        _kept++;
      } on Object catch (error) {
        if (mounted) await showSnack(context, 'Could not save: $error');
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    }
    if (index + 1 >= length && !await _confirmDiscardPending()) return;
    _advanceFrom(index, length);
  }

  /// Asks before finishing with work cached for another note.
  ///
  /// Saving the last note must not silently drop drafts the learner left on an
  /// earlier step. Declining keeps the review open with every draft intact.
  Future<bool> _confirmDiscardPending() async {
    if (!_creator.hasPendingWork) return true;
    final leave = await confirmDialog(
      context,
      title: 'Leave review?',
      message: 'Drafts and edits for this review are discarded.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (!leave || !mounted) return false;
    _creator.clearSnapshots();
    _completionPending.clear();
    return true;
  }

  Future<void> _requestNext(int index, int length) async {
    if (_busy) return;
    final last = index + 1 >= length;
    if (last && !await _confirmDiscardPending()) return;
    _advanceFrom(index, length);
  }

  Future<void> _requestClose() async {
    if (_busy) return;
    if (!await _confirmDiscardPending()) return;
    if (!mounted) return;
    _creator.clearSnapshots();
    _completionPending.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveReview(child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
    final theme = M3ETheme.of(context);
    final live = ref.watch(notesProvider).value ?? widget.notes;
    final notes = [
      for (final note in live)
        if (_ids.contains(note.id)) note,
    ];

    if (_finished || notes.isEmpty) {
      final changed = _kept > 0 || _cards > 0;
      return ReviewCompletionPage(
        title: 'Notes reviewed',
        heading: notes.isEmpty && !changed
            ? 'No notes to review'
            : 'Note review complete',
        message: changed
            ? [
                if (_kept > 0) '$_kept note${_kept == 1 ? '' : 's'} kept',
                if (_cards > 0) '$_cards card${_cards == 1 ? '' : 's'} created',
              ].join(' and ')
            : 'No notes were changed.',
        onDone: () => Navigator.of(context).pop(true),
        scrollController: _scroll,
      );
    }

    final index = _index >= notes.length ? notes.length - 1 : _index;
    final note = notes[index];
    final last = index == notes.length - 1;
    return ReviewShell(
      title: widget.title,
      saveLabel: last ? 'Save and finish' : 'Save',
      onSave: () => _saveNote(note, index, notes.length),
      onBack: () => _goBack(index),
      onNext: () => _requestNext(index, notes.length),
      onClose: _requestClose,
      canGoBack: index > 0,
      canGoNext: !last,
      onCreateCards: () => _openCreator(note),
      busy: _busy,
      scrollController: _scroll,
      children: [
        Text(
          'Item ${index + 1} of ${notes.length}',
          style: theme.typography.baseline.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearScore(value: (index + 1) / notes.length),
        const SizedBox(height: 22),
        Text(
          'Review the note',
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 16),
        NoteReviewView(key: ValueKey('note-review-${note.id}'), note: note),
      ],
    );
  }
}
