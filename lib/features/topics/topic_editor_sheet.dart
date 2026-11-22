import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../import/domain/import_models.dart';
import 'anki_deck_picker.dart';
import 'domain/topic_edit_service.dart';
import 'domain/topic_update_copy.dart';
import 'topic_update_preview_page.dart';

/// The editable field a topic editor tile expands.
enum _TopicField {
  name,
  description,
  priority,
  minimumScore,
  targetScore,
  deck,
}

/// Tracks the editor state the hosting route needs to allow or block closing.
///
/// The sheet owns validation, saving and closing; the route only asks
/// [requestClose] and reads [saved] after the sheet has gone.
class TopicEditorSheetGuard {
  bool _dirty = false;
  bool _saving = false;
  bool _saved = false;
  Future<bool> Function()? _onCloseRequested;

  /// Whether a field differs from the last saved value.
  bool get dirty => _dirty;

  /// Whether a write is in flight.
  bool get saving => _saving;

  /// Whether this sheet successfully saved at least once.
  bool get saved => _saved;

  void update({
    required bool dirty,
    required bool saving,
    required bool saved,
  }) {
    _dirty = dirty;
    _saving = saving;
    _saved = saved;
  }

  /// Registers the sheet's close handler.
  void bindCloseHandler(Future<bool> Function() handler) {
    _onCloseRequested = handler;
  }

  /// Drops the handler when the sheet is disposed.
  void releaseCloseHandler() {
    _onCloseRequested = null;
  }

  /// Validates and flushes pending edits. Resolves true to let the route pop.
  Future<bool> requestClose() {
    final handler = _onCloseRequested;
    if (handler == null) return Future<bool>.value(!_dirty && !_saving);
    return handler();
  }
}

/// Bottom-sheet editor for a topic's name, description, priority and deck.
///
/// The sheet is one continuous form of option-style tiles, with no section
/// headings or guidance paragraphs. Tapping a tile expands its inline editor
/// in place, matching the long-press topic and practice menus. It re-reads the
/// topic by id when it opens: a caller may hold a summary from before a backup
/// restore or another database replacement, and saving that stale snapshot
/// back would silently clear newer fields.
///
/// There is no Save button. Valid edits auto-save after a short debounce and
/// are flushed on focus loss and close. Invalid values are never written;
/// closing with an invalid name or score keeps the sheet open and reveals the
/// first field that needs attention.
class TopicEditorSheet extends ConsumerStatefulWidget {
  const TopicEditorSheet({required this.topic, required this.guard, super.key});

  final Topic topic;
  final TopicEditorSheetGuard guard;

  @override
  ConsumerState<TopicEditorSheet> createState() => _TopicEditorSheetState();
}

class _TopicEditorSheetState extends ConsumerState<TopicEditorSheet> {
  static const _autosaveDelay = Duration(milliseconds: 600);

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _priority = TextEditingController();
  final _minimumScore = TextEditingController();
  final _targetScore = TextEditingController();
  final _deck = TextEditingController();

  final Map<_TopicField, FocusNode> _focusNodes = {
    for (final field in _TopicField.values)
      field: FocusNode(debugLabel: 'topic-editor-${field.name}'),
  };
  final Map<_TopicField, GlobalKey> _tileKeys = {
    for (final field in _TopicField.values) field: GlobalKey(),
  };

  Timer? _autosaveTimer;
  Completer<void>? _savingDone;
  bool _loading = true;
  bool _saving = false;
  bool _jsonBusy = false;
  bool _closing = false;
  bool _validationRequested = false;
  bool _syncingFields = false;
  bool _didSave = false;
  Object? _loadError;
  _TopicField? _expanded;

  String _topicName = '';
  String? _savedKey;

