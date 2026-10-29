import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'domain/anki_note_builder.dart';

enum _Filter { all, concepts, errors, basic }

class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  final _selectedConcepts = <int>{};
  final _selectedErrors = <int>{};
  final _selectedBasic = <int>{};
  bool _initialized = false;
  bool _busy = false;
  bool _showExported = false;
  _Filter _filter = _Filter.all;

  ExportSelection _selection({
    required List<Concept> concepts,
    required List<ErrorCard> errors,
    required List<ManualCard> manuals,
  }) {
    return ExportSelection(
      concepts: concepts
          .where((item) => _selectedConcepts.contains(item.id))
          .toList(),
      errorCards: errors
          .where((item) => _selectedErrors.contains(item.id))
          .toList(),
      manualCards: manuals
          .where((item) => _selectedBasic.contains(item.id))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conceptsAsync = ref.watch(allConceptsProvider);
    final errorsAsync = ref.watch(allErrorCardsProvider);
    final manualsAsync = ref.watch(allManualCardsProvider);
    final topicSummaries = ref.watch(topicSummariesProvider).value ?? const [];
    final defaultDeck =
        ref.watch(settingsProvider).value?.ankiDeck ?? 'Question Practice';
    final deckByTopic = {
      for (final topic in topicSummaries)
        if (topic.topic.ankiDeck != null &&
            topic.topic.ankiDeck!.trim().isNotEmpty)
          topic.topic.name: topic.topic.ankiDeck!.trim(),
    };
    String deckFor(String topicName) {
      final configured = deckByTopic[topicName.trim()];
      return configured == null || configured.isEmpty
          ? defaultDeck
          : configured;
    }

    final allConcepts = conceptsAsync.value ?? const <Concept>[];
    final allErrors = errorsAsync.value ?? const <ErrorCard>[];
    final allManuals = manualsAsync.value ?? const <ManualCard>[];
    final concepts = _showExported
        ? allConcepts
        : allConcepts.where((item) => item.exportedAt == null).toList();
    final errors = _showExported
        ? allErrors
        : allErrors.where((item) => item.exportedAt == null).toList();
    final manuals = _showExported
        ? allManuals
        : allManuals.where((item) => item.exportedAt == null).toList();

    if (!_initialized &&
        conceptsAsync.hasValue &&
        errorsAsync.hasValue &&
        manualsAsync.hasValue) {
      _initialized = true;
      _selectedConcepts.addAll(
        concepts
            .where((item) => item.isExportable && item.exportedAt == null)
            .map((item) => item.id),
      );
      _selectedErrors.addAll(
        errors
            .where((item) => !item.needsDetails && item.exportedAt == null)
            .map((item) => item.id),
      );
      _selectedBasic.addAll(
        manuals.where((item) => item.exportedAt == null).map((item) => item.id),
      );
    }

    final selection = _selection(
      concepts: concepts,
      errors: errors,
      manuals: manuals,
    );
    final loading =
        conceptsAsync.isLoading ||
        errorsAsync.isLoading ||
        manualsAsync.isLoading;
    final theme = M3ETheme.of(context);

    return AppScaffold(
      title: 'Cards',
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: Icon(
            _showExported ? Icons.visibility : Icons.visibility_outlined,
          ),
          tooltip: _showExported
              ? 'Hide exported cards'
              : 'Show exported cards',
          isSelected: _showExported,
          onPressed: () => setState(() => _showExported = !_showExported),
        ),
      ],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: theme.colorScheme.surfaceContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selection.total} selected',
                      style: theme.typography.baseline.labelMedium,
                    ),
                  ),
                  M3EButton.text(
                    onPressed: selection.total == 0 ? null : _deleteSelected,
                    child: const Text('Delete selected'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: M3EButton.filled(
                  onPressed: _busy || selection.total == 0
                      ? null
                      : () => _export(selection),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(_busy ? 'Exporting…' : 'Export to AnkiDroid'),
                ),
              ),
              const SizedBox(height: 2),
              M3EButton.text(
                onPressed: _busy || selection.total == 0
                    ? null
                    : () => _share(selection),
                child: const Text('Share as files'),
              ),
            ],
          ),
        ),
      ),
      body:
          loading &&
              allConcepts.isEmpty &&
              allErrors.isEmpty &&
              allManuals.isEmpty
          ? const Center(child: M3ELoadingIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Review what goes to Anki. Concepts become cloze cards, errors have five fields, and skipped-question cards are basic front/back. Each topic uses its own deck; topics without one use the default deck from Settings.',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                M3ESegmentedButton<_Filter>(
                  segments: const [
                    M3ESegment(value: _Filter.all, label: 'All'),
                    M3ESegment(value: _Filter.concepts, label: 'Concepts'),
                    M3ESegment(value: _Filter.errors, label: 'Errors'),
                    M3ESegment(value: _Filter.basic, label: 'Basic'),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (values) {
                    if (values.isNotEmpty) {
                      setState(() => _filter = values.first);
                    }
                  },
                ),
                const SizedBox(height: 20),
                if ((_filter == _Filter.all || _filter == _Filter.concepts) &&
                    concepts.isNotEmpty) ...[
                  SectionTitle(
                    'Concepts · ${concepts.length}',
                    trailing: _SelectAllButton(
                      allSelected: concepts
                          .where(
                            (item) =>
                                item.isExportable && item.exportedAt == null,
                          )
                          .every((item) => _selectedConcepts.contains(item.id)),
                      onPressed: () => setState(() {
                        final selectable = concepts
                            .where(
                              (item) =>
                                  item.isExportable && item.exportedAt == null,
                            )
                            .map((item) => item.id);
                        if (selectable.every(_selectedConcepts.contains)) {
                          _selectedConcepts.removeAll(selectable);
                        } else {
                          _selectedConcepts.addAll(selectable);
                        }
                      }),
                    ),
                  ),
                  for (final concept in concepts) ...[
                    _ConceptRow(
                      concept: concept,
                      deckName: deckFor(concept.topicName),
                      selected: _selectedConcepts.contains(concept.id),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selectedConcepts.add(concept.id);
                        } else {
                          _selectedConcepts.remove(concept.id);
                        }
                      }),
                      onComplete: concept.isExportable
                          ? null
                          : () => _editConcept(concept),
                      onPreview: () => _previewConcept(concept),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                ],
                if ((_filter == _Filter.all || _filter == _Filter.errors) &&
                    errors.isNotEmpty) ...[
                  SectionTitle(
                    'Error cards · ${errors.length}',
                    trailing: _SelectAllButton(
                      allSelected: errors
                          .where(
                            (item) =>
                                !item.needsDetails && item.exportedAt == null,
                          )
                          .every((item) => _selectedErrors.contains(item.id)),
                      onPressed: () => setState(() {
                        final selectable = errors
                            .where(
                              (item) =>
                                  !item.needsDetails && item.exportedAt == null,
                            )
                            .map((item) => item.id);
                        if (selectable.every(_selectedErrors.contains)) {
                          _selectedErrors.removeAll(selectable);
                        } else {
                          _selectedErrors.addAll(selectable);
                        }
                      }),
                    ),
                  ),
                  for (final card in errors) ...[
                    _ErrorRow(
                      card: card,
                      deckName: deckFor(card.topicName),
                      selected: _selectedErrors.contains(card.id),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selectedErrors.add(card.id);
                        } else {
                          _selectedErrors.remove(card.id);
                        }
                      }),
                      onComplete: card.needsDetails
                          ? () => _editError(card)
                          : null,
                      onPreview: () => _previewError(card),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                ],
                if ((_filter == _Filter.all || _filter == _Filter.basic) &&
                    manuals.isNotEmpty) ...[
                  SectionTitle(
                    'Basic cards · ${manuals.length}',
                    trailing: _SelectAllButton(
                      allSelected: manuals
                          .where((item) => item.exportedAt == null)
                          .every((item) => _selectedBasic.contains(item.id)),
                      onPressed: () => setState(() {
                        final selectable = manuals
                            .where((item) => item.exportedAt == null)
                            .map((item) => item.id);
                        if (selectable.every(_selectedBasic.contains)) {
                          _selectedBasic.removeAll(selectable);
                        } else {
                          _selectedBasic.addAll(selectable);
                        }
                      }),
                    ),
                  ),
                  for (final card in manuals) ...[
                    _ManualRow(
                      card: card,
                      deckName: deckFor(card.topicName),
                      selected: _selectedBasic.contains(card.id),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selectedBasic.add(card.id);
                        } else {
                          _selectedBasic.remove(card.id);
                        }
                      }),
                      onPreview: () => _previewManual(card),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (!loading &&
                    concepts.isEmpty &&
                    errors.isEmpty &&
                    manuals.isEmpty)
                  const EmptyState(
                    icon: Icons.style_outlined,
                    title: 'No cards to export',
                    message: 'Review a session to create error cards, or define a term to save a concept.',
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: M3ELoadingIndicator()),
                  ),
              ],
            ),
    );
  }

  Future<void> _export(ExportSelection selection) async {
    final gateway = ref.read(ankiGatewayProvider);
    var status = await gateway.status();
    if (status.installed && status.apiAvailable && !status.permissionGranted) {
      status = await gateway.requestPermission();
    }
    if (!status.installed) {
      if (mounted) await showSnack(context, 'Install AnkiDroid first.');
      return;
    }
    if (!status.apiAvailable) {
      if (mounted) {
        await _statusDialog(
          title: 'AnkiDroid API is off',
          message: 'Open AnkiDroid, go to Settings → Advanced, and enable the AnkiDroid API. Then try again.',
        );
      }
      return;
    }
    if (!status.permissionGranted) {
      if (mounted) {
        await _statusDialog(
          title: 'Permission needed',
          message: 'Question Practice needs permission to read and write the AnkiDroid database.',
        );
      }
      return;
    }
    if (!status.conceptModelAvailable) {
      if (mounted) {
        await _statusDialog(
          title: 'Cloze note type missing',
          message: 'AnkiDroid has no Cloze note type. Create one in AnkiDroid, then retry. Error and basic note types are created automatically.',
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final settings = ref.read(settingsProvider).value ?? const AppSettings();
      final outcome = await ref
          .read(exportServiceProvider)
          .exportToAnki(deckName: settings.ankiDeck, selection: selection);
      if (!mounted) return;
      if (outcome.success) {
        setState(() {
          _selectedConcepts.clear();
          _selectedErrors.clear();
          _selectedBasic.clear();
        });
      }
      await showSnack(context, outcome.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ExportSelection selection) async {
    setState(() => _busy = true);
    try {
      await ref.read(exportServiceProvider).shareFiles(selection);
    } on Object catch (error) {
      if (mounted) await showSnack(context, 'Could not share files: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete selected cards?',
      message: 'Concepts and basic cards are removed permanently. Deleting an active error card also removes it from the 48-hour review queue.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await ref
        .read(cardRepositoryProvider)
        .deleteCards(
          conceptIds: _selectedConcepts.toList(),
          errorCardIds: _selectedErrors.toList(),
          manualCardIds: _selectedBasic.toList(),
        );
    setState(() {
      _selectedConcepts.clear();
      _selectedErrors.clear();
      _selectedBasic.clear();
    });
    if (mounted) await showSnack(context, 'Cards deleted.');
  }

  Future<void> _editConcept(Concept concept) async {
    final controller = TextEditingController(text: concept.definition);
    final saved = await M3EDialog.show<bool>(
      context,
      dialog: M3EDialog(
        title: 'Definition of ${concept.term}',
        content: SingleChildScrollView(
          child: M3ETextField(
            controller: controller,
            label: 'Definition',
            minLines: 2,
            maxLines: 4,
            autofocus: true,
          ),
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          M3EButton.filled(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(cardRepositoryProvider)
          .updateConceptDefinition(concept.id, controller.text.trim());
      if (!mounted) return;
      setState(() => _selectedConcepts.add(concept.id));
    }
    controller.dispose();
  }

  Future<void> _editError(ErrorCard card) async {
    final bias = TextEditingController(text: card.bias);
    final vaccine = TextEditingController(text: card.vaccine);
    final saved = await M3EDialog.show<bool>(
      context,
      dialog: M3EDialog(
        title: 'Complete error card',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3ETextField(
                controller: bias,
                label: 'What was the flawed assumption?',
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              M3ETextField(
                controller: vaccine,
                label: 'How will you prevent it?',
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          M3EButton.filled(
            onPressed: () {
              if (bias.text.trim().isEmpty || vaccine.text.trim().isEmpty) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(cardRepositoryProvider)
          .updateErrorCardDetails(
            id: card.id,
            bias: bias.text,
            vaccine: vaccine.text,
            completedAt: ref.read(clockProvider).now().toUtc(),
          );
      if (mounted) setState(() => _selectedErrors.add(card.id));
    }
    bias.dispose();
    vaccine.dispose();
  }

  Future<void> _previewConcept(Concept concept) {
    return _previewDialog('Concept preview', [
      Text(
        const AnkiNoteBuilder().conceptCloze(concept.term, concept.definition),
        style: const TextStyle(fontFamily: 'monospace', height: 1.5),
      ),
      const SizedBox(height: 8),
      Text(
        'One cloze note · ${concept.source.name} · ${concept.topicName} · deck: ${_deckForTopic(concept.topicName)}',
      ),
    ]);
  }

  Future<void> _previewError(ErrorCard card) {
    return _previewDialog('Error card preview', [
      _PreviewField(label: 'Deck', value: _deckForTopic(card.topicName)),
      _PreviewField(label: 'Question', value: card.question),
      _PreviewField(label: 'Wrong answer', value: card.wrongAnswer),
      _PreviewField(label: 'Correct answer', value: card.correctAnswer),
      _PreviewField(
        label: 'Bias',
        value: card.bias.isEmpty ? '— needs notes —' : card.bias,
      ),
      _PreviewField(
        label: 'Vaccine',
        value: card.vaccine.isEmpty ? '— needs notes —' : card.vaccine,
      ),
    ]);
  }

  Future<void> _previewManual(ManualCard card) {
    return _previewDialog('Basic card preview', [
      _PreviewField(label: 'Deck', value: _deckForTopic(card.topicName)),
      _PreviewField(label: 'Front', value: card.question),
      _PreviewField(label: 'Back', value: card.answer),
    ]);
  }

  String _deckForTopic(String topicName) {
    final topics = ref.read(topicSummariesProvider).value ?? const [];
    final defaultDeck =
        ref.read(settingsProvider).value?.ankiDeck ?? 'Question Practice';
    for (final summary in topics) {
      if (summary.topic.name == topicName &&
          summary.topic.ankiDeck != null &&
          summary.topic.ankiDeck!.trim().isNotEmpty) {
        return summary.topic.ankiDeck!.trim();
      }
    }
    return defaultDeck;
  }

  Future<void> _previewDialog(String title, List<Widget> children) {
    return M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: title,
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        actions: [
          M3EButton.filled(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _statusDialog({required String title, required String message}) {
    return M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: title,
        content: Text(message),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          M3EButton.filled(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(ankiGatewayProvider).openAnkiDroid();
            },
            child: const Text('Open AnkiDroid'),
          ),
        ],
      ),
    );
  }
}

class _SelectAllButton extends StatelessWidget {
  const _SelectAllButton({required this.allSelected, required this.onPressed});

  final bool allSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return M3EButton.text(
      onPressed: onPressed,
      child: Text(allSelected ? 'Clear' : 'Select all'),
    );
  }
}

class _ConceptRow extends StatelessWidget {
  const _ConceptRow({
    required this.concept,
    required this.deckName,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
    this.onComplete,
  });

  final Concept concept;
  final String deckName;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPreview;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final disabled = !concept.isExportable || concept.exportedAt != null;
    return M3ECard(
      variant: M3ECardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Definition of ${concept.term}',
                      style: theme.typography.baseline.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      concept.isExportable
                          ? concept.definition
                          : 'Needs a definition before export.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: concept.isExportable
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${concept.source.name} · ${concept.topicName} · deck: $deckName'
                      '${concept.exportedAt != null ? ' · exported' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onComplete != null)
            M3EButton.text(
              onPressed: onComplete,
              child: const Text('Complete'),
            ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.card,
    required this.deckName,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
    this.onComplete,
  });

  final ErrorCard card;
  final String deckName;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPreview;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final disabled = card.needsDetails || card.exportedAt != null;
    return M3ECard(
      variant: M3ECardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.needsDetails
                          ? 'Needs bias and vaccine before export.'
                          : 'You: ${card.wrongAnswer} · Correct: ${card.correctAnswer}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: card.needsDetails
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.topicName} · deck: $deckName'
                      '${card.isResolved ? ' · resolved' : ''}'
                      '${card.exportedAt != null ? ' · exported' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onComplete != null)
            M3EButton.text(
              onPressed: onComplete,
              child: const Text('Complete'),
            ),
        ],
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({
    required this.card,
    required this.deckName,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
  });

  final ManualCard card;
  final String deckName;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final disabled = card.exportedAt != null;
    return M3ECard(
      variant: M3ECardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.answer,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.topicName} · deck: $deckName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.typography.baseline.bodySmall),
        ],
      ),
    );
  }
}
