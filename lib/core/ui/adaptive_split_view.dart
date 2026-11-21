import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// A two-pane layout with a draggable divider.
///
/// The split is vertical (panes stacked, horizontal divider) in portrait and
/// narrow windows, and horizontal (panes side by side, vertical divider) in
/// wide windows at 720dp or in phone landscape at 600dp. Pass [horizontal] to
/// override the breakpoints, for example in a test.
///
/// Each child owns its scrolling. The split view never wraps the panes in a
/// scroll view; it only gives each pane a bounded extent along the split axis.
///
/// The ratio is kept per [PageStorage] bucket under [storageKey], with a
/// separate value for each orientation. Nothing is written to settings or the
/// database, so reopening the route restores the default ratio.
class AdaptiveSplitView extends StatefulWidget {
  const AdaptiveSplitView({
    required this.leading,
    required this.trailing,
    this.initialRatio = 0.52,
    this.minLeading = 160,
    this.minTrailing = 220,
    this.horizontalInitialRatio = 0.56,
    this.horizontalMinLeading = 300,
    this.horizontalMinTrailing = 280,
    this.storageKey,
    this.horizontal,
    super.key,
  }) : assert(initialRatio > 0 && initialRatio < 1),
       assert(horizontalInitialRatio > 0 && horizontalInitialRatio < 1),
       assert(minLeading >= 0),
       assert(minTrailing >= 0),
       assert(horizontalMinLeading >= 0),
       assert(horizontalMinTrailing >= 0);

  /// The pane above a horizontal divider, or left of a vertical divider.
  final Widget leading;

  /// The pane below a horizontal divider, or right of a vertical divider.
  final Widget trailing;

  /// Default leading share when the panes are stacked vertically.
  final double initialRatio;

  /// Minimum height of the leading pane when the panes are stacked.
  final double minLeading;

  /// Minimum height of the trailing pane when the panes are stacked.
  final double minTrailing;

  /// Default leading share when the panes are side by side.
  final double horizontalInitialRatio;

  /// Minimum width of the leading pane when the panes are side by side.
  final double horizontalMinLeading;

  /// Minimum width of the trailing pane when the panes are side by side.
  final double horizontalMinTrailing;

  /// Identifies this split view in the current [PageStorage] bucket.
  ///
  /// Without a key the ratio is not persisted, but it still survives ordinary
  /// rebuilds while the widget stays mounted.
  final Key? storageKey;

  /// Forces the split axis. When null the axis follows the window size.
  final bool? horizontal;

  /// The draggable divider, exposed for tests and host focus handling.
  static const Key dividerKey = ValueKey<String>('adaptive-split-view-divider');

  /// Extent of the divider along the split axis, including the hit target.
  static const double dividerExtent = 48;

  @override
  State<AdaptiveSplitView> createState() => _AdaptiveSplitViewState();
}

