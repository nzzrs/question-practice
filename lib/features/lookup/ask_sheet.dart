import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/widgets.dart';
import '../export/card_creator_page.dart';
import 'domain/lookup_service.dart';

/// Opens a sheet that asks the configured AI about the selected passage.
Future<void> showAskAboutSelection(
  BuildContext context, {
  required String selection,
  required String question,
  required String topicName,
  required String practiceName,
  required int? sessionId,
  required int? questionId,
  String subtopic = '',
}) {
  return M3EBottomSheet.show<void>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => AskSheet(
      selection: selection,
      question: question,
      topicName: topicName,
      practiceName: practiceName,
      sessionId: sessionId,
      questionId: questionId,
      subtopic: subtopic,
    ),
  );
}

class AskSheet extends ConsumerStatefulWidget {
  const AskSheet({
    required this.selection,
    required this.question,
    required this.topicName,
    required this.practiceName,
    required this.sessionId,
    required this.questionId,
    this.subtopic = '',
    super.key,
  });

  final String selection;
  final String question;
  final String topicName;
  final String practiceName;
  final int? sessionId;
  final int? questionId;
  final String subtopic;

  @override
  ConsumerState<AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<AskSheet> {
  final _message = TextEditingController();
  String? _answer;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Write a question first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await ref
          .read(lookupServiceProvider)
          .ask(
            selection: widget.selection,
            question: widget.question,
            topicName: widget.topicName,
            userQuestion: message,
          );
      if (!mounted) return;
      setState(() => _answer = answer);
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCards() async {
    final answer = _answer;
    if (answer == null) return;
    final message = _message.text.trim();
    final created = await showCardCreator(
      context,
      request: CardCreatorRequest(
        title: 'Create cards',
        sessionId: widget.sessionId,
        questionId: widget.questionId,
        questionContext: widget.question,
        topicName: widget.topicName,
        subtopic: widget.subtopic,
        initialFront: message.isEmpty ? widget.selection : message,
        initialBack: answer,
      ),
    );
    if (!mounted || created == 0) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask about this',
              style: theme.typography.emphasized.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'The AI sees the passage, its question and your message.',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TonalBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                widget.selection.trim(),
                style: theme.typography.baseline.bodyMedium.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            M3ETextField(
              controller: _message,
              label: 'Your question',
              placeholder: 'Why does this apply here?',
              minLines: 2,
              maxLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            M3EButton.filled(
              onPressed: _busy ? null : _ask,
              icon: const Icon(Icons.help_outline),
              label: Text(_busy ? 'Asking…' : 'Ask'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: M3ELoadingIndicator()),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              TonalBox(
                color: theme.colorScheme.errorContainer,
                child: Text(
                  _error!,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 16),
              TonalBox(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _answer!,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  M3EButton.tonal(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _answer = null;
                            _error = null;
                          }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Ask another'),
                  ),
                  M3EButton.filled(
                    key: const ValueKey('ask-create-cards'),
                    onPressed: _busy ? null : _createCards,
                    icon: const Icon(Icons.add_card),
                    label: const Text('Create cards'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
