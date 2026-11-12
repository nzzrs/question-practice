import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'anki_deck_picker.dart';

/// The editable field a topic editor tile expands.
enum _TopicField { name, description, priority, deck }

/// Tracks unsaved edits in a [TopicEditorSheet].
///
/// The route that hosts the sheet reads this to guard drag, back and scrim
/// dismissals. It never notifies listeners; the fields are only read when a
/// dismissal is requested.
class TopicEditorSheetGuard {
  bool _dirty = false;
  bool _saving = false;

  /// Whether a field differs from the value loaded from the database.
  bool get dirty => _dirty;

  /// Whether a save is in flight and the sheet must stay open.
  bool get saving => _saving;

  void update({required bool dirty, required bool saving}) {
    _dirty = dirty;
    _saving = saving;
  }
}

/// Asks before throwing away unsaved topic edits.
Future<bool> confirmDiscardTopicChanges(BuildContext context) {
  return confirmDialog(
    context,
    title: 'Discard changes?',
    message: 'Your changes to this topic will be lost.',
    confirmLabel: 'Discard',
    destructive: true,
  );
}

/// Bottom-sheet editor for a topic's name, description, priority and deck.
///
/// The sheet lists the fields as option-style tiles. Tapping a tile expands its
/// inline editor in place, matching the long-press topic and practice menus.
/// It re-reads the topic by id when it opens: a caller may hold a summary from
/// before a backup restore or another database replacement, and saving that
/// stale snapshot back would silently clear newer fields.
class TopicEditorSheet extends ConsumerStatefulWidget {
  const TopicEditorSheet({required this.topic, required this.guard, super.key});

  final Topic topic;
  final TopicEditorSheetGuard guard;

  @override
  ConsumerState<TopicEditorSheet> createState() => _TopicEditorSheetState();
}

class _TopicEditorSheetState extends ConsumerState<TopicEditorSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _priority = TextEditingController();
  final _deck = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  _TopicField? _expanded;

  String _topicName = '';
  String _initialName = '';
  String _initialDescription = '';
  String _initialPriority = '';
  String _initialDeck = '';

  String? _nameError;
  String? _priorityError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onFieldChanged);
    _description.addListener(_onFieldChanged);
    _priority.addListener(_onFieldChanged);
    _deck.addListener(_onFieldChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _priority.dispose();
    _deck.dispose();
    super.dispose();
  }

  bool get _dirty =>
      !_loading &&
      (_name.text != _initialName ||
          _description.text != _initialDescription ||
          _priority.text != _initialPriority ||
          _deck.text != _initialDeck);

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
    _syncGuard();
  }

  void _syncGuard() {
    widget.guard.update(dirty: _dirty, saving: _saving);
  }

  Future<void> _load() async {
    try {
      final current =
          await ref.read(topicRepositoryProvider).topicById(widget.topic.id) ??
          widget.topic;
      if (!mounted) return;
      _name.text = current.name;
      _description.text = current.description;
      _priority.text = current.priority?.toString() ?? '';
      _deck.text = current.ankiDeck ?? '';
      setState(() {
        _topicName = current.name;
        _initialName = current.name;
        _initialDescription = current.description;
        _initialPriority = current.priority?.toString() ?? '';
        _initialDeck = current.ankiDeck ?? '';
        _loading = false;
        _loadError = null;
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

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _syncGuard();
    await _load();
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await confirmDiscardTopicChanges(context);
    if (discard && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final priorityText = _priority.text.trim();
    final parsedPriority = priorityText.isEmpty
        ? null
        : int.tryParse(priorityText);
    final nameError = name.isEmpty ? 'Name is required.' : null;
    final priorityError =
        priorityText.isNotEmpty &&
            (parsedPriority == null || parsedPriority < 1 || parsedPriority > 5)
        ? 'Use a number from 1 to 5.'
        : null;
    if (nameError != null || priorityError != null) {
      setState(() {
        _nameError = nameError;
        _priorityError = priorityError;
        // Show the message next to the field that needs attention.
        if (nameError != null) {
          _expanded = _TopicField.name;
        } else if (priorityError != null) {
          _expanded = _TopicField.priority;
        }
      });
      return;
    }

    setState(() {
      _saving = true;
      _nameError = null;
      _priorityError = null;
    });
    _syncGuard();
    try {
      await ref
          .read(topicRepositoryProvider)
          .updateTopic(
            id: widget.topic.id,
            name: name,
            description: _description.text.trim(),
            priority: parsedPriority,
            ankiDeck: _deck.text.trim().isEmpty ? null : _deck.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _syncGuard();
      await showSnack(context, 'Could not save the topic: $error');
    }
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

  void _toggle(_TopicField field) {
    if (_saving) return;
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

  String get _deckValue => _deck.text.trim().isEmpty
      ? 'Default deck from Settings'
      : _deck.text.trim();

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SheetHeader(
                      title: 'Edit topic',
                      subtitle: _topicName.isEmpty
                          ? widget.topic.name
                          : _topicName,
                    ),
                    ..._content(context),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    M3EButton.text(
                      key: const ValueKey('topic-editor-cancel'),
                      onPressed: _saving ? null : _requestClose,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: M3EButton.filled(
                        key: const ValueKey('topic-editor-save'),
                        onPressed: _saving || _loading || _loadError != null
                            ? null
                            : _save,
                        icon: _saving ? null : const Icon(Icons.check),
                        label: Text(_saving ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          label: 'Name',
          placeholder: 'e.g. Networking',
          isRequired: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
          },
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
        editor: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ETextField(
              key: const ValueKey('topic-editor-priority'),
              controller: _priority,
              label: 'Priority (1–5, optional)',
              placeholder: 'Blank',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: _priorityError,
              onChanged: (_) {
                if (_priorityError != null) {
                  setState(() => _priorityError = null);
                }
              },
            ),
            const SizedBox(height: 8),
            _HelperText(
              '1 is the highest priority, 5 is the lowest. '
              'Leave blank when order does not matter.',
            ),
          ],
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
              label: 'Deck name',
              supportingText: 'Blank uses the default deck from Settings.',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: M3EButton.tonal(
                onPressed: _saving ? null : _browseDecks,
                icon: const Icon(Icons.style_outlined),
                label: const Text('Browse decks'),
              ),
            ),
          ],
        ),
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
    return OptionTile(
      key: ValueKey('topic-editor-tile-${field.name}'),
      icon: icon,
      title: title,
      subtitle: value,
      expanded: expanded,
      onTap: _saving ? null : () => _toggle(field),
      details: expanded ? editor : null,
    );
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

/// Small helper line shown under an inline editor field.
class _HelperText extends StatelessWidget {
  const _HelperText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Text(
      text,
      style: theme.typography.baseline.bodySmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}
