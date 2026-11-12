import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/widgets.dart';
import 'domain/lookup_service.dart';

/// Rewrites a card field concisely with the configured AI provider.
///
/// The button edits the controller in place and reports through [onChanged] so
/// the surrounding form can revalidate. A missing key or provider is shown as
/// a message and never interrupts the form.
class AiSummarizeButton extends ConsumerStatefulWidget {
  const AiSummarizeButton({
    required this.controller,
    required this.fieldLabel,
    this.question,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;

  /// Readable name used in prompts and messages, such as "question".
  final String fieldLabel;

  /// Optional surrounding text, such as the original question.
  final String? question;
  final VoidCallback? onChanged;

  @override
  ConsumerState<AiSummarizeButton> createState() => _AiSummarizeButtonState();
}

class _AiSummarizeButtonState extends ConsumerState<AiSummarizeButton> {
  bool _busy = false;

  Future<void> _summarize() async {
    final source = widget.controller.text.trim();
    if (source.isEmpty) {
      await showSnack(context, 'Write the ${widget.fieldLabel} first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final summary = await ref
          .read(lookupServiceProvider)
          .summarizeText(
            text: source,
            fieldLabel: widget.fieldLabel,
            question: widget.question,
          );
      if (!mounted) return;
      widget.controller
        ..text = summary
        ..selection = TextSelection.collapsed(offset: summary.length);
      widget.onChanged?.call();
    } on LookupException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: M3EButton.text(
        onPressed: _busy ? null : _summarize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 18),
            const SizedBox(width: 8),
            Text(_busy ? 'Summarizing…' : 'Summarize with AI'),
          ],
        ),
      ),
    );
  }
}
