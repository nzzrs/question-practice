import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_controller.dart';
import '../feedback/feedback_actions.dart';
import '../feedback/feedback_snapshot.dart';
import '../feedback/question_feedback_view.dart';
import '../lookup/ask_sheet.dart';
import '../lookup/lookup_actions.dart';

export 'error_card_content.dart';

enum _NoteAction { define, ask, delete }

/// Shared error-card study view used by session review and the Cards screen.
///
/// The same feedback surface as practice renders the question, alternatives,
/// explanations, status and what-went-wrong bullets. The review is read-only:
/// bullets and notes are text, and cards are written in the embedded creator
/// beside this pane.
class ErrorCardReviewView extends ConsumerStatefulWidget {
  const ErrorCardReviewView({
    required this.card,
    required this.creator,
    required this.onSeedRequested,
    this.hasUnsavedComposerWork,
    this.leading,
    this.scrollController,
    super.key,
  });

  final ErrorCard card;

  /// Page-scoped bridge to the embedded creator.
  final CardCreatorController creator;

  /// Lets the page reveal the creator after a bullet or note seed.
  final VoidCallback onSeedRequested;

  /// Whether a closed creator still holds text or a seed draft for this card.
  ///
  /// The live controller forgets seeded edits when the review moves to another
  /// step, so the page answers from the stored snapshot instead.
  final bool Function()? hasUnsavedComposerWork;

  /// Review step header, scrolled with the feedback.
  final Widget? leading;

  final ScrollController? scrollController;

  @override
  ConsumerState<ErrorCardReviewView> createState() =>
      _ErrorCardReviewViewState();
}

