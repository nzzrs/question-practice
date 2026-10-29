import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'domain/lookup_service.dart';

class LookupSheet extends ConsumerStatefulWidget {
  const LookupSheet({
    required this.term,
    required this.question,
    required this.topicName,
    required this.practiceName,
    required this.sessionId,
    required this.questionId,
    super.key,
  });

  final String term;
  final String question;
  final String topicName;
  final String practiceName;
  final int? sessionId;
  final int? questionId;

  @override
  ConsumerState<LookupSheet> createState() => _LookupSheetState();
}

class _LookupSheetState extends ConsumerState<LookupSheet> {
  final _definition = TextEditingController();
  LookupResult? _result;
  LookupException? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _definition.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await ref
          .read(lookupServiceProvider)
          .define(
            term: widget.term,
            question: widget.question,
            topicName: widget.topicName,
            practiceName: widget.practiceName,
            sessionId: widget.sessionId,
            questionId: widget.questionId,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _definition.text = result.definition;
        _loading = false;
      });
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _webFallback() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(lookupServiceProvider)
          .openWeb(
            term: widget.term,
            question: widget.question,
            topicName: widget.topicName,
            practiceName: widget.practiceName,
            sessionId: widget.sessionId,
            questionId: widget.questionId,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _definition.text = result.definition;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = LookupException('Could not open the browser: $error');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(cardRepositoryProvider)
          .updateConceptDefinition(result.conceptId, _definition.text.trim());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            Text(widget.term, style: theme.typography.emphasized.headlineSmall),
            const SizedBox(height: 2),
            Text(
              'Selected term',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: M3ELoadingIndicator()),
              )
            else if (_error != null) ...[
              TonalBox(
                color: theme.colorScheme.errorContainer,
                child: Text(
                  _error!.message,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              if (_error!.canUseWeb) ...[
                const SizedBox(height: 12),
                M3EButton.tonal(
                  onPressed: _webFallback,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Search the web instead'),
                ),
              ],
            ] else if (_result != null) ...[
              if (_result!.source == ConceptSource.web && _result!.openedWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'The browser is open. Add the definition here when you have it.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              M3ETextField(
                controller: _definition,
                label: 'Definition',
                maxLines: 4,
                minLines: 2,
                supportingText: 'Saved as a missing concept for this session.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  M3EButton.filled(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                  const SizedBox(width: 8),
                  if (_result!.source == ConceptSource.web)
                    M3EButton.text(
                      onPressed: _webFallback,
                      child: const Text('Open again'),
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
