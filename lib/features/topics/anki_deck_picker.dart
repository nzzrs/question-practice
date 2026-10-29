import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/platform/anki_gateway.dart';

/// Shows AnkiDroid decks as a `::` hierarchy.
///
/// Returns a deck name, an empty string for the default deck, or null when the
/// picker is cancelled. Anki decks are flat names, so the tree is rebuilt from
/// the `::` separators and new names are written back in the same form.
Future<String?> showAnkiDeckPicker(
  BuildContext context,
  WidgetRef ref, {
  String? current,
  bool allowDefault = true,
}) async {
  final custom = TextEditingController(text: current ?? '');
  final defaultDeck =
      ref.read(settingsProvider).value?.ankiDeck ?? 'Question Practice';
  final result = await M3EDialog.show<String>(
    context,
    dialog: M3EDialog(
      title: 'AnkiDroid deck',
      content: _DeckPickerBody(
        gateway: ref.read(ankiGatewayProvider),
        current: current,
        defaultDeck: defaultDeck,
        custom: custom,
        allowDefault: allowDefault,
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: () {
            final name = custom.text.trim();
            if (name.isNotEmpty) Navigator.of(context).pop(name);
          },
          child: const Text('Use typed name'),
        ),
      ],
    ),
  );
  custom.dispose();
  return result;
}

class _DeckNode {
  _DeckNode({required this.segment, required this.path});

  final String segment;
  final String path;
  final List<_DeckNode> children = [];
  bool expanded = true;

  void insert(List<String> segments) {
    var node = this;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final path = segments.take(index + 1).join('::');
      _DeckNode? child;
      for (final item in node.children) {
        if (item.segment == segment) {
          child = item;
          break;
        }
      }
      if (child == null) {
        child = _DeckNode(segment: segment, path: path);
        node.children.add(child);
      }
      node = child;
    }
    node.children.sort(
      (a, b) => a.segment.toLowerCase().compareTo(b.segment.toLowerCase()),
    );
    for (final child in node.children) {
      child._sortRecursively();
    }
  }

  void _sortRecursively() {
    children.sort(
      (a, b) => a.segment.toLowerCase().compareTo(b.segment.toLowerCase()),
    );
    for (final child in children) {
      child._sortRecursively();
    }
  }

  List<_DeckNode> get orderedChildren {
    final sorted = List<_DeckNode>.of(children)
      ..sort(
        (a, b) => a.segment.toLowerCase().compareTo(b.segment.toLowerCase()),
      );
    return sorted;
  }
}

class _DeckPickerBody extends StatefulWidget {
  const _DeckPickerBody({
    required this.gateway,
    required this.current,
    required this.defaultDeck,
    required this.custom,
    required this.allowDefault,
  });

  final AnkiGateway gateway;
  final String? current;
  final String defaultDeck;
  final TextEditingController custom;
  final bool allowDefault;

  @override
  State<_DeckPickerBody> createState() => _DeckPickerBodyState();
}

