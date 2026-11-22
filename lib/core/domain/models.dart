import 'dart:convert';

import 'package:meta/meta.dart';

enum SessionMode { practice, mixed, pastErrors }

enum SessionStatus { inProgress, completed, abandoned }

enum ConceptSource { ai, web, manual }

enum ErrorCardStatus { active, resolved }

enum LookupMode { ai, web }

enum WebEngine { duckDuckGo, wikipedia }

enum AiProvider { openai, groq, openRouter, gemini, custom }

/// The cognitive shape a card tests.
enum CognitiveType {
  fact('Fact'),
  heuristic('Scenario and rule'),
  procedure('Steps'),
  contrast('Contrast'),
  concept('Concept');

  const CognitiveType(this.label);

  final String label;

  static CognitiveType fromName(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return CognitiveType.fact;
  }
}

/// The authoring shape a card is written in inside the card creator.
///
/// A template codes how the front and back are phrased. The exact template is
/// not stored: after saving, [cognitiveType] carries the pedagogical shape and
/// the Definition template becomes a [Concept].
enum CardTemplate {
  definition('Definition', 'Definition', CognitiveType.concept),
  contrast('Contrast', 'Contrast', CognitiveType.contrast),
  mechanism('Cause and effect', 'Cause and effect', CognitiveType.fact),
  heuristic('Scenario and rule', 'Scenario and rule', CognitiveType.heuristic),
  procedure('Steps', 'Steps', CognitiveType.procedure);

  const CardTemplate(this.label, this.chipLabel, this.cognitiveType);

  /// Short name for quality rows and group headers.
  final String label;

  /// Name shown in the template picker and AI suggestion rows.
  final String chipLabel;

  /// The stored shape after the card is saved.
  final CognitiveType cognitiveType;
}

/// A one-tap classification of why an answer was wrong.
///
/// Legacy data only: practice now keeps free-form wrong-answer bullets. The
/// enum and its columns remain so older backups and cards still render.
enum MistakeKind {
  forgottenFact('Forgotten fact'),
  confusion('Confusion between 2 options'),
  misinterpretation('Misinterpretation'),
  distraction('Distraction');

  const MistakeKind(this.label);

  final String label;

  static MistakeKind? fromName(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// Why a mistake happened, in a stable order.
List<MistakeKind> mistakeKindsFromJson(String value) {
  final parsed = <MistakeKind>[];
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      for (final item in decoded) {
        final kind = item is String ? MistakeKind.fromName(item) : null;
        if (kind != null && !parsed.contains(kind)) parsed.add(kind);
      }
    }
  } on FormatException {
    return parsed;
  }
  return parsed;
}

String mistakeKindsToJson(Iterable<MistakeKind> kinds) {
  final values = <String>[
    for (final kind in MistakeKind.values)
      if (kinds.contains(kind)) kind.name,
  ];
  return jsonEncode(values);
}

@immutable
class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.ankiDeck,
    required this.createdAt,
    this.minimumScore = 70,
    this.targetScore = 80,
    this.archived = false,
  });

  final int id;
  final String name;
  final String description;
  final int? priority;
  final String? ankiDeck;
  final DateTime createdAt;

  /// Percentage below which a score counts as failing this topic.
  final int minimumScore;

  /// Percentage at which a score counts as meeting the topic goal.
  final int targetScore;

  /// Archived topics keep all their data but stay out of the normal list.
  final bool archived;

  Topic copyWith({
    String? name,
    String? description,
    int? priority,
    String? ankiDeck,
    int? minimumScore,
    int? targetScore,
    bool? archived,
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
      minimumScore: minimumScore ?? this.minimumScore,
      targetScore: targetScore ?? this.targetScore,
      archived: archived ?? this.archived,
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
    this.subtopic = '',
  });

  final int id;
  final int practiceId;
  final String prompt;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final String explanation;
  final List<String> alternativeExplanations;
  final int position;

  /// Optional grouping inside a practice. Empty means uncategorized.
  final String subtopic;

  bool get hasSubtopic => subtopic.trim().isNotEmpty;
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
    this.subtopic = '',
    this.sourceId = '',
  });

  final String prompt;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final String explanation;
  final List<String> alternativeExplanations;
  final String subtopic;

  /// Stable identity from an exported practice file.
  ///
  /// Empty for files imported without question identities. The value is used
  /// only while updating a practice; it is not stored in the database.
  final String sourceId;
}

/// One practice from a topic update file and how it maps to stored rows.
@immutable
class TopicPracticeUpdate {
  const TopicPracticeUpdate({
    required this.name,
    required this.description,
    required this.questions,
    required this.deletedQuestionIds,
    required this.contentHash,
    this.existingPracticeId,
    this.changed = true,
  });

