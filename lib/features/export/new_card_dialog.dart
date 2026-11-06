import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

enum NewCardKind { concept, basic }

class NewCardDraft {
  const NewCardDraft.concept({required this.term, required this.definition})
    : kind = NewCardKind.concept,
      question = '',
      answer = '';

  const NewCardDraft.basic({required this.question, required this.answer})
    : kind = NewCardKind.basic,
      term = '',
      definition = '';

  final NewCardKind kind;
  final String term;
  final String definition;
  final String question;
  final String answer;
}

/// Asks for a concept or basic card, showing the source passage above.
Future<NewCardDraft?> showNewCardDialog(
  BuildContext context, {
  required String contextText,
  String initialTerm = '',
  String initialQuestion = '',
  String initialAnswer = '',
  NewCardKind initialKind = NewCardKind.basic,
  String title = 'Make a card',
}) {
  return M3EDialog.show<NewCardDraft>(
    context,
    dialog: _NewCardDialog(
      title: title,
      contextText: contextText,
      initialTerm: initialTerm,
      initialQuestion: initialQuestion,
      initialAnswer: initialAnswer,
      initialKind: initialKind,
    ),
  );
}

class _NewCardDialog extends StatefulWidget {
  const _NewCardDialog({
    required this.title,
    required this.contextText,
    required this.initialTerm,
    required this.initialQuestion,
    required this.initialAnswer,
    required this.initialKind,
  });

  final String title;
  final String contextText;
  final String initialTerm;
  final String initialQuestion;
  final String initialAnswer;
  final NewCardKind initialKind;

  @override
  State<_NewCardDialog> createState() => _NewCardDialogState();
}

class _NewCardDialogState extends State<_NewCardDialog> {
  late final _term = TextEditingController(text: widget.initialTerm);
  late final _definition = TextEditingController();
  late final _question = TextEditingController(text: widget.initialQuestion);
  late final _answer = TextEditingController(text: widget.initialAnswer);
  late NewCardKind _kind = widget.initialKind;

  @override
  void dispose() {
    _term.dispose();
    _definition.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  bool get _valid => _kind == NewCardKind.concept
      ? _term.text.trim().isNotEmpty && _definition.text.trim().isNotEmpty
      : _question.text.trim().isNotEmpty && _answer.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      _kind == NewCardKind.concept
          ? NewCardDraft.concept(
              term: _term.text.trim(),
              definition: _definition.text.trim(),
            )
          : NewCardDraft.basic(
              question: _question.text.trim(),
              answer: _answer.text.trim(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return M3EDialog(
      title: widget.title,
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.contextText.trim().isNotEmpty) ...[
                TonalBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    widget.contextText.trim(),
                    style: theme.typography.baseline.bodySmall.copyWith(
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              M3ESegmentedButton<NewCardKind>(
                segments: const [
                  M3ESegment(value: NewCardKind.basic, label: 'Basic card'),
                  M3ESegment(value: NewCardKind.concept, label: 'Concept'),
                ],
                selected: {_kind},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) {
                    setState(() => _kind = values.first);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_kind == NewCardKind.concept) ...[
                M3ETextField(
                  controller: _term,
                  label: 'Term',
                  isRequired: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                M3ETextField(
                  controller: _definition,
                  label: 'Definition',
                  minLines: 2,
                  maxLines: 4,
                  isRequired: true,
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                M3ETextField(
                  controller: _question,
                  label: 'Question',
                  minLines: 2,
                  maxLines: 4,
                  isRequired: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                M3ETextField(
                  controller: _answer,
                  label: 'Answer',
                  minLines: 2,
                  maxLines: 4,
                  isRequired: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: _valid ? _save : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
