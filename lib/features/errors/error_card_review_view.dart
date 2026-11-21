import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../feedback/feedback_actions.dart';
import '../feedback/feedback_snapshot.dart';
import '../feedback/question_feedback_view.dart';
import '../export/card_creator_sheet.dart';
import '../lookup/ask_sheet.dart';
import '../lookup/lookup_actions.dart';

export 'error_card_content.dart';

enum _NoteAction { define, ask, delete }

/// Shared error-card study view used by session review and the Cards screen.
///
/// The same feedback surface as practice renders the question, alternatives,
/// explanations, status and what-went-wrong bullets. The review is read-only:
/// bullets and notes are text, and cards are created through the existing
/// card-creator sheet.
class ErrorCardReviewView extends ConsumerStatefulWidget {
  const ErrorCardReviewView({required this.card, this.onCardsAdded, super.key});

  final ErrorCard card;

  /// Reports how many atomic cards were added so the page can advance.
  final ValueChanged<int>? onCardsAdded;

  @override
  ConsumerState<ErrorCardReviewView> createState() =>
      _ErrorCardReviewViewState();
}

class _ErrorCardReviewViewState extends ConsumerState<ErrorCardReviewView> {
  List<Note> _notes = const [];
  Object? _notesError;
  bool _cardsBusy = false;

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
      await showSnack(context, 'Note saved. It is ready in the card creator.');
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

  Future<void> _createCardFromNote(Note note) async {
    final card = widget.card;
    final added = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: card.sessionId,
        questionId: card.questionId,
        questionContext: card.question,
        topicName: card.topicName,
        subtopic: card.subtopic,
        initialKind: CardCreatorKind.concept,
        initialTerm: note.text,
        note: note,
      ),
    );
    if (!mounted || added == 0) return;
    await _loadNotes();
    if (!mounted) return;
    await showSnack(context, '$added card${added == 1 ? '' : 's'} created.');
  }

  Future<void> _deleteNote(Note note) async {
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

  Future<void> _createCards() async {
    if (_cardsBusy) return;
    final card = widget.card;
    setState(() => _cardsBusy = true);
    try {
      final added = await showCardCreator(
        context,
        request: CardCreatorRequest(
          title: 'Create cards',
          sessionId: card.sessionId,
          questionId: card.questionId,
          questionContext: card.question,
          topicName: card.topicName,
          subtopic: card.subtopic,
          error: CardCreatorErrorSource(
            card: card,
            question: card.question,
            wrongAnswer: card.wrongAnswer,
            correctAnswer: card.correctAnswer,
            reasoning: card.reasoning,
            explanation: card.explanation,
          ),
        ),
      );
      if (!mounted || added == 0) return;
      final report = widget.onCardsAdded;
      if (report != null) {
        report(added);
      } else {
        await showSnack(
          context,
          '$added card${added == 1 ? '' : 's'} created.',
        );
      }
    } finally {
      if (mounted) setState(() => _cardsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final card = widget.card;
    return QuestionFeedbackView(
      snapshot: FeedbackSnapshot.fromCard(card: card, notes: _notes),
      actions: FeedbackActions(
        onDefine: _define,
        onOpenUrl: _openUrl,
        onAsk: _ask,
        onSaveNote: _saveNote,
      ),
      notes: _notes,
      onCopyNote: _copyNote,
      onCreateCardFromNote: _createCardFromNote,
      onNoteOverflow: _openNoteActions,
      readOnly: true,
      hostFooter: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreateCardsSection(busy: _cardsBusy, onCreateCards: _createCards),
          if (_notesError != null) ...[
            const SizedBox(height: 12),
            TonalBox(
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
          ],
        ],
      ),
    );
  }
}

class _CreateCardsSection extends StatelessWidget {
  const _CreateCardsSection({required this.busy, required this.onCreateCards});

  final bool busy;
  final VoidCallback onCreateCards;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create cards', style: theme.typography.emphasized.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Turn this error and your bullets into atomic cards. AI suggestions '
          'are optional when an AI provider is configured.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        M3EButton.filled(
          key: const ValueKey('error-create-cards'),
          onPressed: busy ? null : onCreateCards,
          icon: const Icon(Icons.add_card),
          label: const Text('Create cards'),
        ),
      ],
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
              title: 'Delete note',
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
