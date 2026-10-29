import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/web_launcher.dart';
import '../../core/ui/widgets.dart';
import 'lookup_sheet.dart';

/// Looks up [term] using the configured web or AI mode.
///
/// Every surface that renders selectable study text uses this helper so the
/// define action behaves the same in practice, review and card previews.
Future<void> openTermLookup(
  BuildContext context,
  WidgetRef ref, {
  required String term,
  required String question,
  required String topicName,
  required String practiceName,
  required int? sessionId,
  required int? questionId,
  Rect? anchor,
}) async {
  final settings = ref.read(settingsProvider).value ?? const AppSettings();
  if (settings.lookupMode == LookupMode.ai) {
    await showAiDefinitionBubble(
      context,
      term: term,
      question: question,
      topicName: topicName,
      practiceName: practiceName,
      sessionId: sessionId,
      questionId: questionId,
      anchor: anchor,
      onSearchWeb: () => openWebLookup(
        context,
        term: term,
        question: question,
        topicName: topicName,
        practiceName: practiceName,
        sessionId: sessionId,
        questionId: questionId,
      ),
    );
    return;
  }
  await openWebLookup(
    context,
    term: term,
    question: question,
    topicName: topicName,
    practiceName: practiceName,
    sessionId: sessionId,
    questionId: questionId,
  );
}

/// Opens the editable definition sheet for [term].
Future<void> openWebLookup(
  BuildContext context, {
  required String term,
  required String question,
  required String topicName,
  required String practiceName,
  required int? sessionId,
  required int? questionId,
}) async {
  await M3EBottomSheet.show<void>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => LookupSheet(
      term: term,
      question: question,
      topicName: topicName,
      practiceName: practiceName,
      sessionId: sessionId,
      questionId: questionId,
    ),
  );
}

/// Opens an http(s) link found in study text.
Future<void> openStudyUrl(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  try {
    await ref.read(webLauncherProvider).open(uri);
  } on WebLaunchException {
    if (context.mounted) {
      await showSnack(context, 'Could not open that link.');
    }
  }
}
