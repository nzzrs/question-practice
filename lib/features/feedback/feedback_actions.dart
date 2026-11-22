import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Selection and note callbacks shared by practice feedback and error review.
class FeedbackActions {
  const FeedbackActions({
    required this.onDefine,
    required this.onOpenUrl,
    this.onAsk,
    this.onSaveNote,
    this.onNoteTap,
  });

  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String selection, Rect? anchor)? onAsk;
  final Future<void> Function(String selection, Rect? anchor)? onSaveNote;
  final ValueChanged<String>? onNoteTap;
}
