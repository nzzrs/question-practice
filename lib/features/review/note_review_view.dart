import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../feedback/domain/wrong_notes.dart';
import '../feedback/feedback_actions.dart';
import '../feedback/feedback_option_card.dart';
import '../lookup/lookup_actions.dart';

/// Shared reading surface for one saved note.
///
/// The end-of-session review and the Cards note review render the same
/// content: the saved note, its topic and practice, and a read-only
/// context action. Navigation, delete and card creation live in the shared
/// review dock, not in this view.
class NoteReviewView extends ConsumerStatefulWidget {
  const NoteReviewView({required this.note, super.key});

  final Note note;

  @override
  ConsumerState<NoteReviewView> createState() => _NoteReviewViewState();
}

class _NoteReviewViewState extends ConsumerState<NoteReviewView> {
  Question? _question;
  Attempt? _attempt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void didUpdateWidget(covariant NoteReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id ||
        oldWidget.note.questionId != widget.note.questionId ||
        oldWidget.note.sessionId != widget.note.sessionId) {
      _question = null;
      _attempt = null;
      _loading = true;
      _loadContext();
    }
  }

  Future<void> _loadContext() async {
    final questionId = widget.note.questionId;
    Question? question;
    Attempt? attempt;
    if (questionId != null) {
      try {
        question = await ref
            .read(topicRepositoryProvider)
            .questionById(questionId);
        final sessionId = widget.note.sessionId;
        if (question != null && sessionId != null) {
          attempt = await ref
              .read(sessionRepositoryProvider)
              .attemptForQuestion(sessionId, questionId);
        }
      } on Object {
        question = null;
        attempt = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _question = question;
      _attempt = attempt;
      _loading = false;
    });
  }

  Future<void> _showContext() async {
    final question = _question;
    if (question == null) return;
    await M3EBottomSheet.show<void>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) => _NoteContextSheet(
        note: widget.note,
        question: question,
        attempt: _attempt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final note = widget.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: TonalBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Pill('Note', tone: PillTone.primary),
                    if (note.topicName.trim().isNotEmpty) Pill(note.topicName),
                    if (note.practiceName.trim().isNotEmpty)
                      Pill(note.practiceName),
                    if (note.isKept) const Pill('Kept', tone: PillTone.success),
                    if (note.hasCard)
                      const Pill('Card made', tone: PillTone.success),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    note.text,
                    style: theme.typography.baseline.titleMedium.copyWith(
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox.shrink()
        else if (_question == null)
          Text(
            'Context unavailable.',
            key: const ValueKey('note-context-unavailable'),
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          M3EButton.text(
            key: const ValueKey('note-see-context'),
            onPressed: _showContext,
            child: const Text('See context'),
          ),
        if (note.hasCard) ...[
          const SizedBox(height: 8),
          TonalBox(
            key: const ValueKey('note-card-made'),
            child: Text(
              'Cards were already made from this note. The saved text '
              'stays in Cards until you delete it.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NoteContextSheet extends ConsumerWidget {
  const _NoteContextSheet({
    required this.note,
    required this.question,
    required this.attempt,
  });

  final Note note;
  final Question question;
  final Attempt? attempt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final selected = attempt?.selectedIndexes.toSet() ?? const <int>{};
    final reasoning = attempt == null
        ? const <String>[]
        : WrongNotes.parse(attempt!.reasoning);
    final actions = FeedbackActions(
      onDefine: (term, anchor) => openTermLookup(
        context,
        ref,
        term: term,
        question: question.prompt,
        topicName: note.topicName,
        practiceName: note.practiceName,
        sessionId: note.sessionId,
        questionId: note.questionId,
        subtopic: note.subtopic,
        anchor: anchor,
      ),
      onOpenUrl: (value) => openStudyUrl(context, ref, value),
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original question',
                style: theme.typography.baseline.labelMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.prompt,
                style: theme.typography.baseline.headlineSmall.copyWith(
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              for (final index in List<int>.generate(
                question.alternatives.length,
                (index) => index,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeedbackOptionCard(
                    originalIndex: index,
                    text: question.alternatives[index],
                    selected: selected.contains(index),
                    revealed: true,
                    isCorrect: question.correctIndexes.contains(index),
                    multiSelect: question.allowsMultiple,
                    showLetter: true,
                    explanation: index < question.alternativeExplanations.length
                        ? question.alternativeExplanations[index]
                        : '',
                    actions: actions,
                    notes: const [],
                  ),
                ),
              if (question.explanation.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                TonalBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this answer',
                        style: theme.typography.emphasized.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.explanation,
                        style: theme.typography.baseline.bodyMedium.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (reasoning.isNotEmpty) ...[
                const SizedBox(height: 10),
                TonalBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your reasoning',
                        style: theme.typography.emphasized.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reasoning.join('\n'),
                        style: theme.typography.baseline.bodyMedium.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
