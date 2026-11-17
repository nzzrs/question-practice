import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../export/new_card_dialog.dart';

/// Opens the manual card dialog for [highlight] and stores the chosen card.
///
/// Returns the number of cards created: `0` when the learner cancels the
/// dialog, otherwise `1` for the concept or basic card. The highlight is marked
/// converted once the card exists, so every review surface can hide its
/// card-making actions afterwards.
Future<int> convertHighlightToCard(
  BuildContext context,
  WidgetRef ref,
  StudyHighlight highlight,
) async {
  final draft = await showNewCardDialog(
    context,
    title: 'Turn the highlight into a card',
    contextText: highlight.context,
    initialTerm: highlight.text,
    initialQuestion: highlight.text,
    initialKind: NewCardKind.concept,
  );
  if (draft == null) return 0;
  final service = ref.read(reviewServiceProvider);
  if (draft.kind == NewCardKind.concept) {
    await service.createConcept(
      sessionId: highlight.sessionId,
      questionId: highlight.questionId,
      term: draft.term,
      definition: draft.definition,
      context: highlight.context,
      topicName: highlight.topicName,
      source: ConceptSource.manual,
    );
    await service.markHighlightConverted(highlight.id);
  } else {
    final manualCardId = await service.createBasicCard(
      sessionId: highlight.sessionId,
      questionId: highlight.questionId,
      question: draft.question,
      answer: draft.answer,
      context: highlight.context,
      topicName: highlight.topicName,
    );
    await service.markHighlightConverted(
      highlight.id,
      manualCardId: manualCardId,
    );
  }
  if (context.mounted) {
    await showSnack(context, 'Card created from the highlight.');
  }
  return 1;
}
