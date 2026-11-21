import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'feedback_actions.dart';

/// One selection area for every read-only part of the feedback surface.
///
/// Child text widgets must disable their own selection area so Define,
/// Ask, Save as note and URL taps all resolve against the same selection.
class FeedbackSelectionArea extends StatefulWidget {
  const FeedbackSelectionArea({
    required this.child,
    required this.actions,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final FeedbackActions actions;
  final bool enabled;

  @override
  State<FeedbackSelectionArea> createState() => _FeedbackSelectionAreaState();
}

class _FeedbackSelectionAreaState extends State<FeedbackSelectionArea> {
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, state) {
        final selected = _selectedText;
        final anchor = Rect.fromLTWH(
          state.contextMenuAnchors.primaryAnchor.dx,
          state.contextMenuAnchors.primaryAnchor.dy,
          0,
          0,
        );
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            if (selected.isNotEmpty)
              ContextMenuButtonItem(
                label: 'Define',
                onPressed: () {
                  state.hideToolbar();
                  widget.actions.onDefine(selected, anchor);
                },
              ),
            if (selected.isNotEmpty && widget.actions.onAsk != null)
              ContextMenuButtonItem(
                label: 'Ask',
                onPressed: () {
                  state.hideToolbar();
                  unawaited(widget.actions.onAsk!(selected, anchor));
                },
              ),
            if (selected.isNotEmpty && widget.actions.onSaveNote != null)
              ContextMenuButtonItem(
                label: 'Save as note',
                onPressed: () {
                  state.hideToolbar();
                  unawaited(widget.actions.onSaveNote!(selected, anchor));
                },
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