  String? _nameError;
  String? _priorityError;
  String? _minimumScoreError;
  String? _targetScoreError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onFieldChanged);
    _description.addListener(_onFieldChanged);
    _priority.addListener(_onFieldChanged);
    _minimumScore.addListener(_onFieldChanged);
    _targetScore.addListener(_onFieldChanged);
    _deck.addListener(_onFieldChanged);
    for (final entry in _focusNodes.entries) {
      entry.value.addListener(() => _onFocusChanged(entry.key));
    }
    widget.guard.bindCloseHandler(_requestClose);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.guard.releaseCloseHandler();
    _autosaveTimer?.cancel();
    _name.dispose();
    _description.dispose();
    _priority.dispose();
    _minimumScore.dispose();
    _targetScore.dispose();
    _deck.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _busy => _saving || _jsonBusy;

  /// The current text as it would be stored, including invalid values so a
  /// half-typed field still counts as dirty and cannot be dropped silently.
  String get _currentKey => [
    _name.text.trim(),
    _description.text.trim(),
    _canonicalNumber(_priority.text),
    _canonicalNumber(_minimumScore.text),
    _canonicalNumber(_targetScore.text),
    _deck.text.trim(),
  ].join('\u0000');

  bool get _dirty => !_loading && _savedKey != null && _currentKey != _savedKey;

  String _canonicalNumber(String text) {
    final value = text.trim();
    if (value.isEmpty) return '';
    return int.tryParse(value)?.toString() ?? value;
  }

  void _onFieldChanged() {
    if (!mounted || _syncingFields) return;
    final validation = _validationRequested ? _validateDraft() : null;
    setState(() {
      if (validation != null) _applyValidation(validation);
    });
    _syncGuard();
    _scheduleAutosave();
  }

  void _syncGuard() {
    widget.guard.update(dirty: _dirty, saving: _busy, saved: _didSave);
  }

  Future<void> _load() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    try {
      final current =
          await ref.read(topicRepositoryProvider).topicById(widget.topic.id) ??
          widget.topic;
      if (!mounted) return;
      _applyTopic(current);
      setState(() {
        _topicName = current.name;
        _savedKey = _currentKey;
        _loading = false;
        _loadError = null;
        _validationRequested = false;
        _nameError = null;
        _priorityError = null;
        _minimumScoreError = null;
        _targetScoreError = null;
      });
      _syncGuard();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
      _syncGuard();
    }
  }

  void _applyTopic(Topic current) {
    _syncingFields = true;
    try {
      _name.text = current.name;
      _description.text = current.description;
      _priority.text = current.priority?.toString() ?? '';
      _minimumScore.text = current.minimumScore.toString();
      _targetScore.text = current.targetScore.toString();
      _deck.text = current.ankiDeck ?? '';
    } finally {
      _syncingFields = false;
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _syncGuard();
    await _load();
  }

  Future<bool> _requestClose() async {
    if (!mounted) return true;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (_jsonBusy || _closing) return false;
    while (_savingDone != null) {
      await _savingDone!.future;
      if (!mounted) return false;
    }
    if (!mounted) return false;
    if (_loading || _loadError != null) return true;

    final validation = _validateDraft();
    if (validation.draft == null) {
      _showValidation(validation, revealFirst: true);
      return false;
    }

    _closing = true;
    try {
      while (_currentKey != _savedKey) {
        final current = _validateDraft();
        if (current.draft == null) {
          _showValidation(current, revealFirst: true);
          return false;
        }
        final saved = await _persist();
        if (!saved || !mounted) return false;
      }
      return true;
    } finally {
      _closing = false;
    }
  }

  Future<void> _runAutosave() async {
    _autosaveTimer = null;
    if (!_canAutosave || !_dirty) return;
    if (_validateDraft().draft == null) return;
    await _persist();
  }

  /// Saves the latest valid values, waiting for any write already in flight.
  ///
  /// The draft is re-read after waiting and after every write. A field that
  /// became invalid, or a JSON update that started meanwhile, cancels the
  /// write instead of persisting a stale or invalid value.
  Future<bool> _persist() async {
    while (_savingDone != null) {
      await _savingDone!.future;
      if (!mounted) return false;
    }
    if (!mounted || _loading || _loadError != null || _jsonBusy) return false;
    final validation = _validateDraft();
    final draft = validation.draft;
    if (draft == null) return false;
    if (_savedKey == _currentKey) return true;

    final done = _savingDone = Completer<void>();
    var saved = false;
    setState(() => _saving = true);
    _syncGuard();
    try {
      await ref
          .read(topicRepositoryProvider)
          .updateTopic(
            id: widget.topic.id,
            name: draft.name,
            description: draft.description,
            priority: draft.priority,
            ankiDeck: draft.deck,
            minimumScore: draft.minimumScore,
            targetScore: draft.targetScore,
          );
      _savedKey = draft.key;
      _didSave = true;
      saved = true;
      return true;
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not save the topic: $error');
      }
      return false;
    } finally {
      _savingDone = null;
      if (mounted) {
        setState(() => _saving = false);
        _syncGuard();
        if (saved && !_closing && !_jsonBusy && _savedKey != _currentKey) {
          _scheduleAutosave();
        }
      } else {
        _saving = false;
      }
      done.complete();
    }
  }

  Future<bool> _flushAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!mounted || _loading || _loadError != null || _jsonBusy) return false;
    if (_validateDraft().draft == null) return false;
    if (_savedKey == _currentKey) return true;
    return _persist();
  }

  /// Whether a debounced write may run now.
  bool get _canAutosave =>
      mounted &&
      !_loading &&
      _loadError == null &&
      !_saving &&
      !_jsonBusy &&
      !_closing;

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!_canAutosave || !_dirty) return;
    if (_validateDraft().draft == null) return;
    _autosaveTimer = Timer(_autosaveDelay, () => unawaited(_runAutosave()));
  }

  void _onFocusChanged(_TopicField field) {
    if (!mounted || _syncingFields || _loading) return;
    if (_focusNodes[field]!.hasFocus) return;
    if (_jsonBusy || _closing) return;
    _validationRequested = true;
    final validation = _validateDraft();
    setState(() => _applyValidation(validation));
    _syncGuard();
    if (validation.draft == null) {
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      return;
    }
    unawaited(_flushAutosave());
  }

  _DraftValidation _validateDraft() {
    final name = _name.text.trim();
    final description = _description.text.trim();
    final priorityText = _priority.text.trim();
    final priority = priorityText.isEmpty ? null : int.tryParse(priorityText);
    final minimumText = _minimumScore.text.trim();
    final targetText = _targetScore.text.trim();
    final minimum = int.tryParse(minimumText);
    final target = int.tryParse(targetText);

    final nameError = name.isEmpty ? 'Name is required.' : null;
    final priorityError =
        priorityText.isNotEmpty &&
            (priority == null || priority < 1 || priority > 5)
        ? 'Use a number from 1 to 5.'
        : null;
    final minimumError = minimum == null || minimum < 0 || minimum > 100
        ? 'Use a number from 0 to 100.'
        : null;
    var targetError = target == null || target < 0 || target > 100
        ? 'Use a number from 0 to 100.'
        : null;
    if (minimumError == null && targetError == null && target! < minimum!) {
      targetError = 'Target must be at least the minimum score.';
    }

    final deck = _deck.text.trim();
    final draft =
        nameError == null &&
            priorityError == null &&
            minimumError == null &&
            targetError == null
        ? _TopicDraft(
            name: name,
            description: description,
            priority: priority,
            minimumScore: minimum!,
            targetScore: target!,
            deck: deck.isEmpty ? null : deck,
          )
        : null;
    return _DraftValidation(
      draft: draft,
      nameError: nameError,
      priorityError: priorityError,
      minimumScoreError: minimumError,
      targetScoreError: targetError,
    );
  }

  void _applyValidation(_DraftValidation validation) {
    _nameError = validation.nameError;
    _priorityError = validation.priorityError;
    _minimumScoreError = validation.minimumScoreError;
    _targetScoreError = validation.targetScoreError;
  }

  void _showValidation(
    _DraftValidation validation, {
    required bool revealFirst,
  }) {
    _validationRequested = true;
    final first = validation.firstInvalidField;
    setState(() {
      _applyValidation(validation);
      if (revealFirst && first != null) _expanded = first;
    });
    if (revealFirst && first != null) _revealField(first);
  }

  void _revealField(_TopicField field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _tileKeys[field]?.currentContext;
      if (context != null) {
        unawaited(
          Scrollable.ensureVisible(
            context,
            alignment: 0.12,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          ),
        );
      }
      _focusNodes[field]?.requestFocus();
    });
  }

  Future<void> _browseDecks() async {
    final selected = await showAnkiDeckPicker(
      context,
      ref,
      current: _deck.text.trim(),
    );
    if (selected == null || !mounted) return;
    setState(() => _deck.text = selected);
  }

  /// Shares the topic as a JSON file without leaving the editor.
  Future<void> _downloadJson() async {
    if (_busy) return;
    await _flushAutosave();
    if (!mounted) return;
    setState(() => _jsonBusy = true);
    _syncGuard();
    try {
      await ref.read(topicEditServiceProvider).shareTopicJson(widget.topic.id);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not export the topic JSON: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _jsonBusy = false);
        _syncGuard();
        _scheduleAutosave();
      }
    }
  }

  /// Replaces the stored topic from a JSON file and reloads the fields.
  ///
  /// Valid pending edits are flushed first. If an invalid edit is still
  /// pending, the sheet asks before replacing it. Debounced saves are
  /// suspended, and any write already in flight finishes before the import
  /// runs, so a stale autosave cannot overwrite the imported topic.
  Future<void> _updateFromJson() async {
    if (_busy) return;
    await _flushAutosave();
    if (!mounted) return;
    if (_dirty) {
      final confirmed = await confirmDialog(
        context,
        title: 'Replace this topic?',
        message:
            'Updating from a file applies the topic as it is saved now. '
            'Unsaved edits in this sheet will be lost.',
        confirmLabel: 'Update from file',
      );
      if (!confirmed || !mounted) return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    while (_savingDone != null) {
      await _savingDone!.future;
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _jsonBusy = true);
    _syncGuard();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
      );
      if (files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      final preview = await ref
          .read(topicEditServiceProvider)
          .previewUpdateBytes(
            bytes,
            fileName: file.name,
            topicId: widget.topic.id,
          );
      if (!mounted) return;
      final applied = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => TopicUpdatePreviewPage(preview: preview),
        ),
      );
      if (applied != true || !mounted) return;
      await _load();
      if (!mounted) return;
      await showSnack(context, topicUpdateSummary(preview));
    } on ImportException catch (error) {
      if (mounted) await _showIssues(error.issues);
    } on TopicFileException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not read that file: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _jsonBusy = false);
        _syncGuard();
        _scheduleAutosave();
      }
    }
  }

  Future<void> _showIssues(List<ImportIssue> issues) async {
    await M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: 'Update file rejected',
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${issues.length} problem${issues.length == 1 ? '' : 's'} '
                  'found. Nothing was changed.',
                ),
                const SizedBox(height: 12),
                for (final issue in issues.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${issue.displayPath}: ${issue.message}'),
                  ),
                if (issues.length > 20)
                  Text('…and ${issues.length - 20} more.'),
              ],
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

  void _toggle(_TopicField field) {
    if (_busy) return;
    setState(() => _expanded = _expanded == field ? null : field);
  }

  String get _nameValue =>
      _name.text.trim().isEmpty ? 'Not set' : _name.text.trim();

  String get _descriptionValue => _description.text.trim().isEmpty
      ? 'No description'
      : _description.text.trim();

  String get _priorityValue {
    final text = _priority.text.trim();
    if (text.isEmpty) return 'Not set';
    return switch (text) {
      '1' => '1 · highest',
      '5' => '5 · lowest',
      _ => '$text of 5',
    };
  }

  String get _minimumScoreValue => '${_minimumScore.text.trim()}%';

  String get _targetScoreValue => '${_targetScore.text.trim()}%';

  String get _deckValue => _deck.text.trim().isEmpty
      ? 'Default deck from Settings'
      : _deck.text.trim();

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                title: 'Edit topic',
                subtitle: _topicName.isEmpty ? widget.topic.name : _topicName,
              ),
              ..._content(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: M3ELoadingIndicator()),
        ),
      ];
    }
    if (_loadError != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load this topic',
            message: '$_loadError',
            action: M3EButton.tonal(
              onPressed: _retryLoad,
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }
    return [
      _fieldTile(
        field: _TopicField.name,
        icon: Icons.label_outline,
        title: 'Name',
        value: _nameValue,
        editor: M3ETextField(
          key: const ValueKey('topic-editor-name'),
          controller: _name,
          focusNode: _focusNodes[_TopicField.name],
          label: 'Name',
          placeholder: 'e.g. Networking',
          isRequired: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          errorText: _nameError,
        ),
      ),
      _fieldTile(
        field: _TopicField.description,
        icon: Icons.notes_outlined,
        title: 'Description',
        value: _descriptionValue,
        editor: M3ETextField(
          key: const ValueKey('topic-editor-description'),
          controller: _description,
          focusNode: _focusNodes[_TopicField.description],
          label: 'Description',
          placeholder: 'What this topic covers',
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      _fieldTile(
        field: _TopicField.priority,
        icon: Icons.flag_outlined,
        title: 'Priority',
        value: _priorityValue,
        editor: M3ETextField(
          key: const ValueKey('topic-editor-priority'),
          controller: _priority,
          focusNode: _focusNodes[_TopicField.priority],
          label: 'Priority (1–5, optional)',
          placeholder: 'Blank',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _priorityError,
        ),
      ),
      _fieldTile(
        field: _TopicField.minimumScore,
        icon: Icons.flag_circle_outlined,
        title: 'Minimum score',
        value: _minimumScoreValue,
        editor: M3ETextField(
          key: const ValueKey('topic-editor-minimum-score'),
          controller: _minimumScore,
          focusNode: _focusNodes[_TopicField.minimumScore],
          label: 'Minimum (%)',
          placeholder: '70',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _minimumScoreError,
        ),
      ),
      _fieldTile(
        field: _TopicField.targetScore,
        icon: Icons.gps_fixed,
        title: 'Target score',
        value: _targetScoreValue,
        editor: M3ETextField(
          key: const ValueKey('topic-editor-target-score'),
          controller: _targetScore,
          focusNode: _focusNodes[_TopicField.targetScore],
          label: 'Target (%)',
          placeholder: '80',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _targetScoreError,
        ),
      ),
      _fieldTile(
        field: _TopicField.deck,
        icon: Icons.style_outlined,
        title: 'AnkiDroid deck',
        value: _deckValue,
        editor: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            M3ETextField(
              key: const ValueKey('topic-editor-deck'),
              controller: _deck,
              focusNode: _focusNodes[_TopicField.deck],
              label: 'Deck name',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: M3EButton.tonal(
                onPressed: _busy ? null : _browseDecks,
                icon: const Icon(Icons.style_outlined),
                label: const Text('Browse decks'),
              ),
            ),
          ],
        ),
      ),
      OptionTile(
        key: const ValueKey('topic-editor-download-json'),
        icon: Icons.download_outlined,
        title: 'Download topic JSON',
        subtitle: 'Share every practice in this topic as a file',
        onTap: _busy ? null : _downloadJson,
      ),
      OptionTile(
        key: const ValueKey('topic-editor-update-json'),
        icon: Icons.upload_file_outlined,
        title: 'Update topic JSON',
        subtitle: 'Add or modify practices and questions from a file',
        onTap: _busy ? null : _updateFromJson,
      ),
    ];
  }

  Widget _fieldTile({
    required _TopicField field,
    required IconData icon,
    required String title,
    required String value,
    required Widget editor,
  }) {
    final expanded = _expanded == field;
    return KeyedSubtree(
      key: _tileKeys[field],
      child: OptionTile(
        key: ValueKey('topic-editor-tile-${field.name}'),
        icon: icon,
        title: title,
        subtitle: value,
        expanded: expanded,
        onTap: _busy ? null : () => _toggle(field),
        details: expanded ? editor : null,
      ),
    );
  }
}

