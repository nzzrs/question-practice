import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/practice_repository.dart';
import '../../../core/domain/progress_math.dart';

/// Writes a topic's statistics as a shareable JSON document.
///
/// The payload is derived from the same queries that feed the statistics
/// screen, so it always matches the visible figures.
class StatisticsExportService {
  StatisticsExportService({
    required PracticeRepository practices,
    required Clock clock,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(File file)? shareFile,
  }) : _practices = practices,
       _clock = clock,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareFile = shareFile ?? _shareWithSystem;

  static const appId = 'question_practice';
  static const kind = 'statistics';
  static const formatVersion = 1;

  final PracticeRepository _practices;
  final Clock _clock;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(File file) _shareFile;

  Future<Map<String, dynamic>> buildTopicPayload(int topicId) async {
    final summary = await _practices.watchTopicSummary(topicId).first;
    if (summary == null) {
      throw StateError('The topic no longer exists.');
    }
    final progress = await _practices.watchTopicProgress(topicId).first;
    final subtopics = await _practices.watchSubtopicStats(topicId).first;
    final fit = fitProgressBySession([
      for (final point in progress) point.score,
    ]);
    final learningRate = learningRatePercentagePointsPerWeek(progress);
    final hasSubtopics = subtopics.any((stat) => !stat.isUncategorized);

    return <String, dynamic>{
      'app': appId,
      'kind': kind,
      'formatVersion': formatVersion,
      'exportedAt': _clock.now().toUtc().toIso8601String(),
      'scope': <String, dynamic>{
        'kind': 'topic',
        'topicId': summary.topic.id,
        'topicName': summary.topic.name,
      },
      'summary': <String, dynamic>{
        'practiceCount': summary.practiceCount,
        'questionCount': summary.questionCount,
        'answeredCount': summary.answeredCount,
        'correctCount': summary.correctCount,
        'accuracy': summary.accuracy,
        'progress': summary.progress,
        'sessionCount': summary.sessionCount,
        'lastPracticedAt': summary.lastPracticedAt?.toIso8601String(),
      },
      'progress': <Map<String, dynamic>>[
        for (final point in progress)
          <String, dynamic>{
            'sessionId': point.sessionId,
            'finishedAt': point.finishedAt.toUtc().toIso8601String(),
            'practiceName': point.practiceName,
            'correct': point.correct,
            'total': point.total,
            'score': point.score,
          },
      ],
      'subtopics': hasSubtopics
          ? <Map<String, dynamic>>[
              for (final stat in subtopics)
                <String, dynamic>{
                  'subtopic': stat.label,
                  'questionCount': stat.questionCount,
                  'attemptedQuestionCount': stat.attemptedQuestionCount,
                  'answeredCount': stat.answeredCount,
                  'correctCount': stat.correctCount,
                  'accuracy': stat.accuracy,
                  'progress': stat.progress,
                },
            ]
          : <Map<String, dynamic>>[],
      'trend': <String, dynamic>{
        'sessionCount': progress.length,
        'regression': fit == null
            ? null
            : <String, dynamic>{'slope': fit.slope, 'intercept': fit.intercept},
        'learningRatePercentagePointsPerWeek': learningRate,
      },
    };
  }

  String encodeTopicPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> writeTopicStats(int topicId) async {
    final directory = await _temporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final file = File(
      p.join(
        directory.path,
        'question-practice-statistics-$topicId-$stamp.json',
      ),
    );
    await file.writeAsString(
      encodeTopicPayload(await buildTopicPayload(topicId)),
    );
    return file;
  }

  Future<File> shareTopicStats(int topicId) async {
    final file = await writeTopicStats(topicId);
    await _shareFile(file);
    return file;
  }

  static Future<void> _shareWithSystem(File file) {
    return SharePlus.instance.share(
      ShareParams(
        subject: 'Question Practice statistics',
        text: 'Topic statistics from Question Practice.',
        files: [XFile(file.path)],
      ),
    );
  }
}
