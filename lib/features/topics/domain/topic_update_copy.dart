import '../../../core/domain/plural.dart';
import 'topic_update_models.dart';

/// Snack-bar summary shown after a topic file has been applied.
///
/// Every count carries its own noun so a single new or changed row never reads
/// as `1 new practices`.
String topicUpdateSummary(TopicUpdatePreview preview) {
  return 'Topic updated: '
      '${formatCount(preview.newPracticeCount, 'new practice')}, '
      '${formatCount(preview.modifiedPracticeCount, 'changed practice')}, '
      '${formatCount(preview.newQuestionCount, 'new question')}, '
      '${formatCount(preview.modifiedQuestionCount, 'modified question')} and '
      '${formatCount(preview.deletedQuestionCount, 'deleted question')}.';
}