class _DeckPickerBodyState extends State<_DeckPickerBody> {
  final _newDeck = TextEditingController();
  _DeckNode _root = _DeckNode(segment: '', path: '');
  List<String> _decks = const [];
  String? _message;
  String? _addingUnder;
  String? _addError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newDeck.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = await widget.gateway.status();
    if (!status.installed) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'AnkiDroid is not installed. Type a deck name instead.';
        });
      }
      return;
    }
    if (!status.apiAvailable) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Enable the AnkiDroid API in AnkiDroid settings to load decks.';
        });
      }
      return;
    }
    if (!status.permissionGranted) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Grant AnkiDroid database permission in Settings to load decks.';
        });
      }
      return;
    }
    final decks = await widget.gateway.deckNames();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _decks = decks;
      _root = _buildTree(decks);
      if (decks.isEmpty) {
        _message =
            'No decks found. Type a new deck name; it is created on export.';
      }
    });
  }

  _DeckNode _buildTree(List<String> decks) {
    final root = _DeckNode(segment: '', path: '');
    for (final deck in decks) {
      final segments = [
        for (final part in deck.split('::'))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      if (segments.isEmpty) continue;
      root.insert(segments);
    }
    return root;
  }

  void _beginAdd(String path) {
    setState(() {
      _addingUnder = path;
      _newDeck.clear();
      _addError = null;
    });
  }

  void _cancelAdd() {
    setState(() {
      _addingUnder = null;
      _newDeck.clear();
      _addError = null;
    });
  }

  void _submitAdd() {
    final parentPath = _addingUnder;
    if (parentPath == null) return;
    final name = _newDeck.text.trim();
    if (name.isEmpty) {
      setState(() => _addError = 'Name a deck first.');
      return;
    }
    if (name.contains('::')) {
      setState(() => _addError = 'Add one level at a time.');
      return;
    }
    final path = parentPath.isEmpty ? name : '$parentPath::$name';
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SizedBox(
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Decks use AnkiDroid names with :: for each level. Pick a deck or add one under any level.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.allowDefault)
            _DeckOption(
              title: 'Use default deck',
              subtitle: widget.defaultDeck,
              selected: (widget.current ?? '').trim().isEmpty,
              onPressed: () => Navigator.of(context).pop(''),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: M3ELoadingIndicator()),
            )
          else ...[
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _message!,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_decks.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_addingUnder == '') _addRow(0),
                      for (final node in _root.orderedChildren)
                        ..._buildNode(node, 0),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: M3EButton.tonal(
                onPressed: () => _beginAdd(''),
                icon: const Icon(Icons.add),
                label: const Text('Add deck'),
              ),
            ),
            const SizedBox(height: 12),
            M3ETextField(
              controller: widget.custom,
              label: 'Or type a deck name',
              placeholder: 'Parent::Child is allowed',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildNode(_DeckNode node, int depth) {
    final hasChildren = node.children.isNotEmpty;
    return [
      _DeckRow(
        node: node,
        depth: depth,
        selected: widget.current == node.path,
        onPressed: () => Navigator.of(context).pop(node.path),
        onToggle: hasChildren
            ? () => setState(() => node.expanded = !node.expanded)
            : null,
        onAdd: () => _beginAdd(node.path),
      ),
      if (_addingUnder == node.path) _addRow(depth + 1),
      if (node.expanded)
        for (final child in node.orderedChildren)
          ..._buildNode(child, depth + 1),
    ];
  }

  Widget _addRow(int depth) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.0 + depth * 18, 4, 8, 8),
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ETextField(
              controller: _newDeck,
              label: 'New deck name',
              placeholder: 'One level, no ::',
              isRequired: true,
              errorText: _addError,
              onSubmitted: (_) => _submitAdd(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                M3EButton.filled(
                  onPressed: _submitAdd,
                  icon: const Icon(Icons.check),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 4),
                M3EButton.text(
                  onPressed: _cancelAdd,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            if (_addError != null)
              Text(
                _addError!,
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.node,
    required this.depth,
    required this.selected,
    required this.onPressed,
    required this.onToggle,
    required this.onAdd,
  });

  final _DeckNode node;
  final int depth;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0),
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: onToggle == null
                      ? const SizedBox.shrink()
                      : M3EIconButton(
                          variant: M3EIconButtonVariant.standard,
                          icon: Icon(
                            node.expanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                          ),
                          tooltip: node.expanded ? 'Collapse' : 'Expand',
                          onPressed: onToggle,
                        ),
                ),
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add under ${node.path}',
                  onPressed: onAdd,
                ),
                Icon(
                  selected ? Icons.folder_open : Icons.folder_outlined,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  node.segment,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: selected
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckOption extends StatelessWidget {
  const _DeckOption({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: M3ECard(
        variant: M3ECardVariant.outlined,
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.typography.baseline.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