class _AdaptiveSplitViewState extends State<AdaptiveSplitView> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AdaptiveSplitView');
  double? _verticalRatio;
  double? _horizontalRatio;
  bool _loadedStorage = false;
  bool _dragging = false;
  bool _focusHighlight = false;
  bool _announcedClamp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedStorage) {
      _readStoredRatios();
    }
  }

  @override
  void didUpdateWidget(AdaptiveSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storageKey != oldWidget.storageKey) {
      _verticalRatio = null;
      _horizontalRatio = null;
      _readStoredRatios();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _readStoredRatios() {
    _loadedStorage = true;
    final bucket = PageStorage.maybeOf(context);
    if (bucket == null || widget.storageKey == null) return;

    _verticalRatio = _readRatio(bucket, horizontal: false) ?? _verticalRatio;
    _horizontalRatio = _readRatio(bucket, horizontal: true) ?? _horizontalRatio;
  }

  double? _readRatio(PageStorageBucket bucket, {required bool horizontal}) {
    final value = bucket.readState(
      context,
      identifier: _storageIdentifier(horizontal),
    );
    if (value is double && value > 0 && value < 1) return value;
    return null;
  }

  String _storageIdentifier(bool horizontal) {
    final axis = horizontal ? 'horizontal' : 'vertical';
    return 'adaptive-split-view/${widget.storageKey}/$axis';
  }

  void _persistRatio(bool horizontal) {
    if (widget.storageKey == null) return;
    final value = horizontal ? _horizontalRatio : _verticalRatio;
    final bucket = PageStorage.maybeOf(context);
    if (value == null || bucket == null) return;
    bucket.writeState(
      context,
      value,
      identifier: _storageIdentifier(horizontal),
    );
  }

  bool _isHorizontal(BoxConstraints constraints, Size window) {
    final override = widget.horizontal;
    if (override != null) return override;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : window.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : window.height;
    return width >= 720 || (width >= 600 && width > height);
  }

  double _resolveRatio(_PaneBounds bounds, bool horizontal) {
    final configured = horizontal ? _horizontalRatio : _verticalRatio;
    final fallback = horizontal
        ? widget.horizontalInitialRatio
        : widget.initialRatio;
    if (bounds.space <= 0) return 0.5;
    return (configured ?? fallback).clamp(bounds.minRatio, bounds.maxRatio);
  }

  void _setRatio(
    double ratio,
    _PaneBounds bounds,
    bool horizontal, {
    required bool persist,
  }) {
    if (bounds.space <= 0) return;
    final next = ratio.clamp(bounds.minRatio, bounds.maxRatio);
    final current = horizontal ? _horizontalRatio : _verticalRatio;
    if (current != null && (current - next).abs() < 1e-9) {
      if (persist) _persistRatio(horizontal);
      return;
    }
    setState(() {
      if (horizontal) {
        _horizontalRatio = next;
      } else {
        _verticalRatio = next;
      }
    });
    if (persist) _persistRatio(horizontal);
  }

  void _beginDrag() {
    _announcedClamp = false;
    if (_dragging) return;
    setState(() => _dragging = true);
  }

  void _updateDrag(
    DragUpdateDetails details,
    _PaneBounds bounds,
    bool horizontal,
  ) {
    if (bounds.space <= 0) return;
    final delta = horizontal ? details.delta.dx : details.delta.dy;
    if (delta == 0) return;

    final current = _resolveRatio(bounds, horizontal);
    final desired = current * bounds.space + delta;
    final clamped = desired.clamp(bounds.minLeadExtent, bounds.maxLeadExtent);
    final hitBoundary = (desired - clamped).abs() > 0.001;
    if (hitBoundary && !_announcedClamp) {
      _announcedClamp = true;
      unawaited(HapticFeedback.selectionClick());
    } else if (!hitBoundary) {
      _announcedClamp = false;
    }

    _setRatio(clamped / bounds.space, bounds, horizontal, persist: false);
  }

  void _endDrag(bool horizontal) {
    if (_dragging) {
      setState(() => _dragging = false);
    }
    _announcedClamp = false;
    _persistRatio(horizontal);
  }

  void _adjust(
    double fraction,
    _PaneBounds bounds,
    bool horizontal, {
    bool persist = true,
  }) {
    if (bounds.space <= 0) return;
    final current = _resolveRatio(bounds, horizontal);
    final desired = (current + fraction) * bounds.space;
    final clamped = desired.clamp(bounds.minLeadExtent, bounds.maxLeadExtent);
    _setRatio(clamped / bounds.space, bounds, horizontal, persist: persist);
  }

  void _reset(_PaneBounds bounds, bool horizontal) {
    final fallback = horizontal
        ? widget.horizontalInitialRatio
        : widget.initialRatio;
    _setRatio(fallback, bounds, horizontal, persist: true);
  }

  String _semanticsValue(double ratio, _PaneBounds bounds) {
    final percent = (ratio * 100).round();
    if (ratio <= bounds.minRatio + 1e-6) return '$percent percent, minimum';
    if (ratio >= bounds.maxRatio - 1e-6) return '$percent percent, maximum';
    return '$percent percent';
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final window = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final extraMinimum = 32 * (textScale - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = _isHorizontal(constraints, window);
        final available = horizontal
            ? (constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : window.width)
            : (constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : window.height);
        final bounds = _PaneBounds.compute(
          available: available,
          minLeading:
              (horizontal ? widget.horizontalMinLeading : widget.minLeading) +
              extraMinimum,
          minTrailing:
              (horizontal ? widget.horizontalMinTrailing : widget.minTrailing) +
              extraMinimum,
        );
        final ratio = _resolveRatio(bounds, horizontal);
        final leadExtent = bounds.space * ratio;
        final trailExtent = bounds.space - leadExtent;

        final leading = SizedBox(
          width: horizontal ? leadExtent : null,
          height: horizontal ? null : leadExtent,
          child: widget.leading,
        );
        final trailing = SizedBox(
          width: horizontal ? trailExtent : null,
          height: horizontal ? null : trailExtent,
          child: widget.trailing,
        );
        final divider = _buildDivider(
          theme: theme,
          bounds: bounds,
          horizontal: horizontal,
          ratio: ratio,
        );

        if (horizontal) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [leading, divider, trailing],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [leading, divider, trailing],
        );
      },
    );
  }

  Widget _buildDivider({
    required M3EThemeData theme,
    required _PaneBounds bounds,
    required bool horizontal,
    required double ratio,
  }) {
    final scheme = theme.colorScheme;
    final lineColor = _dragging
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.55);
    final handleColor = _dragging
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.55);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);

    final line = horizontal
        ? Container(width: 1, height: double.infinity, color: lineColor)
        : Container(width: double.infinity, height: 1, color: lineColor);
    final handle = AnimatedContainer(
      duration: duration,
      width: horizontal ? (_dragging ? 6 : 4) : (_dragging ? 48 : 32),
      height: horizontal ? (_dragging ? 48 : 32) : (_dragging ? 6 : 4),
      decoration: BoxDecoration(
        color: handleColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    final increased = _resolveRatio(bounds, horizontal) + 0.10;
    final decreased = _resolveRatio(bounds, horizontal) - 0.10;
    final increasedValue = _semanticsValue(
      increased.clamp(bounds.minRatio, bounds.maxRatio),
      bounds,
    );
    final decreasedValue = _semanticsValue(
      decreased.clamp(bounds.minRatio, bounds.maxRatio),
      bounds,
    );

    final focusRing = _focusHighlight
        ? Container(
            width: horizontal ? 12 : 40,
            height: horizontal ? 40 : 12,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          )
        : const SizedBox.shrink();

    final Widget dividerBody = SizedBox(
      width: horizontal ? AdaptiveSplitView.dividerExtent : null,
      height: horizontal ? null : AdaptiveSplitView.dividerExtent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: line),
          Center(child: handle),
          Center(child: focusRing),
        ],
      ),
    );

    final resizeIntent = horizontal
        ? const {
            SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizeIntent(-0.05),
            SingleActivator(LogicalKeyboardKey.arrowRight): _ResizeIntent(0.05),
            SingleActivator(LogicalKeyboardKey.home): _ResetSplitIntent(),
          }
        : const {
            SingleActivator(LogicalKeyboardKey.arrowUp): _ResizeIntent(-0.05),
            SingleActivator(LogicalKeyboardKey.arrowDown): _ResizeIntent(0.05),
            SingleActivator(LogicalKeyboardKey.home): _ResetSplitIntent(),
          };

    final gestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      onHorizontalDragStart: horizontal ? (_) => _beginDrag() : null,
      onHorizontalDragUpdate: horizontal
          ? (details) => _updateDrag(details, bounds, true)
          : null,
      onHorizontalDragEnd: horizontal ? (_) => _endDrag(true) : null,
      onHorizontalDragCancel: horizontal ? () => _endDrag(true) : null,
      onVerticalDragStart: horizontal ? null : (_) => _beginDrag(),
      onVerticalDragUpdate: horizontal
          ? null
          : (details) => _updateDrag(details, bounds, false),
      onVerticalDragEnd: horizontal ? null : (_) => _endDrag(false),
      onVerticalDragCancel: horizontal ? null : () => _endDrag(false),
      child: dividerBody,
    );

    final semanticDivider = Semantics(
      key: AdaptiveSplitView.dividerKey,
      container: true,
      slider: true,
      label: 'Resize panes',
      value: _semanticsValue(ratio, bounds),
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      hint: horizontal
          ? 'Swipe left or right to resize'
          : 'Swipe up or down to resize',
      onIncrease: () => _adjust(0.10, bounds, horizontal),
      onDecrease: () => _adjust(-0.10, bounds, horizontal),
      child: gestures,
    );

    return FocusableActionDetector(
      focusNode: _focusNode,
      shortcuts: resizeIntent,
      actions: {
        _ResizeIntent: CallbackAction<_ResizeIntent>(
          onInvoke: (intent) {
            _adjust(intent.fraction, bounds, horizontal);
            return null;
          },
        ),
        _ResetSplitIntent: CallbackAction<_ResetSplitIntent>(
          onInvoke: (intent) {
            _reset(bounds, horizontal);
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) {
        if (_focusHighlight != value) {
          setState(() => _focusHighlight = value);
        }
      },
      child: MouseRegion(
        cursor: horizontal
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.resizeUpDown,
        child: semanticDivider,
      ),
    );
  }
}

