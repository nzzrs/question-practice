import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../lookup/ai_summarize_button.dart';
import 'error_card_content.dart';

/// Opens the full-page editor for an error card's question and explanations.
///
/// The page saves through the review service and returns the saved content so
/// the caller can refresh the card it is showing.
Future<ErrorCardContent?> openErrorCardContentEditor(
  BuildContext context, {
  required ErrorCard card,
  required ErrorCardContent current,
}) {
  return Navigator.of(context).push<ErrorCardContent>(
    MaterialPageRoute<ErrorCardContent>(
      builder: (context) =>
          ErrorCardContentEditorPage(card: card, current: current),
    ),
  );
}

/// Full page editor for an error card's question, options and explanations.
///
/// Correct and chosen-wrong indexes are never touched here: they stay attached
/// to the card so the edited wording keeps its original linkage.
class ErrorCardContentEditorPage extends ConsumerStatefulWidget {
  const ErrorCardContentEditorPage({
    required this.card,
    required this.current,
    super.key,
  });

  final ErrorCard card;
  final ErrorCardContent current;

  @override
  ConsumerState<ErrorCardContentEditorPage> createState() =>
      _ErrorCardContentEditorPageState();
}

class _ErrorCardContentEditorPageState
    extends ConsumerState<ErrorCardContentEditorPage> {
  late final TextEditingController _question;
  late final List<TextEditingController> _alternatives;
  late final List<TextEditingController> _explanations;
  late final TextEditingController _explanation;
  final Set<int> _touchedAlternatives = {};
  bool _questionTouched = false;
  bool _overallExpanded = false;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(text: widget.current.question);
    _alternatives = [
      for (final value in widget.current.alternatives)
        TextEditingController(text: value),
    ];
    _explanations = [
      for (var index = 0; index < widget.current.alternatives.length; index++)
        TextEditingController(
          text: widget.current.alternativeExplanation(index),
        ),
    ];
    _explanation = TextEditingController(text: widget.current.explanation);
  }

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    for (final controller in _alternatives) {
      controller.dispose();
    }
    for (final controller in _explanations) {
      controller.dispose();
    }
    super.dispose();
  }

  ErrorCardContent _buildContent() {
    return ErrorCardContent(
      question: _question.text.trim(),
      alternatives: [
        for (final controller in _alternatives) controller.text.trim(),
      ],
      explanation: _explanation.text.trim(),
      alternativeExplanations: [
        for (final controller in _explanations) controller.text.trim(),
      ],
    );
  }

  bool get _valid =>
      _question.text.trim().isNotEmpty &&
      _alternatives.every((controller) => controller.text.trim().isNotEmpty);

  bool get _dirty => !_sameContent(_buildContent(), widget.current);

  bool get _canSave => _valid && _dirty && !_saving;

  String? get _questionError {
    if (!_questionTouched || _question.text.trim().isNotEmpty) return null;
    return 'Write the question.';
  }

  String? _optionError(int index) {
    if (!_touchedAlternatives.contains(index)) return null;
    if (_alternatives[index].text.trim().isNotEmpty) return null;
    return 'Write option ${_letterFor(index)}.';
  }

  bool _sameContent(ErrorCardContent left, ErrorCardContent right) {
    if (left.question != right.question) return false;
    if (left.explanation != right.explanation) return false;
    if (left.alternatives.length != right.alternatives.length) return false;
    for (var index = 0; index < left.alternatives.length; index++) {
      if (left.alternatives[index] != right.alternatives[index]) return false;
    }
    final leftExplanations = left.alternativeExplanations;
    final rightExplanations = right.alternativeExplanations;
    for (var index = 0; index < left.alternatives.length; index++) {
      final leftValue = index < leftExplanations.length
          ? leftExplanations[index]
          : '';
      final rightValue = index < rightExplanations.length
          ? rightExplanations[index]
          : '';
      if (leftValue != rightValue) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final content = _buildContent();
    setState(() => _saving = true);
    try {
      await ref
          .read(reviewServiceProvider)
          .saveErrorContent(
            cardId: widget.card.id,
            question: content.question,
            alternatives: content.alternatives,
            explanation: content.explanation,
            alternativeExplanations: content.alternativeExplanations,
          );
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop(content);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showSnack(context, 'Could not update the card: $error');
    }
  }

  Future<bool> _confirmDiscard() {
    return confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your edits to this card will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _handleBlockedPop() async {
    if (_saving) return;
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  String get _subtitle {
    final parts = [
      if (widget.card.topicName.trim().isNotEmpty) widget.card.topicName,
      if (widget.card.practiceName.trim().isNotEmpty) widget.card.practiceName,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBlockedPop();
      },
      child: AppPage(
        title: 'Edit card content',
        subtitle: _subtitle.isEmpty ? null : _subtitle,
        showBack: true,
        variant: M3EAppBarVariant.small,
        bottomBar: AppActionDock(
          child: Row(
            children: [
              M3EButton.text(
                key: const ValueKey('edit-error-content-cancel'),
                onPressed: _saving ? null : _requestClose,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  key: const ValueKey('edit-error-content-save'),
                  onPressed: _canSave ? _save : null,
                  label: _saving ? 'Saving…' : 'Save changes',
                  icon: Icons.check,
                ),
              ),
            ],
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TonalBox(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fix the wording or add the reasoning behind an answer. '
                        'Correct and chosen options keep their letters and links.',
                        style: theme.typography.baseline.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _EditorSectionHeader(
                icon: Icons.help_outline,
                title: 'Question',
                supporting: 'The prompt exactly as it should read.',
              ),
              const SizedBox(height: 10),
              M3ETextField(
                key: const ValueKey('edit-error-question'),
                controller: _question,
                label: 'Question',
                placeholder: 'What is the question?',
                minLines: 3,
                maxLines: 6,
                isRequired: true,
                errorText: _questionError,
                trailing: AiSummarizeButton(
                  key: const ValueKey('edit-error-question-summarize'),
                  controller: _question,
                  fieldLabel: 'question',
                  compact: true,
                  onChanged: () => setState(() => _questionTouched = true),
                ),
                onChanged: (_) => setState(() => _questionTouched = true),
              ),
              const SizedBox(height: 26),
              _EditorSectionHeader(
                icon: Icons.checklist_outlined,
                title: 'Options',
                supporting:
                    'Open an explanation only when the answer needs one. '
                    'Letters, correct answers and chosen wrong answers stay linked.',
                trailing: Pill('${_alternatives.length}'),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _alternatives.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _OptionEditor(
                  index: index,
                  controller: _alternatives[index],
                  explanation: _explanations[index],
                  isCorrect: widget.card.correctIndexes.contains(index),
                  isWrong: widget.card.wrongIndexes.contains(index),
                  errorText: _optionError(index),
                  onChanged: () =>
                      setState(() => _touchedAlternatives.add(index)),
                ),
              ],
              const SizedBox(height: 22),
              TonalBox(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionToggle(
                      toggleKey: const ValueKey(
                        'edit-error-explanation-toggle',
                      ),
                      icon: Icons.lightbulb_outline,
                      title: 'Overall explanation',
                      supporting: _explanation.text.trim().isEmpty
                          ? 'Optional context for the whole question'
                          : 'Explanation added',
                      expanded: _overallExpanded,
                      onTap: () =>
                          setState(() => _overallExpanded = !_overallExpanded),
                    ),
                    if (_overallExpanded) ...[
                      const SizedBox(height: 8),
                      M3ETextField(
                        key: const ValueKey('edit-error-explanation'),
                        controller: _explanation,
                        label: 'Overall explanation',
                        placeholder: 'Why the correct answer is right.',
                        minLines: 3,
                        maxLines: 6,
                        trailing: AiSummarizeButton(
                          key: const ValueKey(
                            'edit-error-explanation-summarize',
                          ),
                          controller: _explanation,
                          fieldLabel: 'overall explanation',
                          question: _question.text,
                          compact: true,
                          onChanged: () => setState(() {}),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _dirty
                    ? 'Unsaved changes. Save when the wording is right.'
                    : 'No changes yet.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _letterFor(int index) => String.fromCharCode(65 + index);

class _EditorSectionHeader extends StatelessWidget {
  const _EditorSectionHeader({
    required this.icon,
    required this.title,
    this.supporting,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? supporting;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.typography.emphasized.titleMedium,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (supporting != null) ...[
          const SizedBox(height: 4),
          Text(
            supporting!,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.toggleKey,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.supporting,
  });

  final Key toggleKey;
  final IconData icon;
  final String title;
  final String? supporting;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Semantics(
      button: true,
      label: expanded ? 'Hide $title' : 'Show $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: toggleKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.typography.baseline.titleSmall.copyWith(
                          height: 1.25,
                        ),
                      ),
                      if (supporting != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          supporting!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.baseline.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({
    required this.index,
    required this.controller,
    required this.explanation,
    required this.isCorrect,
    required this.isWrong,
    required this.errorText,
    required this.onChanged,
  });

  final int index;
  final TextEditingController controller;
  final TextEditingController explanation;
  final bool isCorrect;
  final bool isWrong;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  bool _expanded = false;

  String get _letter => _letterFor(widget.index);

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final tone = widget.isCorrect
        ? AppSuccess.onContainer(context)
        : widget.isWrong
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return TonalBox(
      key: ValueKey('edit-error-option-card-${widget.index}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _letter,
                  style: theme.typography.baseline.labelMedium.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Option $_letter',
                        style: theme.typography.baseline.labelLarge.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (widget.isCorrect)
                        const Pill('Correct', tone: PillTone.success),
                      if (widget.isWrong)
                        const Pill('Chosen wrong', tone: PillTone.error),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          M3ETextField(
            key: ValueKey('edit-error-option-${widget.index}'),
            controller: widget.controller,
            label: 'Option $_letter',
            placeholder: 'Option text',
            minLines: 1,
            maxLines: 3,
            isRequired: true,
            errorText: widget.errorText,
            trailing: AiSummarizeButton(
              key: ValueKey('edit-error-option-${widget.index}-summarize'),
              controller: widget.controller,
              fieldLabel: 'option $_letter',
              compact: true,
              onChanged: widget.onChanged,
            ),
            onChanged: (_) => widget.onChanged(),
          ),
          const SizedBox(height: 2),
          _SectionToggle(
            toggleKey: ValueKey(
              'edit-error-option-${widget.index}-explanation-toggle',
            ),
            icon: Icons.notes_outlined,
            title: 'Explanation',
            supporting: widget.explanation.text.trim().isEmpty
                ? 'Optional reason for this option'
                : 'Explanation added',
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            M3ETextField(
              key: ValueKey('edit-error-option-${widget.index}-explanation'),
              controller: widget.explanation,
              label: 'Explanation for option $_letter',
              placeholder: 'Why this option is right or wrong.',
              minLines: 2,
              maxLines: 4,
              trailing: AiSummarizeButton(
                key: ValueKey(
                  'edit-error-option-${widget.index}-explanation-summarize',
                ),
                controller: widget.explanation,
                fieldLabel: 'explanation for option $_letter',
                question: widget.controller.text,
                compact: true,
                onChanged: widget.onChanged,
              ),
              onChanged: (_) => widget.onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}