  /// The stored practice this row updates, or null for a new practice.
  final int? existingPracticeId;
  final String name;
  final String description;
  final List<PracticeQuestionUpdate> questions;
  final List<int> deletedQuestionIds;
  final String contentHash;

  /// Whether an existing practice needs any write; new practices always do.
  final bool changed;

  bool get isNew => existingPracticeId == null;
}

/// One question from an update file, at its new position in the practice.
@immutable
class PracticeQuestionUpdate {
  const PracticeQuestionUpdate({
    required this.question,
    required this.position,
    this.existingQuestionId,
    this.changed = false,
  });

  /// The stored question this row maps to, or null for a new question.
  final int? existingQuestionId;
  final QuestionDraft question;
  final int position;

  /// Whether a matched question's visible content differs from the file.
  final bool changed;

  bool get isNew => existingQuestionId == null;
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
    required this.unknown,
    required this.isCorrect,
    required this.answeredAt,
    this.mistakeKinds = const [],
  });

  final int id;
  final int sessionId;
  final int questionId;
  final List<int> selectedIndexes;
  final String reasoning;
  final bool distracted;

  /// The learner marked the wrong answer as "I didn't know this".
  ///
  /// Such an answer counts as skipped and creates no error card.
  final bool unknown;
  final bool isCorrect;
  final DateTime answeredAt;

  /// Legacy one-tap classifications chosen after a wrong answer.
  final List<MistakeKind> mistakeKinds;

  bool get isSkipped => selectedIndexes.isEmpty || unknown;
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

/// Correct share of a topic's most recent answered questions.
@immutable
class TopicReadiness {
  const TopicReadiness({
    required this.correctCount,
    required this.answeredCount,
  });

  final int correctCount;
  final int answeredCount;

  bool get hasAnswers => answeredCount > 0;

  /// A value from 0 to 1; zero when no question was answered.
  double get value => answeredCount == 0 ? 0 : correctCount / answeredCount;
}

@immutable
class SubtopicStat {
  const SubtopicStat({
    required this.subtopic,
    required this.questionCount,
    required this.attemptedQuestionCount,
    required this.answeredCount,
    required this.correctCount,
  });

  /// Empty when the questions have no subtopic assigned.
  final String subtopic;
  final int questionCount;
  final int attemptedQuestionCount;
  final int answeredCount;
  final int correctCount;

  bool get isUncategorized => subtopic.trim().isEmpty;
  String get label => isUncategorized ? 'Uncategorized' : subtopic;
  double get accuracy => answeredCount == 0 ? 0 : correctCount / answeredCount;
  double get progress =>
      questionCount == 0 ? 0 : attemptedQuestionCount / questionCount;
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
    required this.extra,
    required this.context,
    required this.topicName,
    required this.source,
    required this.createdAt,
    required this.exportedAt,
    this.subtopic = '',
  });

  final int id;
  final int? sessionId;
  final int? questionId;
  final String term;
  final String definition;

  /// Acronym expansion shown in the Anki extra field, when the term is one.
  final String extra;
  final String context;
  final String topicName;

  /// Optional grouping inside the topic, copied from the source question.
  final String subtopic;
  final ConceptSource source;
  final DateTime createdAt;
  final DateTime? exportedAt;

  bool get needsDefinition => definition.trim().isEmpty;
  bool get isExportable => !needsDefinition;

  Concept copyWith({String? definition, String? extra, DateTime? exportedAt}) {
    return Concept(
      id: id,
      sessionId: sessionId,
      questionId: questionId,
      term: term,
      definition: definition ?? this.definition,
      extra: extra ?? this.extra,
      context: context,
      topicName: topicName,
      subtopic: subtopic,
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
    this.cognitiveType = CognitiveType.contrast,
    this.subtopic = '',
    this.mistakeKinds = const [],
    this.distracted = false,
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

  /// Cognitive shape of the card generated from this error.
  final CognitiveType cognitiveType;

  /// Optional grouping inside the topic, copied from the source question.
  final String subtopic;

  /// Legacy quick classifications chosen after the wrong answer.
  final List<MistakeKind> mistakeKinds;

  /// A distracted re-test kept this card due instead of counting a new error.
  final bool distracted;

  bool get isResolved => status == ErrorCardStatus.resolved;

  /// Whether the learner has completed the card's details at least once.
  bool get hasCompletedDetails => detailsCompletedAt != null;

  /// Whether the card needs the learner's review again.
  ///
  /// A card is pending when its details were never completed, or when the
  /// question was missed again after the last completed review. Exporting a
  /// card does not clear or set this state. The field name is kept for the
  /// existing Cards flow, which uses it for the review badge and selection.
  bool get needsDetails =>
      detailsCompletedAt == null || lastWrongAt.isAfter(detailsCompletedAt!);

  /// Alias that names the pending state without implying missing notes.
  bool get needsReview => needsDetails;

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
    this.questionId,
    this.context = '',
    this.cognitiveType = CognitiveType.fact,
    this.subtopic = '',
  });

  final int id;
  final int? sessionId;
  final int? questionId;
  final String question;
  final String answer;

  /// Passage shown above the question on the card front, when one exists.
  final String context;
  final String topicName;
  final DateTime createdAt;
  final DateTime? exportedAt;

  /// Cognitive shape of the card: fact, scenario and rule, steps, contrast or
  /// concept.
  final CognitiveType cognitiveType;

  /// Optional grouping inside the topic, copied from the source question.
  final String subtopic;
}

