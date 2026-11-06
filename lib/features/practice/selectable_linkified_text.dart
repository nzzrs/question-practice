import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Selectable text with Define and Highlight actions, plus tappable links.
class SelectableLinkifiedText extends StatefulWidget {
  const SelectableLinkifiedText({
    required this.text,
    required this.style,
    required this.onDefine,
    required this.onOpenUrl,
    this.onHighlight,
    this.highlights = const [],
    this.selectable = true,
    super.key,
  });

  final String text;
  final TextStyle style;
  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;

  /// Saves the selected phrase as a highlight.
  final Future<void> Function(String selection, Rect? anchor)? onHighlight;

  /// Phrases painted with a highlight background inside [text].
  final List<String> highlights;
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
    final text = widget.text;
    final urlMatches = _urlPattern.allMatches(text).toList();
    final highlightRanges = _highlightRanges();
    final urlRanges = [
      for (final match in urlMatches) (match.start, match.end),
    ];

    final cuts = <int>{0, text.length};
    for (final (start, end) in [...urlRanges, ...highlightRanges]) {
      if (start > 0 && start < text.length) cuts.add(start);
      if (end > 0 && end < text.length) cuts.add(end);
    }
    final ordered = cuts.toList()..sort();

    final spans = <InlineSpan>[];
    for (var index = 0; index + 1 < ordered.length; index++) {
      final start = ordered[index];
      final end = ordered[index + 1];
      if (end <= start) continue;
      final chunk = text.substring(start, end);
      final urlIndex = urlRanges.indexWhere(
        (range) => range.$1 <= start && end <= range.$2,
      );
      final highlighted = highlightRanges.any(
        (range) => range.$1 <= start && end <= range.$2,
      );
      TextStyle? style;
      if (urlIndex >= 0) {
        style = widget.style.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        );
      }
      if (highlighted) {
        style = (style ?? widget.style).copyWith(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        );
      }
      spans.add(
        TextSpan(
          text: chunk,
          style: style,
          recognizer: urlIndex >= 0 && urlIndex < _recognizers.length
              ? _recognizers[urlIndex]
              : null,
        ),
      );
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
            if (selected.isNotEmpty && widget.onHighlight != null)
              ContextMenuButtonItem(
                label: 'Highlight',
                onPressed: () {
                  state.hideToolbar();
                  unawaited(
                    widget.onHighlight!(
                      selected,
                      Rect.fromLTWH(
                        state.contextMenuAnchors.primaryAnchor.dx,
                        state.contextMenuAnchors.primaryAnchor.dy,
                        0,
                        0,
                      ),
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

  List<(int, int)> _highlightRanges() {
    final haystack = widget.text.toLowerCase();
    final ranges = <(int, int)>[];
    for (final highlight in widget.highlights) {
      final needle = highlight.trim().toLowerCase();
      if (needle.isEmpty) continue;
      var from = 0;
      while (from < haystack.length) {
        final index = haystack.indexOf(needle, from);
        if (index < 0) break;
        ranges.add((index, index + needle.length));
        from = index + needle.length;
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.$1 > merged.last.$2) {
        merged.add(range);
      } else if (range.$2 > merged.last.$2) {
        merged[merged.length - 1] = (merged.last.$1, range.$2);
      }
    }
    return merged;
  }
}
