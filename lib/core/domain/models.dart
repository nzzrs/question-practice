import 'package:meta/meta.dart';

enum SessionMode { practice, mixed, pastErrors }

enum SessionStatus { inProgress, completed, abandoned }

enum ConceptSource { ai, web, manual }

enum ErrorCardStatus { active, resolved }

enum LookupMode { ai, web }

enum WebEngine { duckDuckGo, wikipedia }

enum AiProvider { openai, groq, openRouter, gemini, custom }

@immutable
class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.ankiDeck,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final int? priority;
  final String? ankiDeck;
  final DateTime createdAt;

  Topic copyWith({
    String? name,
    String? description,
    int? priority,
    String? ankiDeck,
    bool clearPriority = false,
    bool clearAnkiDeck = false,
  }) {
    return Topic(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: clearPriority ? null : (priority ?? this.priority),
      ankiDeck: clearAnkiDeck ? null : (ankiDeck ?? this.ankiDeck),
      createdAt: createdAt,
    );
  }
}

@immutable
class Practice {
  const Practice({
    required this.id,
    required this.topicId,
    required this.name,
    required this.description,
    required this.contentHash,
    required this.importedAt,
    this.isDone = false,
  });

  final int id;
  final int topicId;
  final String name;
  final String description;
  final String contentHash;
  final DateTime importedAt;
  final bool isDone;
}

@immutable
class Question {
  const Question({
    required this.id,
    required this.practiceId,
    required this.prompt,
    required this.alternatives,
    required this.correctIndexes,
    required this.explanation,
    required this.alternativeExplanations,
    required this.position,
  });

  final int id;
  final int practiceId;
  final String prompt;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final String explanation;
  final List<String> alternativeExplanations;
  final int position;

  bool get allowsMultiple => correctIndexes.length > 1;
  int get correctIndex => correctIndexes.isEmpty ? -1 : correctIndexes.first;
  bool isCorrectSelection(Iterable<int> selected) =>
      _sameIndexes(correctIndexes, selected);

  List<String> get correctAnswers => [
    for (final index in correctIndexes)
      if (index >= 0 && index < alternatives.length) alternatives[index],
  ];

  String get correctAnswer => correctAnswers.join('; ');
}

@immutable
class QuestionDraft {
  const QuestionDraft({
    required this.prompt,
    required this.alternatives,
    required this.correctIndexes,
    required this.explanation,
    required this.alternativeExplanations,
  });

  final String prompt;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final String explanation;
  final List<String> alternativeExplanations;
}

@immutable
class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.practiceId,
    required this.mode,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.total,
    required this.correct,
    required this.skipped,
    required this.distracted,
    this.topicName = '',
    this.practiceName = '',
    this.answeredCount = 0,
  });

  final int id;
  final int? practiceId;
  final SessionMode mode;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int total;
  final int correct;
  final int skipped;
  final int distracted;

  /// Filled for in-progress sessions so Home can name what is paused.
  final String topicName;
  final String practiceName;
  final int answeredCount;

  double get score => total == 0 ? 0 : correct / total;
  int get wrong => total - correct - skipped;
}

@immutable
class Attempt {
  const Attempt({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.selectedIndexes,
    required this.reasoning,
    required this.distracted,
    required this.isCorrect,
    required this.answeredAt,
  });

  final int id;
  final int sessionId;
  final int questionId;
  final List<int> selectedIndexes;
  final String reasoning;
  final bool distracted;
  final bool isCorrect;
  final DateTime answeredAt;

  bool get isSkipped => selectedIndexes.isEmpty;
  int? get selectedIndex =>
      selectedIndexes.isEmpty ? null : selectedIndexes.first;
}

@immutable
class TopicSummary {
  const TopicSummary({
    required this.topic,
    required this.practiceCount,
    required this.questionCount,
    required this.attemptedQuestionCount,
    required this.unansweredQuestionCount,
    required this.answeredCount,
    required this.correctCount,
    required this.correctQuestionCount,
    required this.activeErrorCount,
    required this.dueErrorCount,
    required this.sessionCount,
    required this.lastPracticedAt,
  });

  final Topic topic;
  final int practiceCount;
  final int questionCount;
  final int attemptedQuestionCount;
  final int unansweredQuestionCount;
  final int answeredCount;
  final int correctCount;
  final int correctQuestionCount;
  final int activeErrorCount;
  final int dueErrorCount;
  final int sessionCount;
  final DateTime? lastPracticedAt;

  int get relevantQuestionCount {
    final value = questionCount - unansweredQuestionCount;
    return value < 0 ? 0 : value;
  }

  double get accuracy => answeredCount == 0 ? 0 : correctCount / answeredCount;
  double get progress => relevantQuestionCount == 0
      ? 0
      : attemptedQuestionCount / relevantQuestionCount;
}

@immutable
class PracticeSummary {
  const PracticeSummary({
    required this.practice,
    required this.questionCount,
    required this.lastScore,
    this.inProgressSessionId,
  });

  final Practice practice;
  final int questionCount;
  final double? lastScore;
  final int? inProgressSessionId;

  bool get hasInProgressSession => inProgressSessionId != null;
}

@immutable
class TopicProgressPoint {
  const TopicProgressPoint({
    required this.sessionId,
    required this.finishedAt,
    required this.practiceName,
    required this.correct,
    required this.total,
  });

  final int sessionId;
  final DateTime finishedAt;
  final String practiceName;
  final int correct;
  final int total;

  double get score => total == 0 ? 0 : correct / total;
}

