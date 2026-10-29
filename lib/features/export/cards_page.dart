import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/error_cards_review_page.dart';
import '../lookup/lookup_actions.dart';
import '../practice/selectable_linkified_text.dart';
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
    final selectedErrorCards = errors
        .where((card) => _selectedErrors.contains(card.id))
        .toList();
    final hasIncompleteSelected = selectedErrorCards.any(
      (card) => card.needsDetails,
    );

    return AppPage(
      title: 'Cards',
      subtitle: selection.total == 0
          ? 'Ready for AnkiDroid'
          : '${selection.total} card${selection.total == 1 ? '' : 's'} selected',
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.info_outline),
          tooltip: 'How cards are exported',
          onPressed: _showInfo,
        ),
      ],
      bottomBar: AppActionDock(
        child: hasIncompleteSelected
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: M3ETheme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Complete the selected error cards before export.',
                          style: M3ETheme.of(context)
                              .typography
                              .baseline
                              .bodySmall
                              .copyWith(
                                color: M3ETheme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppPrimaryButton(
                    onPressed: () => _reviewErrors(selectedErrorCards),
                    label: 'Review selected',
                    icon: Icons.fact_check_outlined,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      onPressed: _busy || selection.total == 0
                          ? null
                          : () => _export(selection),
                      label: _busy ? 'Exporting…' : 'Export to AnkiDroid',
                      icon: Icons.upload_outlined,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AppDockIconButton(
                    icon: Icons.ios_share,
                    tooltip: 'Share as files',
                    onPressed: _busy || selection.total == 0
                        ? null
                        : () => _share(selection),
                  ),
                  AppDockIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete selected',
                    isDestructive: true,
                    onPressed: selection.total == 0 ? null : _deleteSelected,
                  ),
                ],
              ),
      ),
      children: [
        _FilterBar(
          filter: _filter,
          showExported: _showExported,
          onFilter: (value) => setState(() => _filter = value),
          onShowExported: () => setState(() => _showExported = !_showExported),
        ),
        const SizedBox(height: 20),
        if (loading &&
            allConcepts.isEmpty &&
            allErrors.isEmpty &&
            allManuals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          )
        else ...[
          if ((_filter == _Filter.all || _filter == _Filter.concepts) &&
              concepts.isNotEmpty) ...[
            SectionTitle(
              'Concepts',
              count: concepts.length,
              trailing: _SelectAllButton(
                allSelected: concepts
                    .where(
                      (item) => item.isExportable && item.exportedAt == null,
                    )
                    .every((item) => _selectedConcepts.contains(item.id)),
                onPressed: () => setState(() {
                  final selectable = concepts
                      .where(
                        (item) => item.isExportable && item.exportedAt == null,
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
            AppGroup(
              children: [
                for (final concept in concepts)
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
              ],
            ),
            const SizedBox(height: 28),
          ],
          if ((_filter == _Filter.all || _filter == _Filter.errors) &&
              errors.isNotEmpty) ...[
            SectionTitle(
              'Error cards',
              count: errors.length,
              trailing: _SelectAllButton(
                allSelected: errors
                    .where((item) => item.exportedAt == null)
                    .every((item) => _selectedErrors.contains(item.id)),
                onPressed: () => setState(() {
                  final selectable = errors
                      .where((item) => item.exportedAt == null)
                      .map((item) => item.id);
                  if (selectable.every(_selectedErrors.contains)) {
                    _selectedErrors.removeAll(selectable);
                  } else {
                    _selectedErrors.addAll(selectable);
                  }
                }),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                M3EButton.tonal(
                  onPressed: errors.isEmpty
                      ? null
                      : () => _reviewErrors(errors),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Review all'),
                ),
                if (selectedErrorCards.isNotEmpty && !hasIncompleteSelected)
                  M3EButton.filled(
                    onPressed: () => _reviewErrors(selectedErrorCards),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review selected'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppGroup(
              children: [
                for (final card in errors)
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
                        ? () => _reviewErrors([card])
                        : null,
                    onPreview: () => _previewError(card),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if ((_filter == _Filter.all || _filter == _Filter.basic) &&
              manuals.isNotEmpty) ...[
            SectionTitle(
              'Basic cards',
              count: manuals.length,
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
            AppGroup(
              children: [
                for (final card in manuals)
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
              ],
            ),
          ],
          if (!loading && concepts.isEmpty && errors.isEmpty && manuals.isEmpty)
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
      ],
    );
  }

  Future<void> _showInfo() {
    return M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: 'What goes to Anki',
        content: const Text(
          'Concepts become cloze cards, error cards have six fields, and skipped-question cards are basic front/back. '
          'Each topic uses its own deck; topics without one use the default deck from Settings.',
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

  Future<void> _reviewErrors(List<ErrorCard> cards) async {
    if (cards.isEmpty) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ErrorCardsReviewPage(cards: cards),
      ),
    );
  }

  void _defineTerm(String term, Rect? anchor, ErrorCard card) {
    openTermLookup(
      context,
      ref,
      term: term,
      question: card.question,
      topicName: card.topicName,
      practiceName: card.practiceName,
      sessionId: card.sessionId,
      questionId: card.questionId,
      anchor: anchor,
    );
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
    void define(String term, Rect? anchor) => _defineTerm(term, anchor, card);
    void openUrl(String value) => openStudyUrl(context, ref, value);
    return _previewDialog('Error card preview', [
      _PreviewField(label: 'Deck', value: _deckForTopic(card.topicName)),
      _PreviewField(
        label: 'Question',
        value: card.question,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      _PreviewField(
        label: 'Wrong answer',
        value: card.wrongAnswer,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      _PreviewField(
        label: 'Correct answer',
        value: card.correctAnswer,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      _PreviewField(
        label: 'Bias',
        value: card.bias.isEmpty ? '— needs notes —' : card.bias,
      ),
      _PreviewField(
        label: 'Vaccine',
        value: card.vaccine.isEmpty ? '— needs notes —' : card.vaccine,
      ),
      _PreviewField(
        label: 'Explanation',
        value: card.explanation.isEmpty ? '— none —' : card.explanation,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      for (var index = 0; index < card.alternatives.length; index++)
        if (index < card.alternativeExplanations.length &&
            card.alternativeExplanations[index].trim().isNotEmpty)
          _PreviewField(
            label: 'Explanation for ${String.fromCharCode(65 + index)}',
            value: card.alternativeExplanations[index],
            onDefine: define,
            onOpenUrl: openUrl,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.showExported,
    required this.onFilter,
    required this.onShowExported,
  });

  final _Filter filter;
  final bool showExported;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onShowExported;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in const [
          (_Filter.all, 'All'),
          (_Filter.concepts, 'Concepts'),
          (_Filter.errors, 'Errors'),
          (_Filter.basic, 'Basic'),
        ])
          M3EChip(
            type: M3EChipType.filter,
            label: entry.$2,
            selected: filter == entry.$1,
            onPressed: () => onFilter(entry.$1),
          ),
        M3EChip(
          type: M3EChipType.filter,
          label: showExported ? 'Hide exported' : 'Show exported',
          selected: showExported,
          onPressed: onShowExported,
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Definition of ${concept.term}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(concept.topicName),
                        Pill('deck: $deckName'),
                        if (concept.exportedAt != null)
                          const Pill('Exported', tone: PillTone.success),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onComplete != null)
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Complete',
              onPressed: onComplete,
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
    final disabled = card.exportedAt != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(card.topicName),
                        Pill('deck: $deckName'),
                        if (card.isResolved)
                          const Pill('Resolved', tone: PillTone.success),
                        if (card.exportedAt != null) const Pill('Exported'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onComplete != null)
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Complete',
              onPressed: onComplete,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            value: selected,
            onChanged: disabled ? null : (value) => onSelected(value ?? false),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(card.topicName),
                        Pill('deck: $deckName'),
                        if (card.exportedAt != null) const Pill('Exported'),
                      ],
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
  const _PreviewField({
    required this.label,
    required this.value,
    this.onDefine,
    this.onOpenUrl,
  });

  final String label;
  final String value;
  final void Function(String, Rect?)? onDefine;
  final ValueChanged<String>? onOpenUrl;

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
          if (onDefine != null && onOpenUrl != null)
            SelectableLinkifiedText(
              text: value,
              style: theme.typography.baseline.bodySmall.copyWith(height: 1.4),
              onDefine: onDefine!,
              onOpenUrl: onOpenUrl!,
            )
          else
            Text(value, style: theme.typography.baseline.bodySmall),
        ],
      ),
    );
  }
}