class _ErrorCardReviewViewState extends ConsumerState<ErrorCardReviewView> {
  List<Note> _notes = const [];
  Object? _notesError;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant ErrorCardReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.questionId != widget.card.questionId) {
      _notes = const [];
      _notesError = null;
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ref
          .read(cardRepositoryProvider)
          .notesForQuestion(widget.card.questionId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _notesError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _notesError = error);
    }
  }

  Future<void> _saveNote(String selection, Rect? anchor) async {
    final card = widget.card;
    final text = selection.trim();
    if (text.isEmpty) return;
    final lowered = text.toLowerCase();
    if (_notes.any((note) => note.text.trim().toLowerCase() == lowered)) {
      await showSnack(context, 'That phrase is already saved as a note.');
      return;
    }
    try {
      await ref
          .read(cardRepositoryProvider)
          .createNote(
            sessionId: card.sessionId,
            questionId: card.questionId,
            text: text,
            context: card.question,
            topicName: card.topicName,
            practiceName: card.practiceName,
            subtopic: card.subtopic,
            createdAt: ref.read(clockProvider).now().toUtc(),
          );
      await _loadNotes();
      if (!mounted) return;
      await showSnack(context, 'Note saved. It is ready in Create cards.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not save the note: $error');
      }
    }
  }

  Future<void> _copyNote(Note note) async {
    await Clipboard.setData(ClipboardData(text: note.text));
    if (mounted) await showSnack(context, 'Note copied.');
  }

  bool get _hasUnsavedComposerWork =>
      widget.creator.seedDirty ||
      (widget.hasUnsavedComposerWork?.call() ?? false);

  Future<void> _createCardFromNote(Note note) async {
    if (_hasUnsavedComposerWork) {
      final replace = await confirmDialog(
        context,
        title: 'Replace the draft you started?',
        message:
            'The creator already has edits from the previous bullet or note. '
            'Replace them with this note?',
        confirmLabel: 'Replace',
        cancelLabel: 'Keep editing',
      );
      if (!replace || !mounted) return;
    }
    widget.creator.seedFromNote(note);
    widget.onSeedRequested();
  }

  Future<void> _turnBulletIntoCard(String bulletId, String bullet) async {
    if (_hasUnsavedComposerWork) {
      final replace = await confirmDialog(
        context,
        title: 'Replace the draft you started?',
        message:
            'The creator already has edits from the previous bullet or note. '
            'Replace them with this bullet?',
        confirmLabel: 'Replace',
        cancelLabel: 'Keep editing',
      );
      if (!replace || !mounted) return;
    }
    widget.creator.seedFromBullet(bulletId: bulletId, bullet: bullet);
    widget.onSeedRequested();
  }

  Future<void> _deleteNote(Note note) async {
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
    try {
      await ref.read(cardRepositoryProvider).deleteNote(note.id);
      if (!mounted) return;
      setState(() {
        _notes = [
          for (final item in _notes)
            if (item.id != note.id) item,
        ];
      });
      await showSnack(context, 'Note deleted.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete the note: $error');
      }
    }
  }

  Future<void> _openNoteActions(Note note) async {
    var aiAvailable = ref.read(hasApiKeyProvider).value;
    if (aiAvailable == null) {
      try {
        aiAvailable = await ref.read(hasApiKeyProvider.future);
      } on Object {
        aiAvailable = false;
      }
    }
    if (!mounted) return;
    final action = await M3EBottomSheet.show<_NoteAction>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) =>
          _NoteActionsSheet(phrase: note.text, showAsk: aiAvailable ?? false),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _NoteAction.define:
        _define(note.text, null);
      case _NoteAction.ask:
        await _ask(note.text, null);
      case _NoteAction.delete:
        await _deleteNote(note);
    }
  }

  void _define(String term, Rect? anchor) {
    openTermLookup(
      context,
      ref,
      term: term,
      question: widget.card.question,
      topicName: widget.card.topicName,
      practiceName: widget.card.practiceName,
      sessionId: widget.card.sessionId,
      questionId: widget.card.questionId,
      subtopic: widget.card.subtopic,
      anchor: anchor,
    );
  }

  void _openUrl(String value) => openStudyUrl(context, ref, value);

  Future<void> _ask(String selection, Rect? anchor) {
    final card = widget.card;
    return showAskAboutSelection(
      context,
      selection: selection,
      question: card.question,
      topicName: card.topicName,
      practiceName: card.practiceName,
      sessionId: card.sessionId,
      questionId: card.questionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final card = widget.card;
    return ListenableBuilder(
      listenable: widget.creator,
      builder: (context, _) {
        final activeBulletId = widget.creator.activeBulletId;
        return Semantics(
          container: true,
          label: 'Question feedback',
          child: QuestionFeedbackView(
            snapshot: FeedbackSnapshot.fromCard(card: card, notes: _notes),
            actions: FeedbackActions(
              onDefine: _define,
              onOpenUrl: _openUrl,
              onAsk: _ask,
              onSaveNote: _saveNote,
            ),
            leading: widget.leading,
            notes: _notes,
            onCopyNote: _copyNote,
            onCreateCardFromNote: _createCardFromNote,
            onNoteOverflow: _openNoteActions,
            onTurnBulletIntoCard: _turnBulletIntoCard,
            bulletBusy: activeBulletId != null,
            activeBulletId: activeBulletId,
            addedBulletIds: widget.creator.addedBulletIds,
            readOnly: true,
            scrollable: true,
            pageStorageKey: PageStorageKey<String>(
              'feedback-${card.questionId}',
            ),
            scrollController: widget.scrollController,
            hostFooter: _notesError == null
                ? null
                : TonalBox(
                    key: const ValueKey('feedback-notes-error'),
                    color: theme.colorScheme.errorContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load notes: $_notesError',
                          style: theme.typography.baseline.bodySmall.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        M3EButton.text(
                          key: const ValueKey('feedback-notes-retry'),
                          onPressed: _loadNotes,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _NoteActionsSheet extends StatelessWidget {
  const _NoteActionsSheet({required this.phrase, required this.showAsk});

  final String phrase;
  final bool showAsk;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phrase,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.emphasized.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved note',
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OptionTile(
              icon: Icons.menu_book_outlined,
              title: 'Define',
              subtitle: 'Look up this phrase',
              onTap: () => Navigator.of(context).pop(_NoteAction.define),
            ),
            if (showAsk)
              OptionTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Ask',
                subtitle: 'Ask the configured AI about this passage',
                onTap: () => Navigator.of(context).pop(_NoteAction.ask),
              ),
            OptionTile(
              icon: Icons.delete_outline,
              title: 'Delete',
              subtitle: 'Remove it everywhere for this question',
              destructive: true,
              onTap: () => Navigator.of(context).pop(_NoteAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}
