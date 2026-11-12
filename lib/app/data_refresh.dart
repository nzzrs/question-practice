import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Refreshes every provider that reads local data.
///
/// Used after any operation that replaces the whole database, such as a backup
/// restore or **Erase all data**. Keeping the list here prevents a screen from
/// keeping a topic, card or session snapshot from before the replacement.
void refreshDataProviders(WidgetRef ref) {
  ref.invalidate(settingsProvider);
  ref.invalidate(hasApiKeyProvider);
  ref.invalidate(topicSummariesProvider);
  ref.invalidate(archivedTopicSummariesProvider);
  ref.invalidate(topicSummaryProvider);
  ref.invalidate(topicPracticeSortProvider);
  ref.invalidate(homeTopicSortProvider);
  ref.invalidate(practiceSummariesProvider);
  ref.invalidate(topicProgressProvider);
  ref.invalidate(topicSubtopicStatsProvider);
  ref.invalidate(homeStatsProvider);
  ref.invalidate(dueErrorsProvider);
  ref.invalidate(resolvedErrorsProvider);
  ref.invalidate(errorsNeedingDetailsProvider);
  ref.invalidate(conceptsProvider);
  ref.invalidate(allConceptsProvider);
  ref.invalidate(errorCardsProvider);
  ref.invalidate(allErrorCardsProvider);
  ref.invalidate(manualCardsProvider);
  ref.invalidate(allManualCardsProvider);
  ref.invalidate(skippedQuestionsProvider);
  ref.invalidate(highlightsProvider);
  ref.invalidate(inProgressSessionProvider);
  ref.invalidate(inProgressSessionsProvider);
}
