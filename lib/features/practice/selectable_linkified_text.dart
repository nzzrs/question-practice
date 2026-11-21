import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Selectable text with Define and Save as note actions, plus tappable links.
class SelectableLinkifiedText extends StatefulWidget {
  const SelectableLinkifiedText({
    required this.text,
    required this.style,
    required this.onDefine,
    required this.onOpenUrl,
    this.onNote,
    this.onAsk,
    this.onNoteTap,
    this.notes = const [],
    this.selectable = true,
    super.key,
  });

  final String text;
  final TextStyle style;
  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;

  /// Saves the selected phrase as a note.
  final Future<void> Function(String selection, Rect? anchor)? onNote;

  /// Asks the configured AI about the selected phrase.
  final Future<void> Function(String selection, Rect? anchor)? onAsk;

  /// Called with the saved phrase when a note is tapped.
  final ValueChanged<String>? onNoteTap;

  /// Phrases shown with a note tint inside [text].
  final List<String> notes;
  final bool selectable;

  @override
  State<SelectableLinkifiedText> createState() =>
      _SelectableLinkifiedTextState();
}

class _SelectableLinkifiedTextState extends State<SelectableLinkifiedText> {
  static final _urlPattern = RegExp(r'https?://[^\s<>"`]+');
  final _urlRecognizers = <TapGestureRecognizer>[];
  final _noteHits = <_NoteHit>[];
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(SelectableLinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        !_sameNotes(oldWidget.notes, widget.notes) ||
        oldWidget.onNoteTap != widget.onNoteTap) {
      _syncRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _urlRecognizers) {
      recognizer.dispose();
    }
    _urlRecognizers.clear();
    for (final hit in _noteHits) {
      hit.recognizer?.dispose();
    }
    _noteHits.clear();
  }

  void _syncRecognizers() {
    _disposeRecognizers();
    for (final match in _urlPattern.allMatches(widget.text)) {
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onOpenUrl(url);
      _urlRecognizers.add(recognizer);
    }
    final onTap = widget.onNoteTap;
    final haystack = widget.text.toLowerCase();
    for (final note in widget.notes) {
      final needle = note.trim().toLowerCase();
      if (needle.isEmpty) continue;
      var from = 0;
      while (from < haystack.length) {
        final index = haystack.indexOf(needle, from);
        if (index < 0) break;
        final end = index + needle.length;
        TapGestureRecognizer? recognizer;
        if (onTap != null) {
          final phrase = widget.text.substring(index, end);
          recognizer = TapGestureRecognizer()..onTap = () => onTap(phrase);
        }
        _noteHits.add(_NoteHit(index, end, recognizer));
        from = end;
      }
    }
  }

  static bool _sameNotes(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final text = widget.text;
    final urlMatches = _urlPattern.allMatches(text).toList();
    final noteRanges = _noteRanges();
    final urlRanges = [
      for (final match in urlMatches) (match.start, match.end),
    ];

    final cuts = <int>{0, text.length};
    for (final (start, end) in [...urlRanges, ...noteRanges]) {
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
      final noteIndex = _noteHits.indexWhere(
        (hit) => hit.start <= start && end <= hit.end,
      );
      final isNote = noteIndex >= 0;
      TextStyle? style;
      if (urlIndex >= 0) {
        style = widget.style.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        );
      }
      if (isNote) {
        style = (style ?? widget.style).copyWith(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        );
      }
      final TapGestureRecognizer? recognizer = urlIndex >= 0
          ? (urlIndex < _urlRecognizers.length
                ? _urlRecognizers[urlIndex]
                : null)
          : (noteIndex >= 0 ? _noteHits[noteIndex].recognizer : null);
      spans.add(TextSpan(text: chunk, style: style, recognizer: recognizer));
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
            if (selected.isNotEmpty && widget.onAsk != null)
              ContextMenuButtonItem(
                label: 'Ask',
                onPressed: () {
                  state.hideToolbar();
                  unawaited(
                    widget.onAsk!(
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
            if (selected.isNotEmpty && widget.onNote != null)
              ContextMenuButtonItem(
                label: 'Save as note',
                onPressed: () {
                  state.hideToolbar();
                  unawaited(
                    widget.onNote!(
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

  List<(int, int)> _noteRanges() {
    final ranges = <(int, int)>[
      for (final hit in _noteHits) (hit.start, hit.end),
    ];
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

class _NoteHit {
  const _NoteHit(this.start, this.end, this.recognizer);

  final int start;
  final int end;
  final TapGestureRecognizer? recognizer;
}
