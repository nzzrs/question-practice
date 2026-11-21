import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/data/settings_repository.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/error_cards_review_page.dart';
import '../lookup/lookup_actions.dart';
import '../practice/selectable_linkified_text.dart';
import '../review/note_review_page.dart';
import '../review/skipped_question_view.dart';
import 'domain/anki_note_builder.dart';

enum _Filter { all, cards, errors, notes }

class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  final _selectedConcepts = <int>{};
  final _selectedErrors = <int>{};
  final _selectedBasic = <int>{};
  final _selectedSkipped = <int>{};
  final _selectedNotes = <int>{};
  bool _selectionActive = false;
  bool _restoreStarted = false;
  bool _restored = false;
  int _selectionRevision = 0;
  bool _pruneScheduled = false;
  bool _busy = false;
  bool _showExported = false;
  _Filter _filter = _Filter.all;

  bool get _hasSelection =>
      _selectedConcepts.isNotEmpty ||
      _selectedErrors.isNotEmpty ||
      _selectedBasic.isNotEmpty ||
      _selectedSkipped.isNotEmpty ||
      _selectedNotes.isNotEmpty;

  void _clearSelection() {
    setState(() {
      _selectionActive = false;
      _selectedConcepts.clear();
      _selectedErrors.clear();
      _selectedBasic.clear();
      _selectedSkipped.clear();
      _selectedNotes.clear();
    });
    _persistSelection();
  }

  /// Long-press: enter selection mode with the pressed row selected.
  void _startSelection(Set<int> selection, int id) {
    setState(() {
      _selectionActive = true;
      selection.add(id);
    });
    _persistSelection();
  }

  /// Tap while selection mode is active: toggle this row without moving others.
  void _toggleSelection(Set<int> selection, int id) {
    setState(() {
      if (!selection.remove(id)) selection.add(id);
      if (!_hasSelection) _selectionActive = false;
    });
    _persistSelection();
  }

  void _handleRowTap(
    Set<int> selection,
    int id,
    VoidCallback preview, {
    bool selectable = true,
  }) {
    if (_selectionActive) {
      if (selectable) _toggleSelection(selection, id);
      return;
    }
    preview();
  }

  void _handleRowLongPress(
    Set<int> selection,
    int id, {
    bool selectable = true,
  }) {
    if (selectable) _startSelection(selection, id);
  }

  ExportSelection _selection({
    required List<Concept> concepts,
    required List<ManualCard> manuals,
  }) {
    return ExportSelection(
      concepts: concepts
          .where(
            (item) =>
                item.isExportable &&
                item.exportedAt == null &&
                _selectedConcepts.contains(item.id),
          )
          .toList(),
      manualCards: manuals
          .where(
            (item) =>
                item.exportedAt == null && _selectedBasic.contains(item.id),
          )
          .toList(),
    );
  }

  CardsSelection get _currentSelection {
    return CardsSelection(
      concepts: Set.of(_selectedConcepts),
      basic: Set.of(_selectedBasic),
      errors: Set.of(_selectedErrors),
      skipped: Set.of(_selectedSkipped),
      notes: Set.of(_selectedNotes),
    );
  }

  void _replaceSelection(CardsSelection selection) {
    _selectedConcepts
      ..clear()
      ..addAll(selection.concepts);
    _selectedBasic
      ..clear()
      ..addAll(selection.basic);
    _selectedErrors
      ..clear()
      ..addAll(selection.errors);
    _selectedSkipped
      ..clear()
      ..addAll(selection.skipped);
    _selectedNotes
      ..clear()
      ..addAll(selection.notes);
    if (!_hasSelection) _selectionActive = false;
  }

  void _persistSelection() {
    _selectionRevision++;
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .saveCardsSelection(_currentSelection),
    );
  }

  /// Drops ids that no longer match a selectable loaded row.
  CardsSelection _validSelection(
    CardsSelection selection, {
    required Set<int> concepts,
    required Set<int> basic,
    required Set<int> errors,
    required Set<int> skipped,
    required Set<int> notes,
  }) {
    return CardsSelection(
      concepts: selection.concepts.intersection(concepts),
      basic: selection.basic.intersection(basic),
      errors: selection.errors.intersection(errors),
      skipped: selection.skipped.intersection(skipped),
      notes: selection.notes.intersection(notes),
    );
  }

  Future<void> _restoreSelection({
    required Set<int> concepts,
    required Set<int> basic,
    required Set<int> errors,
    required Set<int> skipped,
    required Set<int> notes,
  }) async {
    final revision = _selectionRevision;
    final stored = await ref
        .read(settingsRepositoryProvider)
        .loadCardsSelection();
    if (!mounted) return;
    if (revision != _selectionRevision) {
      // The learner acted while the stored selection loaded. Their fresh
      // selection wins, and overwriting the key drops the stale value.
      setState(() => _restored = true);
      _persistSelection();
      return;
    }
    final valid = _validSelection(
      stored ?? CardsSelection.empty,
      concepts: concepts,
      basic: basic,
      errors: errors,
      skipped: skipped,
      notes: notes,
    );
    setState(() {
      _replaceSelection(valid);
      _selectionActive = _hasSelection;
      _restored = true;
    });
    if (stored != null && stored != valid) {
      await ref.read(settingsRepositoryProvider).saveCardsSelection(valid);
    }
  }

  /// Removes rows that were exported or deleted while the page was open.
  ///
  /// The page can receive new stream values without a user action, so repair
  /// runs after the frame and never mutates state during build.
  void _scheduleStalePrune({
    required Set<int> concepts,
    required Set<int> basic,
    required Set<int> errors,
    required Set<int> skipped,
    required Set<int> notes,
  }) {
    if (!_restored || _pruneScheduled) return;
    final current = _currentSelection;
    final valid = _validSelection(
      current,
      concepts: concepts,
      basic: basic,
      errors: errors,
      skipped: skipped,
      notes: notes,
    );
    if (current == valid) return;
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruneScheduled = false;
      if (!mounted) return;
      final latest = _currentSelection;
      final pruned = _validSelection(
        latest,
        concepts: concepts,
        basic: basic,
        errors: errors,
        skipped: skipped,
        notes: notes,
      );
      if (latest == pruned) return;
      setState(() => _replaceSelection(pruned));
      _persistSelection();
    });
  }

  void _toggleIds(Set<int> selection, Iterable<int> ids) {
    final values = ids.toList();
    if (values.isEmpty) return;
    setState(() {
      if (values.every(selection.contains)) {
        selection.removeAll(values);
      } else {
        selection.addAll(values);
        _selectionActive = true;
      }
      if (!_hasSelection) _selectionActive = false;
    });
    _persistSelection();
  }

  void _toggleErrorIds(Iterable<int> errors, Iterable<int> skipped) {
    final errorIds = errors.toList();
    final skippedIds = skipped.toList();
    if (errorIds.isEmpty && skippedIds.isEmpty) return;
    final allSelected =
        errorIds.every(_selectedErrors.contains) &&
        skippedIds.every(_selectedSkipped.contains);
    setState(() {
      if (allSelected) {
        _selectedErrors.removeAll(errorIds);
        _selectedSkipped.removeAll(skippedIds);
      } else {
        _selectedErrors.addAll(errorIds);
        _selectedSkipped.addAll(skippedIds);
        _selectionActive = true;
      }
      if (!_hasSelection) _selectionActive = false;
    });
    _persistSelection();
  }

  void _toggleVisibleSelection(List<(Set<int>, List<int>)> groups) {
    final entries = [
      for (final group in groups)
        if (group.$2.isNotEmpty) group,
    ];
    if (entries.isEmpty) return;
    final allSelected = entries.every(
      (group) => group.$2.every(group.$1.contains),
    );
    setState(() {
      for (final (selection, ids) in entries) {
        if (allSelected) {
          selection.removeAll(ids);
        } else {
          selection.addAll(ids);
        }
      }
      _selectionActive = _hasSelection;
    });
    _persistSelection();
  }

  @override
  Widget build(BuildContext context) {
    final conceptsAsync = ref.watch(allConceptsProvider);
    final errorsAsync = ref.watch(allErrorCardsProvider);
    final manualsAsync = ref.watch(allManualCardsProvider);
    final skippedAsync = ref.watch(skippedQuestionsProvider);
    final notesAsync = ref.watch(notesProvider);
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
    final skipped = skippedAsync.value ?? const <SkippedQuestion>[];
    final notes = notesAsync.value ?? const <Note>[];
    final concepts = _showExported
        ? allConcepts
        : allConcepts.where((item) => item.exportedAt == null).toList();
    final errors = _showExported
        ? allErrors
        : allErrors.where((item) => item.exportedAt == null).toList();
    final manuals = _showExported
        ? allManuals
        : allManuals.where((item) => item.exportedAt == null).toList();

    final showCards = _filter == _Filter.all || _filter == _Filter.cards;
    final showErrors = _filter == _Filter.all || _filter == _Filter.errors;
    final showNotes = _filter == _Filter.all || _filter == _Filter.notes;
    final visibleManuals = manuals;

    final selectableConceptIds = {
      for (final item in allConcepts)
        if (item.isExportable && item.exportedAt == null) item.id,
    };
    final selectableBasicIds = {
      for (final item in allManuals)
        if (item.exportedAt == null) item.id,
    };
    final selectableErrorIds = {
      for (final item in allErrors)
        if (item.exportedAt == null) item.id,
    };
    final selectableSkippedIds = {for (final item in skipped) item.id};
    final selectableNoteIds = {for (final item in notes) item.id};

    if (!_restoreStarted &&
        conceptsAsync.hasValue &&
        errorsAsync.hasValue &&
        manualsAsync.hasValue &&
        skippedAsync.hasValue &&
        notesAsync.hasValue) {
      _restoreStarted = true;
      unawaited(
        _restoreSelection(
          concepts: selectableConceptIds,
          basic: selectableBasicIds,
          errors: selectableErrorIds,
          skipped: selectableSkippedIds,
          notes: selectableNoteIds,
        ),
      );
    }

    if (_restored) {
      _scheduleStalePrune(
        concepts: selectableConceptIds,
        basic: selectableBasicIds,
        errors: selectableErrorIds,
        skipped: selectableSkippedIds,
        notes: selectableNoteIds,
      );
    }

    final selection = _selection(concepts: concepts, manuals: manuals);
    final loading =
        conceptsAsync.isLoading ||
        errorsAsync.isLoading ||
        manualsAsync.isLoading ||
        skippedAsync.isLoading ||
        notesAsync.isLoading;
    final selectedErrorCards = errors
        .where((card) => _selectedErrors.contains(card.id))
        .toList();
    final selectedSkipped = skipped
        .where((question) => _selectedSkipped.contains(question.id))
        .toList();
    final selectedNotes = notes
        .where((note) => _selectedNotes.contains(note.id))
        .toList();
    final pendingSelectedErrors = selectedErrorCards
        .where((card) => card.needsDetails)
        .toList();
    final selectedPendingCount =
        pendingSelectedErrors.length + selectedSkipped.length;
    final allPendingErrors = allErrors
        .where((card) => card.needsDetails && card.exportedAt == null)
        .toList();
    final globalPendingCount = allPendingErrors.length + skipped.length;
    final selectedCount =
        selection.total +
        selectedErrorCards.length +
        selectedSkipped.length +
        selectedNotes.length;

    final conceptSelectableIds = [
      for (final item in concepts)
        if (item.isExportable && item.exportedAt == null) item.id,
    ];
    final basicSelectableIds = [
      for (final item in visibleManuals)
        if (item.exportedAt == null) item.id,
    ];
    final errorSelectableIds = [
      for (final item in errors)
        if (item.exportedAt == null) item.id,
    ];
    final skippedSelectableIds = [for (final item in skipped) item.id];
    final noteSelectableIds = [for (final item in notes) item.id];
    final visibleGroups = <(Set<int>, List<int>)>[
      if (showCards) (_selectedConcepts, conceptSelectableIds),
      if (showCards) (_selectedBasic, basicSelectableIds),
      if (showErrors) (_selectedErrors, errorSelectableIds),
      if (showErrors) (_selectedSkipped, skippedSelectableIds),
      if (showNotes) (_selectedNotes, noteSelectableIds),
    ];
    final visibleEntryCount = visibleGroups.fold<int>(
      0,
      (count, group) => count + group.$2.length,
    );
    final allVisibleSelected =
        visibleEntryCount > 0 &&
        visibleGroups.every((group) => group.$2.every(group.$1.contains));

    final hasVisibleRows =
        (showCards && (concepts.isNotEmpty || visibleManuals.isNotEmpty)) ||
        (showErrors && (errors.isNotEmpty || skipped.isNotEmpty)) ||
        (showNotes && notes.isNotEmpty);
    final hasAnyRows =
        concepts.isNotEmpty ||
        errors.isNotEmpty ||
        manuals.isNotEmpty ||
        skipped.isNotEmpty ||
        notes.isNotEmpty;
    final subtitle = selectedCount == 0
        ? 'Ready for AnkiDroid'
        : selectedPendingCount > 0
        ? '$selectedCount selected · review to export'
        : '$selectedCount selected';

    final reviewPendingLabel = selectedPendingCount > 0;
    final exportReady = selection.total > 0;
    final primaryLabel = _busy
        ? 'Exporting…'
        : reviewPendingLabel
        ? 'Review pending'
        : 'Export to AnkiDroid';
    final VoidCallback? primaryAction = _busy
        ? null
        : reviewPendingLabel
        ? () => _reviewCards(pendingSelectedErrors, selectedSkipped)
        : exportReady
        ? () => _export(selection)
        : null;

    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return AppPage(
      title: 'Cards',
      subtitle: largeText ? null : subtitle,
      showBack: true,
      variant: largeText
          ? M3EAppBarVariant.small
          : M3EAppBarVariant.largeFlexible,
      actions: [
        if (_selectionActive)
          M3EIconButton(
            key: const ValueKey('clear-selection'),
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.close),
            tooltip: 'Clear selection',
            onPressed: _clearSelection,
          ),
        if (globalPendingCount > 0)
          M3EIconButton(
            key: const ValueKey('review-all-pending'),
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: 'Review all pending',
            semanticLabel: 'Review all pending cards',
            onPressed: () => _reviewCards(allPendingErrors, skipped),
          ),
        if (!largeText)
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.info_outline),
            tooltip: 'How cards are exported',
            onPressed: _showInfo,
          ),
        M3EIconButton(
          key: const ValueKey('select-all'),
          variant: M3EIconButtonVariant.standard,
          icon: Icon(allVisibleSelected ? Icons.deselect : Icons.select_all),
          tooltip: allVisibleSelected ? 'Deselect all' : 'Select all',
          semanticLabel: allVisibleSelected
              ? 'Deselect all visible items'
              : 'Select all visible items',
          onPressed: visibleEntryCount == 0
              ? null
              : () => _toggleVisibleSelection(visibleGroups),
        ),
      ],
      bottomBar: AppActionDock(
        child: Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                onPressed: primaryAction,
                label: primaryLabel,
                icon: reviewPendingLabel
                    ? Icons.fact_check_outlined
                    : Icons.upload_outlined,
              ),
            ),
            const SizedBox(width: 6),
            AppDockIconButton(
              icon: Icons.ios_share,
              tooltip: 'Share as files',
              onPressed: _busy || !exportReady ? null : () => _share(selection),
            ),
            AppDockIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete selected',
              isDestructive: true,
              onPressed: selectedCount == 0 ? null : _deleteSelected,
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
        if (largeText) ...[
          Text(
            subtitle,
            key: const ValueKey('cards-status'),
            style: M3ETheme.of(context).typography.baseline.labelLarge.copyWith(
              color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (loading &&
            allConcepts.isEmpty &&
            allErrors.isEmpty &&
            allManuals.isEmpty &&
            skipped.isEmpty &&
            notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          )
        else ...[
          if (showCards && concepts.isNotEmpty) ...[
            SectionTitle(
              'Concepts',
              count: concepts.length,
              trailing: _SectionSelectAll(
                key: const ValueKey('concepts-select-all'),
                label: 'concepts',
                allSelected:
                    conceptSelectableIds.isNotEmpty &&
                    conceptSelectableIds.every(_selectedConcepts.contains),
                onPressed: conceptSelectableIds.isEmpty
                    ? null
                    : () => _toggleIds(_selectedConcepts, conceptSelectableIds),
              ),
            ),
            AppGroup(
              children: [
                for (final concept in concepts)
                  _ConceptRow(
                    key: ValueKey('concept-row-${concept.id}'),
                    concept: concept,
                    deckName: deckFor(concept.topicName),
                    selected: _selectedConcepts.contains(concept.id),
                    onTap: () => _handleRowTap(
                      _selectedConcepts,
                      concept.id,
                      () => _previewConcept(concept),
                      selectable:
                          concept.isExportable && concept.exportedAt == null,
                    ),
                    onLongPress: () => _handleRowLongPress(
                      _selectedConcepts,
                      concept.id,
                      selectable:
                          concept.isExportable && concept.exportedAt == null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (showErrors && (errors.isNotEmpty || skipped.isNotEmpty)) ...[
            SectionTitle(
              'Error and skipped',
              count: errors.length + skipped.length,
              trailing: _SectionSelectAll(
                key: const ValueKey('errors-select-all'),
                label: 'error and skipped items',
                allSelected:
                    (errorSelectableIds.isNotEmpty ||
                        skippedSelectableIds.isNotEmpty) &&
                    errorSelectableIds.every(_selectedErrors.contains) &&
                    skippedSelectableIds.every(_selectedSkipped.contains),
                onPressed:
                    errorSelectableIds.isEmpty && skippedSelectableIds.isEmpty
                    ? null
                    : () => _toggleErrorIds(
                        errorSelectableIds,
                        skippedSelectableIds,
                      ),
              ),
            ),
            AppGroup(
              children: [
                for (final card in errors)
                  _ErrorRow(
                    key: ValueKey('error-row-${card.id}'),
                    card: card,
                    deckName: deckFor(card.topicName),
                    selected: _selectedErrors.contains(card.id),
                    onTap: () => _handleRowTap(
                      _selectedErrors,
                      card.id,
                      () => _previewError(card),
                      selectable: card.exportedAt == null,
                    ),
                    onLongPress: () => _handleRowLongPress(
                      _selectedErrors,
                      card.id,
                      selectable: card.exportedAt == null,
                    ),
                  ),
                for (final question in skipped)
                  _SkippedRow(
                    key: ValueKey('skipped-row-${question.id}'),
                    question: question,
                    selected: _selectedSkipped.contains(question.id),
                    onTap: () => _handleRowTap(
                      _selectedSkipped,
                      question.id,
                      () => _previewSkipped(question),
                    ),
                    onLongPress: () =>
                        _handleRowLongPress(_selectedSkipped, question.id),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (showCards && visibleManuals.isNotEmpty) ...[
            SectionTitle(
              'Basic cards',
              count: visibleManuals.length,
              trailing: _SectionSelectAll(
                key: const ValueKey('basic-select-all'),
                label: 'basic cards',
                allSelected:
                    basicSelectableIds.isNotEmpty &&
                    basicSelectableIds.every(_selectedBasic.contains),
                onPressed: basicSelectableIds.isEmpty
                    ? null
                    : () => _toggleIds(_selectedBasic, basicSelectableIds),
              ),
            ),
            AppGroup(
              children: [
                for (final card in visibleManuals)
                  _ManualRow(
                    key: ValueKey('basic-row-${card.id}'),
                    card: card,
                    deckName: deckFor(card.topicName),
                    selected: _selectedBasic.contains(card.id),
                    onTap: () => _handleRowTap(
                      _selectedBasic,
                      card.id,
                      () => _previewManual(card),
                      selectable: card.exportedAt == null,
                    ),
                    onLongPress: () => _handleRowLongPress(
                      _selectedBasic,
                      card.id,
                      selectable: card.exportedAt == null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (showNotes && notes.isNotEmpty) ...[
            SectionTitle(
              'Notes',
              count: notes.length,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  M3EIconButton(
                    key: const ValueKey('notes-download'),
                    variant: M3EIconButtonVariant.standard,
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Download all notes',
                    onPressed: _busy ? null : () => _downloadNotes(notes),
                  ),
                  const SizedBox(width: 4),
                  _SectionSelectAll(
                    key: const ValueKey('notes-select-all'),
                    label: 'notes',
                    allSelected:
                        noteSelectableIds.isNotEmpty &&
                        noteSelectableIds.every(_selectedNotes.contains),
                    onPressed: () =>
                        _toggleIds(_selectedNotes, noteSelectableIds),
                  ),
                ],
              ),
            ),
            AppGroup(
              children: [
                for (final note in notes)
                  _NoteRow(
                    key: ValueKey('note-row-${note.id}'),
                    note: note,
                    selected: _selectedNotes.contains(note.id),
                    onTap: () => _handleRowTap(
                      _selectedNotes,
                      note.id,
                      () => _reviewNotes(notes, initialNoteId: note.id),
                    ),
                    onLongPress: () =>
                        _handleRowLongPress(_selectedNotes, note.id),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (!loading && !hasAnyRows)
            const EmptyState(
              icon: Icons.style_outlined,
              title: 'No cards yet',
              message: 'Review a session to save cards, or define a term.',
            )
          else if (!loading && !hasVisibleRows)
            const EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Nothing in this filter',
              message: 'Choose All to see every card again.',
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
          'Concepts become Anki Cloze cards. Facts, heuristics and contrasts '
          'become Anki Basic cards with a front and a back. '
          'Cards carry question-practice, topic::<topic> and '
          'subtopic::<subtopic> tags. '
          'Tags travel in the third column. Map it to Tags when importing. '
          'Topic and subtopic are never written inside card text. '
          'Errors are not exported directly: Create cards turns them into '
          'atomic cards, by hand or with optional AI suggestions. Skipped '
          'questions stay in Cards until you create cards from them. '
          'Notes are never sent to AnkiDroid; use the download action in the '
          'Notes header to save them as plain text. '
          'Each topic uses its own deck; topics without one use the default '
          'deck from Settings.',
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
          message: 'In AnkiDroid, open Settings → Advanced, and enable the AnkiDroid API. Then try again.',
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
          message: 'AnkiDroid has no Cloze note type. Create one in AnkiDroid, then retry. The Basic note type is created automatically.',
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
          _selectedConcepts.removeAll(
            selection.concepts.map((concept) => concept.id),
          );
          _selectedBasic.removeAll(
            selection.manualCards.map((card) => card.id),
          );
          if (!_hasSelection) _selectionActive = false;
        });
        _persistSelection();
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
      message:
          'Concepts, facts, heuristics and contrasts are removed permanently. Deleting an '
          'active error card also removes it from the 48-hour review queue. '
          'Skipped questions are removed from the skipped queue; their '
          'questions stay in the practice. Notes are removed from this '
          'list; cards already made from them stay.',
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
          skippedQuestionIds: _selectedSkipped.toList(),
          noteIds: _selectedNotes.toList(),
        );
    setState(() {
      _selectionActive = false;
      _selectedConcepts.clear();
      _selectedErrors.clear();
      _selectedBasic.clear();
      _selectedSkipped.clear();
      _selectedNotes.clear();
    });
    _persistSelection();
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
      _persistSelection();
    }
    controller.dispose();
  }

  Future<void> _reviewCards(
    List<ErrorCard> cards,
    List<SkippedQuestion> skipped,
  ) async {
    if (cards.isEmpty && skipped.isEmpty) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) =>
            ErrorCardsReviewPage(cards: cards, skippedQuestions: skipped),
      ),
    );
    if (!mounted || completed != true) return;
    setState(() {
      _selectedErrors.removeAll(cards.map((card) => card.id));
      _selectedSkipped.removeAll(skipped.map((question) => question.id));
      if (!_hasSelection) _selectionActive = false;
    });
    _persistSelection();
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
      subtopic: card.subtopic,
      anchor: anchor,
    );
  }

  Future<void> _previewConcept(Concept concept) {
    return _previewDialog('Concept preview', [
      _previewMeta([
        const Pill('Concept', tone: PillTone.primary),
        Pill(concept.topicName),
        if (concept.subtopic.trim().isNotEmpty)
          Pill('subtopic: ${concept.subtopic.trim()}'),
        Pill(
          'deck: ${_deckForTopic(concept.topicName)}',
          tone: PillTone.primary,
        ),
        Pill(concept.source.name),
      ]),
      const SizedBox(height: 14),
      TonalBox(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PreviewLabel('Definition of'),
            const SizedBox(height: 3),
            Text(
              concept.term,
              style: M3ETheme.of(context).typography.emphasized.headlineSmall
                  .copyWith(color: M3ETheme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 10),
            Text(
              concept.definition.isEmpty
                  ? 'Needs a definition before export.'
                  : concept.definition,
              style: M3ETheme.of(context).typography.baseline.bodyMedium
                  .copyWith(height: 1.45),
            ),
          ],
        ),
      ),
      if (concept.extra.isNotEmpty) ...[
        const SizedBox(height: 10),
        _PreviewNote(label: 'Stands for', text: concept.extra),
      ],
      const SizedBox(height: 10),
      _PreviewNote(
        label: 'Anki note',
        text: 'Cloze card · ${concept.source.name}',
      ),
    ], onComplete: concept.isExportable ? null : () => _editConcept(concept));
  }

  Future<void> _previewError(ErrorCard card) {
    void define(String term, Rect? anchor) => _defineTerm(term, anchor, card);
    void openUrl(String value) => openStudyUrl(context, ref, value);
    return _previewDialog('Error preview', [
      _previewMeta([
        Pill(card.topicName),
        Pill('deck: ${_deckForTopic(card.topicName)}', tone: PillTone.primary),
        Pill(
          card.needsDetails ? 'Needs review' : 'Reviewed',
          tone: card.needsDetails ? PillTone.error : PillTone.success,
        ),
      ]),
      const SizedBox(height: 14),
      TonalBox(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PreviewLabel('Question'),
            const SizedBox(height: 4),
            SelectableLinkifiedText(
              text: card.question,
              style: M3ETheme.of(context).typography.baseline.titleMedium
                  .copyWith(height: 1.35),
              onDefine: define,
              onOpenUrl: openUrl,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _PreviewAnswer(
        label: 'Wrong answer chosen',
        value: card.wrongAnswer,
        tone: _PreviewTone.error,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      const SizedBox(height: 8),
      _PreviewAnswer(
        label: 'Right answer discarded',
        value: card.correctAnswer,
        tone: _PreviewTone.success,
        onDefine: define,
        onOpenUrl: openUrl,
      ),
      if (card.reasoning.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        _PreviewNote(label: 'Your reasoning', text: card.reasoning),
      ],
      if (card.explanation.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        _PreviewNote(label: 'Why this answer', text: card.explanation),
      ],
    ], onReview: () => _reviewCards([card], const []));
  }

  Future<void> _previewSkipped(SkippedQuestion question) {
    return _previewDialog('Skipped question preview', [
      _previewMeta([
        Pill(question.topicName),
        Pill(
          'deck: ${_deckForTopic(question.topicName)}',
          tone: PillTone.primary,
        ),
        Pill(
          question.unknown ? "I didn't know this" : 'Skipped',
          tone: question.unknown ? PillTone.secondary : PillTone.neutral,
        ),
      ]),
      const SizedBox(height: 14),
      SkippedQuestionView(
        prompt: question.question,
        alternatives: question.alternatives,
        correctIndexes: question.correctIndexes,
        alternativeExplanations: question.alternativeExplanations,
        explanation: question.explanation,
        reasoning: question.reasoning,
        unknown: question.unknown,
        showStatus: false,
      ),
    ], onReview: () => _reviewCards(const [], [question]));
  }

  Widget _previewMeta(List<Widget> children) {
    return Wrap(spacing: 6, runSpacing: 4, children: children);
  }

  Future<void> _reviewNotes(List<Note> notes, {int? initialNoteId}) async {
    if (notes.isEmpty) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) =>
            NoteReviewPage(notes: notes, initialNoteId: initialNoteId),
      ),
    );
  }

  Future<void> _downloadNotes(List<Note> notes) async {
    setState(() => _busy = true);
    try {
      await ref.read(exportServiceProvider).shareNotes(notes);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not share notes: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewManual(ManualCard card) {
    return _previewDialog('Card preview', [
      _previewMeta([
        Pill(card.cognitiveType.label, tone: PillTone.secondary),
        Pill(card.topicName),
        if (card.subtopic.trim().isNotEmpty)
          Pill('subtopic: ${card.subtopic.trim()}'),
        Pill('deck: ${_deckForTopic(card.topicName)}', tone: PillTone.primary),
      ]),
      const SizedBox(height: 14),
      if (card.context.trim().isNotEmpty) ...[
        _PreviewContext(text: card.context),
        const SizedBox(height: 10),
      ],
      TonalBox(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PreviewLabel('Front'),
            const SizedBox(height: 4),
            Text(
              card.question,
              style: M3ETheme.of(context).typography.baseline.titleMedium
                  .copyWith(height: 1.35),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _PreviewAnswer(
        label: 'Back',
        value: card.answer,
        tone: _PreviewTone.success,
      ),
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

  Future<void> _previewDialog(
    String title,
    List<Widget> children, {
    VoidCallback? onReview,
    VoidCallback? onComplete,
  }) {
    M3EButton action(String label, VoidCallback callback) {
      return M3EButton.filled(
        onPressed: () => _closeDialogThen(callback),
        child: Text(label),
      );
    }

    final hasExtraAction = onReview != null || onComplete != null;
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
          if (hasExtraAction)
            M3EButton.text(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          else
            M3EButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          if (onComplete != null) action('Complete', onComplete),
          if (onReview != null) action('Review', onReview),
        ],
      ),
    );
  }

  void _closeDialogThen(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
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
            child: const Text('Open in AnkiDroid'),
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
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('cards-filter-bar'),
            scrollDirection: Axis.horizontal,
            child: M3EChipGroup(
              groupLabel: 'Card filters',
              child: Row(
                children: [
                  for (final entry in const [
                    (_Filter.all, 'All', 'all'),
                    (_Filter.cards, 'Cards', 'cards'),
                    (_Filter.errors, 'Errors', 'errors'),
                    (_Filter.notes, 'Notes', 'notes'),
                  ]) ...[
                    M3EChip(
                      key: ValueKey('cards-filter-${entry.$3}'),
                      type: M3EChipType.filter,
                      label: entry.$2,
                      selected: filter == entry.$1,
                      onPressed: () => onFilter(entry.$1),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
        M3EIconButton(
          key: const ValueKey('cards-filter-show-exported'),
          variant: showExported
              ? M3EIconButtonVariant.filled
              : M3EIconButtonVariant.standard,
          icon: Icon(
            showExported ? Icons.visibility : Icons.visibility_off_outlined,
          ),
          tooltip: showExported ? 'Hide exported' : 'Show exported',
          semanticLabel: showExported
              ? 'Hide exported cards'
              : 'Show exported cards',
          onPressed: onShowExported,
        ),
      ],
    );
  }
}

class _SectionSelectAll extends StatelessWidget {
  const _SectionSelectAll({
    required this.label,
    required this.allSelected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool allSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = allSelected ? 'Clear' : 'Select all';
    return M3EIconButton(
      variant: M3EIconButtonVariant.standard,
      icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
      tooltip: '$action $label',
      semanticLabel: '$action $label',
      onPressed: onPressed,
    );
  }
}

/// One tappable row in Cards.
///
/// Selection is shown with a tint and a fixed-size trailing mark, never a
/// checkbox. Long-press enters selection mode; a tap either previews the row or
/// toggles its selection, depending on [CardsPage] state. Nothing here changes
/// size when [selected] flips, so the list never shifts when more rows are
/// selected.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.09)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: child),
              const SizedBox(width: 8),
              _SelectionMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed-size selection state. The box keeps its size while unselected so the
/// row never reflows when selection starts.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: selected
          ? Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary)
          : null,
    );
  }
}

class _ConceptRow extends StatelessWidget {
  const _ConceptRow({
    required this.concept,
    required this.deckName,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final Concept concept;
  final String deckName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return _SelectableRow(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
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
          if (concept.extra.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Stands for: ${concept.extra}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              const Pill('Concept', tone: PillTone.primary),
              Pill(concept.topicName),
              if (concept.subtopic.trim().isNotEmpty)
                Pill('subtopic: ${concept.subtopic.trim()}'),
              Pill('deck: $deckName'),
              if (concept.exportedAt != null)
                const Pill('Exported', tone: PillTone.success),
            ],
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
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final ErrorCard card;
  final String deckName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return _SelectableRow(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
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
                ? 'Needs review. Create cards to export.'
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
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({
    required this.card,
    required this.deckName,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final ManualCard card;
  final String deckName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return _SelectableRow(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
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
              Pill(card.cognitiveType.label, tone: PillTone.secondary),
              Pill(card.topicName),
              if (card.subtopic.trim().isNotEmpty)
                Pill('subtopic: ${card.subtopic.trim()}'),
              Pill('deck: $deckName'),
              if (card.exportedAt != null) const Pill('Exported'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return _SelectableRow(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              note.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.titleSmall.copyWith(
                height: 1.35,
              ),
            ),
          ),
          if (note.context.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              note.context,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              const Pill('Note', tone: PillTone.primary),
              if (note.topicName.trim().isNotEmpty) Pill(note.topicName),
              if (note.isKept) const Pill('Kept', tone: PillTone.success),
              if (note.hasCard) const Pill('Card made', tone: PillTone.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkippedRow extends StatelessWidget {
  const _SkippedRow({
    required this.question,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final SkippedQuestion question;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return _SelectableRow(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Correct: ${question.correctAnswer}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: AppSuccess.foreground(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (question.reasoning.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'You: ${question.reasoning}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Pill(
                question.unknown ? "I didn't know this" : 'Skipped',
                tone: question.unknown ? PillTone.secondary : PillTone.neutral,
              ),
              if (question.topicName.trim().isNotEmpty)
                Pill(question.topicName),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PreviewTone { neutral, success, error }

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.typography.baseline.labelSmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PreviewAnswer extends StatelessWidget {
  const _PreviewAnswer({
    required this.label,
    required this.value,
    required this.tone,
    this.onDefine,
    this.onOpenUrl,
  });

  final String label;
  final String value;
  final _PreviewTone tone;
  final void Function(String, Rect?)? onDefine;
  final ValueChanged<String>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final (container, foreground) = switch (tone) {
      _PreviewTone.success => (
        AppSuccess.container(context),
        AppSuccess.onContainer(context),
      ),
      _PreviewTone.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _PreviewTone.neutral => (
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurface,
      ),
    };
    final icon = switch (tone) {
      _PreviewTone.success => Icons.check_circle_outline,
      _PreviewTone.error => Icons.cancel_outlined,
      _PreviewTone.neutral => Icons.notes_outlined,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: foreground.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                if (onDefine != null && onOpenUrl != null)
                  SelectableLinkifiedText(
                    text: value,
                    style: theme.typography.baseline.bodyMedium.copyWith(
                      color: foreground,
                      height: 1.4,
                    ),
                    onDefine: onDefine!,
                    onOpenUrl: onOpenUrl!,
                  )
                else
                  Text(
                    value,
                    style: theme.typography.baseline.bodyMedium.copyWith(
                      color: foreground,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewNote extends StatelessWidget {
  const _PreviewNote({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewLabel(label),
          const SizedBox(height: 3),
          Text(
            text,
            style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PreviewContext extends StatelessWidget {
  const _PreviewContext({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewLabel('Context'),
          const SizedBox(height: 3),
          Text(
            text,
            style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
