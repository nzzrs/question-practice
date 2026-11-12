import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'anki_deck_picker.dart';

/// Full-page editor for a topic's name, description, priority and Anki deck.
///
/// The page re-reads the topic by id when it opens. A caller may hold a summary
/// from before a backup restore or another database replacement, and saving
/// that stale snapshot back would silently clear newer fields.
class TopicEditorPage extends ConsumerStatefulWidget {
  const TopicEditorPage({required this.topic, super.key});

  final Topic topic;

  @override
  ConsumerState<TopicEditorPage> createState() => _TopicEditorPageState();
}

class _TopicEditorPageState extends ConsumerState<TopicEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _priority = TextEditingController();
  final _deck = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;

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
        _initialName = current.name;
        _initialDescription = current.description;
        _initialPriority = current.priority?.toString() ?? '';
        _initialDeck = current.ankiDeck ?? '';
        _loading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _load();
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your changes to this topic will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
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
      });
      return;
    }

    setState(() {
      _saving = true;
      _nameError = null;
      _priorityError = null;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppPage(
        title: 'Edit topic',
        showBack: true,
        onBack: () => Navigator.of(context).maybePop(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
        ],
      );
    }
    if (_loadError != null) {
      return AppPage(
        title: 'Edit topic',
        showBack: true,
        onBack: () => Navigator.of(context).maybePop(),
        children: [
          EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load this topic',
            message: '$_loadError',
            action: M3EButton.tonal(
              onPressed: _retryLoad,
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_requestClose());
      },
      child: AppPage(
        title: 'Edit topic',
        showBack: true,
        onBack: _requestClose,
        bottomBar: AppActionDock(
          child: Row(
            children: [
              M3EButton.text(
                onPressed: _saving ? null : _requestClose,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: M3EButton.filled(
                  key: const ValueKey('topic-editor-save'),
                  onPressed: _saving ? null : _save,
                  icon: _saving ? null : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                'Details',
                supporting: 'The name is required and appears on Home and practice lists.',
              ),
              TonalBox(
                child: Column(
                  children: [
                    M3ETextField(
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
                    const SizedBox(height: 12),
                    M3ETextField(
                      key: const ValueKey('topic-editor-description'),
                      controller: _description,
                      label: 'Description',
                      placeholder: 'What this topic covers',
                      maxLines: 4,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionTitle(
                'Priority',
                supporting:
                    'Optional. 1 is the highest priority, 5 is the lowest. '
                    'Leave blank when order does not matter.',
              ),
              TonalBox(
                child: M3ETextField(
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
              ),
              const SizedBox(height: 22),
              SectionTitle(
                'Deck destination',
                supporting: 'Choose where cards from this topic are sent.',
              ),
              TonalBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    M3ETextField(
                      key: const ValueKey('topic-editor-deck'),
                      controller: _deck,
                      label: 'AnkiDroid deck',
                      supportingText:
                          'Blank uses the default deck from Settings.',
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    M3EButton.tonal(
                      onPressed: _saving ? null : _browseDecks,
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Browse decks'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
