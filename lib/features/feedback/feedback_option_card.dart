import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/app_success.dart';
import '../practice/selectable_linkified_text.dart';
import 'feedback_actions.dart';

/// One alternative in the shared feedback surface.
///
/// The same card is used before an answer (selectable), after an answer
/// (correct/wrong), and in the error review (read-only).
class FeedbackOptionCard extends StatefulWidget {
  const FeedbackOptionCard({
    required this.originalIndex,
    required this.text,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
    required this.multiSelect,
    required this.showLetter,
    required this.explanation,
    required this.actions,
    required this.notes,
    this.onPressed,
    super.key,
  });

  final int originalIndex;
  final String text;
  final bool selected;
  final bool revealed;
  final bool isCorrect;
  final bool multiSelect;
  final bool showLetter;
  final String explanation;
  final FeedbackActions actions;
  final List<String> notes;
  final VoidCallback? onPressed;

  @override
  State<FeedbackOptionCard> createState() => _FeedbackOptionCardState();
}

class _FeedbackOptionCardState extends State<FeedbackOptionCard> {
  late bool _explanationOpen;
  int? _pointer;
  Duration? _pointerDownAt;
  Offset? _pointerDownPosition;

  bool get _shouldOpenExplanation =>
      widget.revealed && (widget.isCorrect || widget.selected);

  @override
  void initState() {
    super.initState();
    _explanationOpen = _shouldOpenExplanation;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _pointerDownAt = event.timeStamp;
    _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final elapsed = _pointerDownAt == null
        ? Duration.zero
        : event.timeStamp - _pointerDownAt!;
    final distance = _pointerDownPosition == null
        ? 0.0
        : (event.position - _pointerDownPosition!).distance;
    _pointer = null;
    _pointerDownAt = null;
    _pointerDownPosition = null;
    if (widget.revealed) return;
    final isTap = elapsed < const Duration(milliseconds: 500) && distance < 12;
    if (isTap) widget.onPressed?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _pointerDownAt = null;
    _pointerDownPosition = null;
  }

  @override
  void didUpdateWidget(FeedbackOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.originalIndex != widget.originalIndex ||
        (!oldWidget.revealed && widget.revealed)) {
      _explanationOpen = _shouldOpenExplanation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final correctNow = widget.revealed && widget.isCorrect;
    final wrongNow = widget.revealed && widget.selected && !widget.isCorrect;
    final background = correctNow
        ? AppSuccess.container(context)
        : wrongNow
        ? theme.colorScheme.errorContainer
        : widget.selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final foreground = correctNow
        ? AppSuccess.onContainer(context)
        : wrongNow
        ? theme.colorScheme.onErrorContainer
        : widget.selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final badgeBackground = correctNow
        ? AppSuccess.foreground(context)
        : wrongNow
        ? theme.colorScheme.error
        : widget.selected
        ? theme.colorScheme.secondary
        : theme.colorScheme.surfaceContainerHighest;
    final badgeForeground = correctNow
        ? theme.colorScheme.surface
        : wrongNow
        ? theme.colorScheme.onError
        : widget.selected
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onSurfaceVariant;
    final letter = String.fromCharCode(65 + widget.originalIndex);
    return Semantics(
      button: !widget.revealed,
      selected: widget.selected,
      label: widget.showLetter
          ? 'Alternative $letter: ${widget.text}'
          : 'Alternative: ${widget.text}',
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Text selection owns touches inside the card. Tapping is resolved
            // from the pointer stream so selecting text and choosing an
            // alternative can both work before an answer is submitted.
            onTap: widget.revealed ? null : () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: ValueKey(
                      'alternative-letter-badge-${widget.originalIndex}',
                    ),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      shape: widget.multiSelect
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius: widget.multiSelect
                          ? BorderRadius.circular(8)
                          : null,
                    ),
                    child: widget.showLetter
                        ? Text(
                            letter,
                            style: theme.typography.baseline.labelMedium
                                .copyWith(
                                  color: badgeForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : correctNow
                        ? Icon(Icons.check, size: 18, color: badgeForeground)
                        : wrongNow
                        ? Icon(Icons.close, size: 18, color: badgeForeground)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableLinkifiedText(
                          key: ValueKey(
                            'alternative-${widget.originalIndex}-text',
                          ),
                          text: widget.text,
                          style: theme.typography.baseline.bodyMedium.copyWith(
                            color: foreground,
                            height: 1.4,
                          ),
                          useSelectionArea: false,
                          onDefine: widget.actions.onDefine,
                          onOpenUrl: widget.actions.onOpenUrl,
                          onNote: widget.actions.onSaveNote,
                          onAsk: widget.actions.onAsk,
                          onNoteTap: widget.actions.onNoteTap,
                          notes: widget.notes,
                        ),
                        if (widget.revealed &&
                            widget.explanation.isNotEmpty &&
                            _explanationOpen) ...[
                          const SizedBox(height: 6),
                          SelectableLinkifiedText(
                            text: widget.explanation,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: foreground.withValues(alpha: 0.82),
                              height: 1.4,
                            ),
                            useSelectionArea: false,
                            onDefine: widget.actions.onDefine,
                            onOpenUrl: widget.actions.onOpenUrl,
                            onNote: widget.actions.onSaveNote,
                            onAsk: widget.actions.onAsk,
                            onNoteTap: widget.actions.onNoteTap,
                            notes: widget.notes,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.revealed && widget.explanation.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: _explanationOpen
                          ? 'Hide explanation'
                          : 'Show explanation',
                      child: InkResponse(
                        key: ValueKey(
                          'alternative-explanation-'
                          '${widget.originalIndex}-toggle',
                        ),
                        onTap: () => setState(
                          () => _explanationOpen = !_explanationOpen,
                        ),
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _explanationOpen
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: foreground.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (correctNow || wrongNow) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        correctNow ? Icons.check : Icons.close,
                        size: 20,
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
