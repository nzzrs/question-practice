import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/topics/domain/topic_update_copy.dart';
import 'package:question_practice/features/topics/domain/topic_update_models.dart';

const _draft = QuestionDraft(
  prompt: 'Which port does HTTPS use?',
  alternatives: ['443', '80'],
  correctIndexes: [0],
  explanation: 'HTTPS uses 443 by default.',
  alternativeExplanations: ['Correct.', 'Port 80 is plain HTTP.'],
);

Question _deletedQuestion() {
  return const Question(
    id: 7,
    practiceId: 1,
    prompt: 'Old question?',
    alternatives: ['Yes', 'No'],
    correctIndexes: [0],
    explanation: 'Because.',
    alternativeExplanations: ['Yes.', 'No.'],
    position: 1,
  );
}

TopicUpdatePreview _preview(List<TopicPracticeUpdatePreview> practices) {
  return TopicUpdatePreview(
    topicId: 1,
    topicName: 'Cloud',
    fileName: 'cloud.json',
    practices: practices,
  );
}

void main() {
  test('summary uses plural nouns for zero counts', () {
    expect(
      topicUpdateSummary(_preview(const [])),
      'Topic updated: 0 new practices, 0 changed practices, '
      '0 new questions, 0 modified questions and 0 deleted questions.',
    );
  });

  test('summary keeps every noun singular for one row', () {
    final preview = _preview([
      const TopicPracticeUpdatePreview(
        name: 'New practice',
        description: '',
        contentHash: 'new',
        questions: [PracticeQuestionUpdate(question: _draft, position: 0)],
        deletedQuestions: [],
      ),
      TopicPracticeUpdatePreview(
        practiceId: 1,
        name: 'Core',
        description: '',
        contentHash: 'changed',
        questions: const [
          PracticeQuestionUpdate(
            question: _draft,
            position: 0,
            existingQuestionId: 1,
            changed: true,
          ),
        ],
        deletedQuestions: [_deletedQuestion()],
      ),
    ]);

    expect(
      topicUpdateSummary(preview),
      'Topic updated: 1 new practice, 1 changed practice, 1 new question, '
      '1 modified question and 1 deleted question.',
    );
  });

  test('summary uses plural nouns for several rows', () {
    final preview = _preview([
      const TopicPracticeUpdatePreview(
        name: 'New practice',
        description: '',
        contentHash: 'new',
        questions: [
          PracticeQuestionUpdate(question: _draft, position: 0),
          PracticeQuestionUpdate(question: _draft, position: 1),
        ],
        deletedQuestions: [],
      ),
      const TopicPracticeUpdatePreview(
        name: 'Another practice',
        description: '',
        contentHash: 'another',
        questions: [PracticeQuestionUpdate(question: _draft, position: 0)],
        deletedQuestions: [],
      ),
    ]);

    expect(
      topicUpdateSummary(preview),
      startsWith(
        'Topic updated: 2 new practices, 0 changed practices, '
        '3 new questions',
      ),
    );
  });
}
