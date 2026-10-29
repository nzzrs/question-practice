import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/data/card_repository.dart';
import '../core/data/practice_repository.dart';
import '../core/data/session_repository.dart';
import '../core/data/settings_repository.dart';
import '../core/database/app_database.dart';
import '../core/domain/models.dart';
import '../core/platform/anki_gateway.dart';
import '../core/platform/secure_key_store.dart';
import '../core/platform/web_launcher.dart';
import '../features/export/domain/export_service.dart';
import '../features/import/domain/import_service.dart';
import '../features/lookup/domain/lookup_service.dart';
import '../features/practice/domain/session_service.dart';
import '../features/review/domain/review_service.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => const Clock());

final topicRepositoryProvider = Provider<PracticeRepository>(
  (ref) =>
      PracticeRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) =>
      CardRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => FlutterSecureKeyStore(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(databaseProvider).settingsDao,
    ref.watch(secureKeyStoreProvider),
  ),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

final hasApiKeyProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).hasApiKey(),
);

final homeStatsProvider = StreamProvider<HomeStats>(
  (ref) => ref.watch(topicRepositoryProvider).watchHomeStats(),
);

final topicSummariesProvider = StreamProvider<List<TopicSummary>>(
  (ref) => ref.watch(topicRepositoryProvider).watchTopicSummaries(),
);

final topicSummaryProvider = StreamProvider.family<TopicSummary?, int>(
  (ref, topicId) =>
      ref.watch(topicRepositoryProvider).watchTopicSummary(topicId),
);

final practiceSummariesProvider =
    StreamProvider.family<List<PracticeSummary>, int>(
      (ref, topicId) =>
          ref.watch(topicRepositoryProvider).watchPracticeSummaries(topicId),
    );

final inProgressSessionProvider = StreamProvider<PracticeSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchLatestInProgress(),
);

final dueErrorsProvider = StreamProvider<List<ErrorCard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchDueErrors(),
);

final resolvedErrorsProvider = StreamProvider<List<ErrorCard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchResolvedErrors(),
);

final errorsNeedingDetailsProvider = StreamProvider<List<ErrorCard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchErrorsNeedingDetails(),
);

final conceptsProvider = StreamProvider<List<Concept>>(
  (ref) => ref.watch(cardRepositoryProvider).watchConcepts(),
);

final allConceptsProvider = StreamProvider<List<Concept>>(
  (ref) =>
      ref.watch(cardRepositoryProvider).watchConcepts(includeExported: true),
);

final errorCardsProvider = StreamProvider<List<ErrorCard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchErrorCards(),
);

final allErrorCardsProvider = StreamProvider<List<ErrorCard>>(
  (ref) =>
      ref.watch(cardRepositoryProvider).watchErrorCards(includeExported: true),
);

final manualCardsProvider = StreamProvider<List<ManualCard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchManualCards(),
);

final allManualCardsProvider = StreamProvider<List<ManualCard>>(
  (ref) =>
      ref.watch(cardRepositoryProvider).watchManualCards(includeExported: true),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final webLauncherProvider = Provider<WebLauncher>(
  (ref) => CustomTabWebLauncher(),
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(
    repository: ref.watch(topicRepositoryProvider),
    clock: ref.watch(clockProvider),
    bundle: rootBundle,
  ),
);

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(
    practices: ref.watch(topicRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    cards: ref.watch(cardRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ReviewService(
    practices: ref.watch(topicRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    cards: ref.watch(cardRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final lookupServiceProvider = Provider<LookupService>(
  (ref) => LookupService(
    client: ref.watch(httpClientProvider),
    settings: ref.watch(settingsRepositoryProvider),
    keyStore: ref.watch(secureKeyStoreProvider),
    webLauncher: ref.watch(webLauncherProvider),
    cards: ref.watch(cardRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final ankiGatewayProvider = Provider<AnkiGateway>(
  (ref) => MethodChannelAnkiGateway(),
);

final ankiStatusProvider = FutureProvider<AnkiStatus>(
  (ref) => ref.watch(ankiGatewayProvider).status(),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    gateway: ref.watch(ankiGatewayProvider),
    cards: ref.watch(cardRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
