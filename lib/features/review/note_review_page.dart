import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_sheet.dart';
import 'note_review_view.dart';

/// Reviews saved notes one at a time.
///
/// Opened from Cards with every visible note, or with a single note
/// when its row is tapped. Notes are read live from the database, so a
/// card made or a note deleted here is reflected without closing the
/// review. The card-making actions live inside the shared
/// [NoteReviewView] and disappear once a note has a card.
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
  late final Set<int> _ids;
  late int _index;
  int _kept = 0;
  int _cards = 0;
  bool _busy = false;
  bool _finished = false;

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
    super.dispose();
  }

  void _advanceFrom(int index, int length) {
    if (index + 1 >= length) {
      setState(() => _finished = true);
      return;
    }
    setState(() => _index = index + 1);
    _resetScroll();
  }

  void _goBack(int index) {
    if (index == 0) return;
    setState(() => _index = index - 1);
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _keep(Note note, int index, int length) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(reviewServiceProvider).keepNote(note.id);
      _kept++;
      if (!mounted) return;
      _advanceFrom(index, length);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCards(Note note, int index, int length) async {
    if (_busy) return;
    final created = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: note.sessionId,
        questionId: note.questionId,
        questionContext: note.context,
        topicName: note.topicName,
        subtopic: note.subtopic,
        initialTemplate: CardTemplate.definition,
        initialTerm: note.text,
        note: note,
      ),
    );
    if (!mounted || created == 0) return;
    _cards += created;
    _advanceFrom(index, length);
  }

  Future<void> _deleteNote(Note note, int length) async {
    if (_busy) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete note?',
      message:
          'The saved note "${note.text}" is removed from Cards. '
          'Cards already made from it stay.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(cardRepositoryProvider).deleteNote(note.id);
      if (!mounted) return;
      final remaining = math.max(0, length - 1);
      setState(() {
        _ids.remove(note.id);
        if (remaining == 0) {
          _finished = true;
        } else if (_index >= remaining) {
          _index = remaining - 1;
        }
      });
      _resetScroll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            if (index > 0) ...[
              M3EButton.text(
                onPressed: _busy ? null : () => _goBack(index),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: AppPrimaryButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (!note.isKept) {
                          _keep(note, index, notes.length);
                        } else {
                          _advanceFrom(index, notes.length);
                        }
                      },
                label: _busy
                    ? 'Saving…'
                    : !note.isKept
                    ? last
                          ? 'Keep & done'
                          : 'Keep & next'
                    : last
                    ? 'Done'
                    : 'Next',
                icon: !note.isKept ? Icons.check : Icons.arrow_forward,
              ),
            ),
            if (!note.isKept) ...[
              const SizedBox(width: 4),
              M3EButton.text(
                onPressed: _busy
                    ? null
                    : () => _advanceFrom(index, notes.length),
                child: const Text('Skip'),
              ),
            ],
          ],
        ),
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
        NoteReviewView(
          key: ValueKey('note-review-${note.id}'),
          note: note,
          onCreateCards: () => _createCards(note, index, notes.length),
          onKeep: note.isKept ? null : () => _keep(note, index, notes.length),
          onDelete: () => _deleteNote(note, notes.length),
        ),
      ],
    );
  }
}