@immutable
class SkippedQuestion {
  const SkippedQuestion({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.question,
    required this.alternatives,
    required this.correctIndexes,
    required this.explanation,
    required this.alternativeExplanations,
    required this.reasoning,
    required this.topicName,
    required this.practiceName,
    required this.unknown,
    required this.createdAt,
    required this.handledAt,
    required this.handledKind,
  });

  final int id;
  final int? sessionId;
  final int questionId;
  final String question;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final String explanation;
  final List<String> alternativeExplanations;
  final String reasoning;
  final String topicName;
  final String practiceName;
  final bool unknown;
  final DateTime createdAt;
  final DateTime? handledAt;
  final String? handledKind;

  bool get isHandled => handledAt != null;

  List<String> get correctAnswers => [
    for (final index in correctIndexes)
      if (index >= 0 && index < alternatives.length) alternatives[index],
  ];

  String get correctAnswer => correctAnswers.join('; ');
}

/// A passage the learner saved from a question.
@immutable
class Note {
  const Note({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.text,
    required this.context,
    required this.topicName,
    required this.practiceName,
    required this.createdAt,
    required this.keptAt,
    required this.cardCreatedAt,
    required this.manualCardId,
    this.subtopic = '',
  });

  final int id;
  final int? sessionId;
  final int? questionId;
  final String text;
  final String context;
  final String topicName;
  final String practiceName;
  final DateTime createdAt;
  final DateTime? keptAt;
  final DateTime? cardCreatedAt;
  final int? manualCardId;

  /// Optional grouping inside the topic, copied from the source question.
  final String subtopic;

  bool get isKept => keptAt != null;
  bool get hasCard => cardCreatedAt != null;
  bool get needsReview => !isKept && !hasCard;
}

/// One atomic front/back variant proposed by the AI.
@immutable
class SuggestedCard {
  const SuggestedCard({
    required this.front,
    required this.back,
    required this.template,
    this.variantIndex = 0,
  });

  final String front;
  final String back;
  final CardTemplate template;

  /// Zero-based position of this variant inside its idea.
  final int variantIndex;

  CognitiveType get cognitiveType => template.cognitiveType;
}

/// One AI idea with one to three wording variants of the same fact.
@immutable
class SuggestedCardIdea {
  const SuggestedCardIdea({required this.template, required this.variants});

  final CardTemplate template;
  final List<SuggestedCard> variants;
}

@immutable
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.lookupCount,
    required this.conceptCount,
    required this.errorCardsNeedingReview,
  });

  final PracticeSession session;
  final int lookupCount;
  final int conceptCount;

  /// Error cards missed in this session that still need review.
  ///
  /// Derived from this session's wrong attempts, not from the session that
  /// originally created each card, so a repeated error is counted here.
  final int errorCardsNeedingReview;

  int get wrongCount => session.total - session.correct - session.skipped;
  bool get hasReviewableIssues =>
      errorCardsNeedingReview > 0 || session.skipped > 0;
}

@immutable
class AppSettings {
  const AppSettings({
    this.lookupMode = LookupMode.web,
    this.webEngine = WebEngine.duckDuckGo,
    this.aiProvider = AiProvider.openai,
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.aiModel = '',
    this.dynamicColor = true,
    this.soundsEnabled = true,
    this.soundVolume = 0.85,
    this.ankiDeck = 'Question Practice',
  });

  final LookupMode lookupMode;
  final WebEngine webEngine;
  final AiProvider aiProvider;
  final String aiBaseUrl;
  final String aiModel;
  final bool dynamicColor;
  final bool soundsEnabled;

  /// Playback volume from 0 to 1 for practice sound effects.
  final double soundVolume;
  final String ankiDeck;

  AppSettings copyWith({
    LookupMode? lookupMode,
    WebEngine? webEngine,
    AiProvider? aiProvider,
    String? aiBaseUrl,
    String? aiModel,
    bool? dynamicColor,
    bool? soundsEnabled,
    double? soundVolume,
    String? ankiDeck,
  }) {
    return AppSettings(
      lookupMode: lookupMode ?? this.lookupMode,
      webEngine: webEngine ?? this.webEngine,
      aiProvider: aiProvider ?? this.aiProvider,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiModel: aiModel ?? this.aiModel,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
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