@immutable
class HomeStats {
  const HomeStats({
    required this.dueErrors,
    required this.activeErrors,
    required this.incompleteErrorCards,
    required this.unexportedCards,
    required this.inProgressSessionId,
    required this.inProgressSessionMode,
    required this.inProgressSessionTotal,
  });

  final int dueErrors;
  final int activeErrors;
  final int incompleteErrorCards;
  final int unexportedCards;
  final int? inProgressSessionId;
  final SessionMode? inProgressSessionMode;
  final int? inProgressSessionTotal;
}

@immutable
class Concept {
  const Concept({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.term,
    required this.definition,
    required this.context,
    required this.topicName,
    required this.source,
    required this.createdAt,
    required this.exportedAt,
  });

  final int id;
  final int? sessionId;
  final int? questionId;
  final String term;
  final String definition;
  final String context;
  final String topicName;
  final ConceptSource source;
  final DateTime createdAt;
  final DateTime? exportedAt;

  bool get needsDefinition => definition.trim().isEmpty;
  bool get isExportable => !needsDefinition;

  Concept copyWith({String? definition, DateTime? exportedAt}) {
    return Concept(
      id: id,
      sessionId: sessionId,
      questionId: questionId,
      term: term,
      definition: definition ?? this.definition,
      context: context,
      topicName: topicName,
      source: source,
      createdAt: createdAt,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }
}

@immutable
class ErrorCard {
  const ErrorCard({
    required this.id,
    required this.questionId,
    required this.sessionId,
    required this.question,
    required this.alternatives,
    required this.correctIndexes,
    required this.wrongIndexes,
    required this.reasoning,
    required this.explanation,
    required this.alternativeExplanations,
    required this.bias,
    required this.vaccine,
    required this.topicName,
    required this.practiceName,
    required this.status,
    required this.createdAt,
    required this.lastWrongAt,
    required this.dueAt,
    required this.detailsCompletedAt,
    required this.resolvedAt,
    required this.exportedAt,
  });

  final int id;
  final int questionId;
  final int? sessionId;
  final String question;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final List<int> wrongIndexes;
  final String reasoning;
  final String explanation;
  final List<String> alternativeExplanations;
  final String bias;
  final String vaccine;
  final String topicName;
  final String practiceName;
  final ErrorCardStatus status;
  final DateTime createdAt;
  final DateTime lastWrongAt;
  final DateTime dueAt;
  final DateTime? detailsCompletedAt;
  final DateTime? resolvedAt;
  final DateTime? exportedAt;

  bool get isResolved => status == ErrorCardStatus.resolved;
  bool get needsDetails => detailsCompletedAt == null;
  bool isDueAt(DateTime now) => !isResolved && !now.isBefore(dueAt);

  int? get correctIndex => correctIndexes.isEmpty ? null : correctIndexes.first;
  int? get wrongIndex => wrongIndexes.isEmpty ? null : wrongIndexes.first;

  List<String> get correctAnswers => [
    for (final index in correctIndexes)
      if (index >= 0 && index < alternatives.length) alternatives[index],
  ];
  List<String> get wrongAnswers => [
    for (final index in wrongIndexes)
      if (index >= 0 && index < alternatives.length) alternatives[index],
  ];

  String get correctAnswer => correctAnswers.join('; ');
  String get wrongAnswer => wrongAnswers.join('; ');
}

@immutable
class ManualCard {
  const ManualCard({
    required this.id,
    required this.sessionId,
    required this.question,
    required this.answer,
    required this.topicName,
    required this.createdAt,
    required this.exportedAt,
  });

  final int id;
  final int? sessionId;
  final String question;
  final String answer;
  final String topicName;
  final DateTime createdAt;
  final DateTime? exportedAt;
}

@immutable
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.lookupCount,
    required this.conceptCount,
    required this.errorCardsNeedingNotes,
  });

  final PracticeSession session;
  final int lookupCount;
  final int conceptCount;
  final int errorCardsNeedingNotes;

  int get wrongCount => session.total - session.correct - session.skipped;
  bool get hasReviewableIssues =>
      errorCardsNeedingNotes > 0 || session.skipped > 0;
}

@immutable
class AppSettings {
  const AppSettings({
    this.lookupMode = LookupMode.web,
    this.webEngine = WebEngine.duckDuckGo,
    this.aiProvider = AiProvider.openai,
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.aiModel = '',
    this.shuffleTopics = false,
    this.dynamicColor = true,
    this.soundsEnabled = true,
    this.ankiDeck = 'Question Practice',
  });

  final LookupMode lookupMode;
  final WebEngine webEngine;
  final AiProvider aiProvider;
  final String aiBaseUrl;
  final String aiModel;
  final bool shuffleTopics;
  final bool dynamicColor;
  final bool soundsEnabled;
  final String ankiDeck;

  AppSettings copyWith({
    LookupMode? lookupMode,
    WebEngine? webEngine,
    AiProvider? aiProvider,
    String? aiBaseUrl,
    String? aiModel,
    bool? shuffleTopics,
    bool? dynamicColor,
    bool? soundsEnabled,
    String? ankiDeck,
  }) {
    return AppSettings(
      lookupMode: lookupMode ?? this.lookupMode,
      webEngine: webEngine ?? this.webEngine,
      aiProvider: aiProvider ?? this.aiProvider,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiModel: aiModel ?? this.aiModel,
      shuffleTopics: shuffleTopics ?? this.shuffleTopics,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      ankiDeck: ankiDeck ?? this.ankiDeck,
    );
  }
}

bool _sameIndexes(Iterable<int> a, Iterable<int> b) {
  final left = a.toSet();
  final right = b.toSet();
  if (left.length != right.length) return false;
  return left.containsAll(right);
}
