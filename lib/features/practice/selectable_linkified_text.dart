import 'package:flutter/gestures.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Selectable text with a Define action and tappable http(s) links.
class SelectableLinkifiedText extends StatefulWidget {
  const SelectableLinkifiedText({
    required this.text,
    required this.style,
    required this.onDefine,
    required this.onOpenUrl,
    this.selectable = true,
    super.key,
  });

  final String text;
  final TextStyle style;
  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;
  final bool selectable;

  @override
  State<SelectableLinkifiedText> createState() =>
      _SelectableLinkifiedTextState();
}

class _SelectableLinkifiedTextState extends State<SelectableLinkifiedText> {
  static final _urlPattern = RegExp(r'https?://[^\s<>"`]+');
  final _recognizers = <TapGestureRecognizer>[];
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(SelectableLinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _syncRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _syncRecognizers() {
    _disposeRecognizers();
    for (final match in _urlPattern.allMatches(widget.text)) {
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onOpenUrl(url);
      _recognizers.add(recognizer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    var recognizerIndex = 0;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: widget.style.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          ),
          recognizer: recognizerIndex < _recognizers.length
              ? _recognizers[recognizerIndex]
              : null,
        ),
      );
      recognizerIndex++;
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    final textWidget = Text.rich(
      TextSpan(children: spans),
      style: widget.style,
    );
    if (!widget.selectable) return textWidget;

    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, state) {
        final selected = _selectedText;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            if (selected.isNotEmpty)
              ContextMenuButtonItem(
                label: 'Define',
                onPressed: () {
                  state.hideToolbar();
                  widget.onDefine(
                    selected,
                    Rect.fromLTWH(
                      state.contextMenuAnchors.primaryAnchor.dx,
                      state.contextMenuAnchors.primaryAnchor.dy,
                      0,
                      0,
                    ),
                  );
                },
              ),
          ],
        );
      },
      child: textWidget,
    );
  }
}