/// Screen-space bounds available to the two panes along the split axis.
class _PaneBounds {
  const _PaneBounds({
    required this.space,
    required this.minLeadExtent,
    required this.maxLeadExtent,
  });

  static const double _dividerExtent = AdaptiveSplitView.dividerExtent;
  static const double _floor = 96;

  /// Space left for both panes after the divider hit target.
  final double space;
  final double minLeadExtent;
  final double maxLeadExtent;

  double get minRatio => space <= 0 ? 0.5 : minLeadExtent / space;
  double get maxRatio => space <= 0 ? 0.5 : maxLeadExtent / space;

  /// Fits both requested minimums into [available], scaling proportionally
  /// with a 96dp floor before falling back to a plain proportional split.
  factory _PaneBounds.compute({
    required double available,
    required double minLeading,
    required double minTrailing,
  }) {
    final space = (available - _dividerExtent).clamp(0.0, double.infinity);
    if (space <= 0) {
      return const _PaneBounds(space: 0, minLeadExtent: 0, maxLeadExtent: 0);
    }

    var leading = minLeading;
    var trailing = minTrailing;
    if (leading + trailing > space) {
      final overflowTotal = leading + trailing;
      final scale = space / overflowTotal;
      final floor = _floor < space ? _floor : space;
      leading = (leading * scale).clamp(floor, space);
      trailing = (trailing * scale).clamp(floor, space);
      if (leading + trailing > space) {
        final total = leading + trailing;
        leading = space * leading / total;
        trailing = space - leading;
      }
    }

    final maxLeading = (space - trailing).clamp(leading, space);
    return _PaneBounds(
      space: space,
      minLeadExtent: leading,
      maxLeadExtent: maxLeading,
    );
  }
}

class _ResizeIntent extends Intent {
  const _ResizeIntent(this.fraction);

  final double fraction;
}

class _ResetSplitIntent extends Intent {
  const _ResetSplitIntent();
}
