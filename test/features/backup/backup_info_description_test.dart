import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/backup/domain/backup_service.dart';

BackupInfo _info({
  int topics = 0,
  int practices = 0,
  int questions = 0,
  int sessions = 0,
  int attempts = 0,
  int cards = 0,
  int skippedQuestions = 0,
  int notes = 0,
  int archivedTopics = 0,
}) {
  return BackupInfo(
    exportedAt: null,
    topics: topics,
    practices: practices,
    questions: questions,
    sessions: sessions,
    attempts: attempts,
    concepts: cards,
    errorCards: 0,
    basicCards: 0,
    skippedQuestions: skippedQuestions,
    notes: notes,
    archivedTopics: archivedTopics,
  );
}

void main() {
  test('description pluralizes every count', () {
    expect(
      _info().description,
      '0 topics, 0 practices, 0 questions, 0 sessions, 0 answers and 0 cards',
    );
    expect(
      _info(
        topics: 1,
        practices: 1,
        questions: 1,
        sessions: 1,
        attempts: 1,
        cards: 1,
      ).description,
      '1 topic, 1 practice, 1 question, 1 session, 1 answer and 1 card',
    );
    expect(
      _info(
        topics: 2,
        practices: 3,
        questions: 4,
        sessions: 5,
        attempts: 6,
        cards: 7,
      ).description,
      '2 topics, 3 practices, 4 questions, 5 sessions, 6 answers and 7 cards',
    );
  });

  test('archived topics and extra counts keep their noun singular', () {
    final description = _info(
      topics: 2,
      archivedTopics: 2,
      skippedQuestions: 1,
      notes: 1,
    ).description;

    expect(description, contains('2 topics (2 archived topics)'));
    expect(description, contains('1 skipped question'));
    expect(description, contains('1 note'));
    expect(description, isNot(contains('archiveds')));
    expect(description, isNot(contains('1 notes')));
    expect(description, isNot(contains('1 skipped questions')));

    expect(
      _info(topics: 1, archivedTopics: 1).description,
      startsWith('1 topic (1 archived topic)'),
    );
  });
}
