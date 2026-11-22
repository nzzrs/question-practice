import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';
import 'domain/wrong_answer_bullets.dart';
import 'wrong_answer_bullets_controller.dart';

/// Editable Logseq-style bullets for "What went wrong?".
///
/// Lives outside the feedback selection area so editable fields never join the
/// read-only selection registrar.
class WrongAnswerBulletsEditor extends StatefulWidget {
  const WrongAnswerBulletsEditor({required this.controller, super.key});

  final WrongAnswerBulletsController controller;

  @override
  State<WrongAnswerBulletsEditor> createState() =>
      _WrongAnswerBulletsEditorState();
}

class _WrongAnswerBulletsEditorState extends State<WrongAnswerBulletsEditor> {
  final _fields = <_BulletField>[];
  bool _syncing = false;
  bool _wasLimited = false;

  WrongAnswerBulletsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleModelChanged);
    _syncFields();
  }

  @override
  void didUpdateWidget(covariant WrongAnswerBulletsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleModelChanged);
      widget.controller.addListener(_handleModelChanged);
      _syncFields();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleModelChanged);
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _handleModelChanged() {
    if (!mounted) return;
    _syncFields();
    setState(() {});
  }

  void _syncFields() {
    final rows = _controller.rows;
    final removed = <_BulletField>[];
    while (_fields.length > rows.length) {
      removed.add(_fields.removeLast());
    }
    if (removed.isNotEmpty) {
      // A blur can be what removed the row, so dispose after the focus
      // notification finishes instead of inside it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final field in removed) {
          field.dispose();
        }
      });
    }
    while (_fields.length < rows.length) {
      _fields.add(_BulletField());
    }
    _syncing = true;
    for (var index = 0; index < rows.length; index++) {
      final field = _fields[index];
      if (field.controller.text == rows[index]) continue;
      final offset = field.focusNode.hasFocus
          ? field.controller.selection.baseOffset
          : rows[index].length;
      final safe = offset.clamp(0, rows[index].length);
      field.controller.value = TextEditingValue(
        text: rows[index],
        selection: TextSelection.collapsed(offset: safe),
      );
    }
    _syncing = false;
  }

  void _handleChanged(int index, String value) {
    if (_syncing) return;
    final limited = value.length > WrongAnswerBullets.maxBulletLength;
    _controller.setRow(index, value);
    if (limited && !_wasLimited && mounted) {
      showSnack(context, 'A bullet can keep up to 500 characters.');
    }
    _wasLimited = limited;
  }

  void _handleSplit(int index, String before, List<String> after) {
    if (!mounted) return;
    _controller.replaceRow(index, before);
    if (after.isEmpty) {
      _controller.addRow();
    } else {
      _controller.insertRows(index + 1, after);
    }
    _syncFields();
    final focusIndex = after.isEmpty ? index + 1 : index + after.length;
    final focusStart = after.length == 1 && after.first.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || focusIndex >= _fields.length) return;
      _focusField(focusIndex, atEnd: !focusStart);
    });
    setState(() {});
  }

  void _focusField(int index, {bool atEnd = true}) {
    final field = _fields[index];
    field.focusNode.requestFocus();
    final text = field.controller.text;
    field.controller.selection = TextSelection.collapsed(
      offset: atEnd ? text.length : 0,
    );
  }

  void _addBullet() {
    if (!_controller.canAddRow) {
      showSnack(context, 'You can keep up to 30 notes.');
      return;
    }
    final rows = _controller.rows;
    if (rows.isNotEmpty && rows.last.trim().isEmpty) {
      _focusField(rows.length - 1);
      return;
    }
    _controller.addRow();
    _syncFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusField(_controller.rows.length - 1);
    });
    setState(() {});
  }

  void _removeBullet(int index) {
    _controller.removeRow(index);
    _syncFields();
    final focusIndex = index.clamp(0, _fields.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fields.isNotEmpty) _focusField(focusIndex);
    });
    setState(() {});
  }

  void _handleBlur(int index) {
    final rows = _controller.rows;
    if (index < rows.length && rows[index].trim().isEmpty) {
      _controller.dropEmptyRow(index);
      _syncFields();
    }
    _controller.flush();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final state = _controller.saveState;
    return Column(
      key: const ValueKey('wrong-answer-bullets-editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What went wrong?', style: theme.typography.emphasized.titleSmall),
        const SizedBox(height: 4),
        Text(
          'One idea per line. These notes feed Create cards.',
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _fields.length; index++)
          _BulletRow(
            key: ValueKey('wrong-answer-bullets-row-$index'),
            index: index,
            field: _fields[index],
            placeholder: index == 0 ? 'I confused X with Y.' : 'Another idea',
            onChanged: (value) => _handleChanged(index, value),
            onSplit: (before, after) => _handleSplit(index, before, after),
            onDelete: _fields.length == 1 ? null : () => _removeBullet(index),
            onFocusChange: (hasFocus) {
              if (!hasFocus) _handleBlur(index);
            },
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            M3EButton.text(
              key: const ValueKey('wrong-answer-bullets-add'),
              onPressed: _addBullet,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 8),
                  Text('Add bullet'),
                ],
              ),
            ),
            const Spacer(),
            if (state != WrongAnswerBulletsSaveState.clean)
              Text(
                key: const ValueKey('wrong-answer-bullets-save-status'),
                state == WrongAnswerBulletsSaveState.saving
                    ? 'Saving…'
                    : 'Not saved. Try again.',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: state == WrongAnswerBulletsSaveState.failed
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BulletRow extends StatefulWidget {
  const _BulletRow({
    required this.index,
    required this.field,
    required this.placeholder,
    required this.onChanged,
    required this.onSplit,
    required this.onDelete,
    required this.onFocusChange,
    super.key,
  });

  final int index;
  final _BulletField field;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final void Function(String before, List<String> after) onSplit;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onFocusChange;

  @override
  State<_BulletRow> createState() => _BulletRowState();
}

class _BulletRowState extends State<_BulletRow> {
  @override
  void initState() {
    super.initState();
    widget.field.focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _BulletRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field) {
      oldWidget.field.focusNode.removeListener(_handleFocus);
      widget.field.focusNode.addListener(_handleFocus);
    }
  }

  @override
  void dispose() {
    widget.field.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    widget.onFocusChange(widget.field.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final field = widget.field;
    return AnimatedBuilder(
      animation: field.focusNode,
      builder: (context, _) {
        final focused = field.focusNode.hasFocus;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            decoration: BoxDecoration(
              color: focused
                  ? theme.colorScheme.surfaceContainerLow
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 16),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      if (field.controller.text.isEmpty)
                        Positioned(
                          left: 0,
                          top: 12,
                          child: IgnorePointer(
                            child: Text(
                              widget.placeholder,
                              style: theme.typography.baseline.bodyMedium
                                  .copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Semantics(
                          label: 'Wrong answer bullet ${widget.index + 1}',
                          child: EditableText(
                            key: ValueKey(
                              'wrong-answer-bullets-field-${widget.index}',
                            ),
                            controller: field.controller,
                            focusNode: field.focusNode,
                            style: theme.typography.baseline.bodyMedium
                                .copyWith(
                                  color: theme.colorScheme.onSurface,
                                  height: 1.45,
                                ),
                            cursorColor: theme.colorScheme.primary,
                            backgroundCursorColor: Colors.transparent,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            keyboardAppearance: theme.colorScheme.brightness,
                            inputFormatters: [
                              _BulletSplitFormatter(onSplit: widget.onSplit),
                            ],
                            onChanged: widget.onChanged,
                            onTapOutside: (_) => field.focusNode.unfocus(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                M3EIconButton(
                  key: ValueKey('wrong-answer-bullets-delete-${widget.index}'),
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.close),
                  tooltip: 'Delete bullet',
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BulletField {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Turns a newline arriving as text input into a new bullet.
///
/// Both soft and hardware keyboards surface Enter as a text edit, so one
/// formatter covers both. A paste with several lines is handled in one pass.
class _BulletSplitFormatter extends TextInputFormatter {
  _BulletSplitFormatter({required this.onSplit});

  final void Function(String before, List<String> after) onSplit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!text.contains('\n') && !text.contains('\r')) return newValue;
    final parts = text.split(RegExp(r'\r\n|\r|\n'));
    final before = parts.first;
    final after = <String>[
      for (final line in parts.skip(1))
        if (line.trim().isNotEmpty) WrongAnswerBullets.stripMarker(line),
    ];
    if (after.isEmpty && (text.endsWith('\n') || text.endsWith('\r'))) {
      after.add('');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSplit(before, after);
    });
    return TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );
  }
}
