import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'row_action_menu.dart';

enum _NoteRowAction { copy, createCard, define, ask, delete }

/// Notes saved for the reviewed question, each with a three-dot action menu.
///
/// Lives inside the feedback selection area; its rows are plain selectable
/// text plus ordinary buttons, never a nested SelectionArea.
class FeedbackNotesSection extends StatelessWidget {
  const FeedbackNotesSection({
    required this.notes,
    required this.onCopy,
    this.onCreateCard,
    this.onDefine,
    this.onAsk,
    this.onDelete,
    super.key,
  });

  final List<Note> notes;
  final ValueChanged<Note> onCopy;
  final ValueChanged<Note>? onCreateCard;
  final ValueChanged<Note>? onDefine;
  final ValueChanged<Note>? onAsk;
  final ValueChanged<Note>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = M3ETheme.of(context);
    return Column(
      key: const ValueKey('feedback-notes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          'Notes for this question',
          style: theme.typography.emphasized.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TonalBox(
              key: ValueKey('feedback-note-${note.id}'),
              color: theme.colorScheme.surfaceContainerLow,
              radius: 16,
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '“${note.text.trim()}”',
                        style: theme.typography.baseline.bodyMedium.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildMenu(note),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenu(Note note) {
    return RowActionMenu<_NoteRowAction>(
      menuKey: ValueKey('feedback-note-more-${note.id}'),
      tooltip: 'Note actions',
      items: [
        RowActionItem(
          value: _NoteRowAction.copy,
          label: 'Copy',
          icon: Icons.copy_all_outlined,
          key: ValueKey('feedback-note-copy-${note.id}'),
        ),
        if (onCreateCard != null)
          RowActionItem(
            value: _NoteRowAction.createCard,
            label: note.hasCard ? 'Card created' : 'Create card',
            icon: note.hasCard ? Icons.check : Icons.auto_awesome_outlined,
            key: ValueKey('feedback-note-card-${note.id}'),
            enabled: !note.hasCard,
          ),
        if (onDefine != null)
          RowActionItem(
            value: _NoteRowAction.define,
            label: 'Define',
            icon: Icons.menu_book_outlined,
            key: ValueKey('feedback-note-define-${note.id}'),
          ),
        if (onAsk != null)
          RowActionItem(
            value: _NoteRowAction.ask,
            label: 'Ask',
            icon: Icons.question_answer_outlined,
            key: ValueKey('feedback-note-ask-${note.id}'),
          ),
        if (onDelete != null)
          RowActionItem(
            value: _NoteRowAction.delete,
            label: 'Delete',
            icon: Icons.delete_outline,
            key: ValueKey('feedback-note-delete-${note.id}'),
            destructive: true,
          ),
      ],
      onSelected: (action) {
        switch (action) {
          case _NoteRowAction.copy:
            onCopy(note);
          case _NoteRowAction.createCard:
            onCreateCard?.call(note);
          case _NoteRowAction.define:
            onDefine?.call(note);
          case _NoteRowAction.ask:
            onAsk?.call(note);
          case _NoteRowAction.delete:
            onDelete?.call(note);
        }
      },
    );
  }
}
