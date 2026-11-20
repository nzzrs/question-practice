import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/new_card_dialog.dart';

/// Opens the concept card dialog for [highlight] and stores the chosen card.
///
/// Returns the number of cards created: `0` when the learner cancels the
/// dialog, otherwise `1`. The highlight flow only creates concept cards;
/// structured facts and heuristics come from Suggest cards with AI. The
/// highlight is marked converted once the card exists, so every review surface
/// can hide its card-making actions afterwards.
Future<int> convertHighlightToCard(
  BuildContext context,
  WidgetRef ref,
  StudyHighlight highlight,
) async {
  final draft = await showNewCardDialog(
    context,
    title: 'Turn the note into a concept card',
    contextText: highlight.context,
    initialTerm: highlight.text,
    initialKind: NewCardKind.concept,
    lockedKind: NewCardKind.concept,
  );
  if (draft == null) return 0;
  final service = ref.read(reviewServiceProvider);
  await service.createConcept(
    sessionId: highlight.sessionId,
    questionId: highlight.questionId,
    term: draft.term,
    definition: draft.definition,
    context: highlight.context,
    topicName: highlight.topicName,
    subtopic: highlight.subtopic,
    source: ConceptSource.manual,
  );
  await service.markHighlightConverted(highlight.id);
  if (context.mounted) {
    await showSnack(context, 'Concept card created from the note.');
  }
  return 1;
}