/// The persisted fields of one valid draft.
class _TopicDraft {
  const _TopicDraft({
    required this.name,
    required this.description,
    required this.priority,
    required this.minimumScore,
    required this.targetScore,
    required this.deck,
  });

  final String name;
  final String description;
  final int? priority;
  final int minimumScore;
  final int targetScore;
  final String? deck;

  /// Canonical form used to compare the draft with the last saved values.
  String get key => [
    name,
    description,
    priority?.toString() ?? '',
    minimumScore.toString(),
    targetScore.toString(),
    deck ?? '',
  ].join('\u0000');
}

/// Field errors and, when every field is valid, the draft they describe.
class _DraftValidation {
  const _DraftValidation({
    required this.draft,
    required this.nameError,
    required this.priorityError,
    required this.minimumScoreError,
    required this.targetScoreError,
  });

  final _TopicDraft? draft;
  final String? nameError;
  final String? priorityError;
  final String? minimumScoreError;
  final String? targetScoreError;

  _TopicField? get firstInvalidField {
    if (nameError != null) return _TopicField.name;
    if (priorityError != null) return _TopicField.priority;
    if (minimumScoreError != null) return _TopicField.minimumScore;
    if (targetScoreError != null) return _TopicField.targetScore;
    return null;
  }
}

/// Header shared by the sheet's option-style tiles.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.emphasized.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
