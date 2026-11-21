import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../practice/selectable_linkified_text.dart';
import 'feedback_actions.dart';
import 'feedback_notes_section.dart';
import 'feedback_option_card.dart';
import 'feedback_selection_area.dart';
import 'feedback_snapshot.dart';
import 'feedback_status_banner.dart';
import 'wrong_notes_controller.dart';
import 'wrong_notes_editor.dart';
import 'wrong_notes_readonly.dart';

/// One feedback presentation for practice and the error review.
///
/// Practice passes an editable [controller] and its distraction checks; the
/// review passes read-only notes and its own host footer. Both get the same
/// topic, question, alternatives, explanations, status and bullets.
class QuestionFeedbackView extends StatefulWidget {
  const QuestionFeedbackView({
    required this.snapshot,
    required this.actions,
    this.leading,
    this.controller,
    this.checks,
    this.hostFooter,
    this.notes = const [],
    this.onCopyNote,
    this.onCreateCardFromNote,
    this.onNoteOverflow,
    this.onTurnBulletIntoCard,
    this.bulletBusy = false,
    this.activeBulletId,
    this.addedBulletIds = const {},
    this.showLetters = true,
    this.onOptionTap,
    this.scrollable = false,
    this.readOnly = false,
    this.pageStorageKey,
    this.scrollController,
    super.key,
  });

  final FeedbackSnapshot snapshot;
  final FeedbackActions actions;

  /// Step header in the review; scrolls with the content.
  final Widget? leading;

  /// Practice only: the live bullet editor state.
  final WrongNotesController? controller;

  /// Practice only: distraction and unknown checkboxes.
  final Widget? checks;
  final Widget? hostFooter;
  final List<Note> notes;
  final ValueChanged<Note>? onCopyNote;
  final ValueChanged<Note>? onCreateCardFromNote;
  final ValueChanged<Note>? onNoteOverflow;
  final void Function(String bulletId, String note)? onTurnBulletIntoCard;
  final bool bulletBusy;
  final String? activeBulletId;
  final Set<String> addedBulletIds;
  final bool showLetters;
  final ValueChanged<int>? onOptionTap;
  final bool scrollable;
  final bool readOnly;
  final PageStorageKey<String>? pageStorageKey;
  final ScrollController? scrollController;

  @override
  State<QuestionFeedbackView> createState() => _QuestionFeedbackViewState();
}

class _QuestionFeedbackViewState extends State<QuestionFeedbackView> {
  List<String> get _noteTexts => [for (final note in widget.notes) note.text];

  bool get _editable =>
      !widget.readOnly &&
      widget.snapshot.mode == FeedbackMode.practice &&
      widget.controller != null &&
      widget.snapshot.canEditWrongNotes;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final snapshot = widget.snapshot;
    final notes = _noteTexts;
    final readOnlyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading != null) widget.leading!,
        if (snapshot.topicName.isNotEmpty || snapshot.subtopic.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (snapshot.topicName.isNotEmpty)
                Text(
                  snapshot.topicName.toUpperCase(),
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (snapshot.subtopic.isNotEmpty)
                Pill(snapshot.subtopic, tone: PillTone.secondary),
            ],
          ),
        if (snapshot.topicName.isNotEmpty || snapshot.subtopic.isNotEmpty)
          const SizedBox(height: 6),
        SelectableLinkifiedText(
          text: snapshot.question,
          style: theme.typography.baseline.headlineSmall.copyWith(height: 1.3),
          useSelectionArea: false,
          onDefine: widget.actions.onDefine,
          onOpenUrl: widget.actions.onOpenUrl,
          onNote: widget.actions.onSaveNote,
          onAsk: widget.actions.onAsk,
          onNoteTap: widget.actions.onNoteTap,
          notes: notes,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.text_fields,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                snapshot.allowsMultiple
                    ? 'Select every correct alternative. Select text to define '
                          'a term.'
                    : 'Select text to define a term.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final index in widget.snapshot.order)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FeedbackOptionCard(
              originalIndex: index,
              text: snapshot.alternatives[index],
              selected: snapshot.selectedIndexes.contains(index),
              revealed: snapshot.revealed,
              isCorrect: snapshot.correctIndexes.contains(index),
              multiSelect: snapshot.allowsMultiple,
              showLetter: widget.showLetters,
              explanation: snapshot.alternativeExplanations.length > index
                  ? snapshot.alternativeExplanations[index]
                  : '',
              actions: widget.actions,
              notes: notes,
              onPressed: widget.onOptionTap == null
                  ? null
                  : () => widget.onOptionTap!(index),
            ),
          ),
        if (snapshot.revealed) ...[
          const SizedBox(height: 6),
          FeedbackStatusBanner(snapshot: snapshot),
          const SizedBox(height: 12),
          _WhyBox(snapshot: snapshot, actions: widget.actions, notes: notes),
          if (widget.checks != null) ...[
            const SizedBox(height: 10),
            widget.checks!,
          ],
          if (snapshot.mode == FeedbackMode.review &&
              snapshot.isDistracted) ...[
            const SizedBox(height: 10),
            const _DistractionWarning(),
          ],
        ],
        if (snapshot.mode == FeedbackMode.review) ...[
          const SizedBox(height: 16),
          WrongNotesReadonly(
            notes: snapshot.wrongNotes,
            actions: widget.actions,
            onTurnBulletIntoCard: widget.onTurnBulletIntoCard,
            bulletBusy: widget.bulletBusy,
            activeBulletId: widget.activeBulletId,
            addedBulletIds: widget.addedBulletIds,
          ),
          if (widget.onCopyNote != null || widget.onCreateCardFromNote != null)
            FeedbackNotesSection(
              notes: widget.notes,
              onCopy: widget.onCopyNote ?? (_) {},
              onCreateCard: widget.onCreateCardFromNote ?? (_) {},
              onOverflow: widget.onNoteOverflow,
            ),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editable)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeedbackSelectionArea(
                actions: widget.actions,
                child: readOnlyContent,
              ),
              const SizedBox(height: 18),
              WrongNotesEditor(controller: widget.controller!),
            ],
          )
        else
          FeedbackSelectionArea(
            actions: widget.actions,
            child: readOnlyContent,
          ),
        if (widget.hostFooter != null) ...[
          const SizedBox(height: 18),
          widget.hostFooter!,
        ],
        const SizedBox(height: 24),
      ],
    );

    if (!widget.scrollable) return content;
    return SingleChildScrollView(
      key: widget.pageStorageKey,
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: content,
    );
  }
}

class _WhyBox extends StatelessWidget {
  const _WhyBox({
    required this.snapshot,
    required this.actions,
    required this.notes,
  });

  final FeedbackSnapshot snapshot;
  final FeedbackActions actions;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return TonalBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why this answer',
            style: theme.typography.emphasized.titleSmall,
          ),
          const SizedBox(height: 6),
          SelectableLinkifiedText(
            text: snapshot.explanation,
            style: theme.typography.baseline.bodyMedium.copyWith(height: 1.45),
            useSelectionArea: false,
            onDefine: actions.onDefine,
            onOpenUrl: actions.onOpenUrl,
            onNote: actions.onSaveNote,
            onAsk: actions.onAsk,
            onNoteTap: actions.onNoteTap,
            notes: notes,
          ),
        ],
      ),
    );
  }
}

class _DistractionWarning extends StatelessWidget {
  const _DistractionWarning();

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return TonalBox(
      key: const ValueKey('feedback-distraction-warning'),
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You were distracted or misread. This card stays due.',
              style: theme.typography.baseline.bodySmall.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
