import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_controller.dart';
import '../export/card_creator_sheet.dart';
import 'note_review_view.dart';
import 'review_action_dock.dart';

/// Reviews saved notes one at a time.
///
/// Opened from Cards with every visible note, or with a single note
/// when its row is tapped. Notes are read live from the database, so a
/// card made or a note deleted here is reflected without closing the
/// review.
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
    if (note.isKept) {
      _advanceFrom(index, length);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reviewServiceProvider).keepNote(note.id);
      _kept++;
      if (!mounted) return;
      _advanceFrom(index, length);
    } on Object catch (error) {
      if (mounted) await showSnack(context, 'Could not save: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteNote(Note note, int length) async {
    if (_busy) return;
    final hasDrafts = _creator.snapshotFor(_itemKey(note))?.hasDrafts ?? false;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete note?',
      message:
          'The saved note "${note.text}" is removed from Cards. '
          'Cards already made from it stay.'
          '${hasDrafts ? ' Unsaved card drafts for this note are discarded.' : ''}',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(cardRepositoryProvider).deleteNote(note.id);
      if (!mounted) return;
      _creator.forgetNote(note.id);
      _creator.clearSnapshot(_itemKey(note));
      _completionPending.remove(_itemKey(note));
      final remaining = math.max(0, length - 1);
      setState(() {
        _ids.remove(note.id);
        if (remaining == 0) {
          _finished = true;
        } else {
          if (_index >= remaining) {
            _index = remaining - 1;
          }
          _creator.resetForStep();
        }
      });
      _resetScroll();
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete the note: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestNext(int index, int length) async {
    if (_busy) return;
    final last = index + 1 >= length;
    if (last && _creator.hasPendingWork) {
      final leave = await confirmDialog(
        context,
        title: 'Leave review?',
        message: 'Drafts and edits for this review are discarded.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
      _creator.clearSnapshots();
      _completionPending.clear();
    }
    _advanceFrom(index, length);
  }

  Future<void> _requestClose() async {
    if (_busy) return;
    if (_creator.hasPendingWork) {
      final leave = await confirmDialog(
        context,
        title: 'Leave review?',
        message: 'Drafts and edits for this review are discarded.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
    }
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
      return AppPage(
        title: 'Notes reviewed',
        focus: true,
        onBack: () => Navigator.of(context).pop(true),
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: [
          const SizedBox(height: 32),
          Center(child: IconBadge(Icons.check_circle_outline, size: 72)),
          const SizedBox(height: 16),
          Text(
            notes.isEmpty && !changed
                ? 'No notes to review'
                : 'Note review complete',
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            changed
                ? [
                    if (_kept > 0) '$_kept note${_kept == 1 ? '' : 's'} kept',
                    if (_cards > 0)
                      '$_cards card${_cards == 1 ? '' : 's'} created',
                  ].join(' and ')
                : 'No notes were changed.',
            textAlign: TextAlign.center,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Done',
            icon: Icons.check,
          ),
        ],
      );
    }

    final index = _index >= notes.length ? notes.length - 1 : _index;
    final note = notes[index];
    final last = index == notes.length - 1;
    return AppPage(
      title: widget.title,
      showBack: true,
      focus: true,
      onBack: _requestClose,
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: ReviewActionDock(
        busy: _busy,
        saveLabel: last ? 'Save and finish' : 'Save',
        onSave: () => _saveNote(note, index, notes.length),
        onBack: () => _goBack(index),
        onNext: () => _requestNext(index, notes.length),
        canGoBack: index > 0,
        canGoNext: true,
        onCreateCards: () => _openCreator(note),
        onDelete: () => _deleteNote(note, notes.length),
      ),
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
