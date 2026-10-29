import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../errors/past_errors_page.dart';
import '../export/cards_page.dart';
import '../help/help_page.dart';
import '../import/import_page.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import '../settings/settings_page.dart';
import '../topics/topic_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicSummariesProvider);
    final stats = ref.watch(homeStatsProvider).value;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final inProgress = ref.watch(inProgressSessionProvider).value;

    return AppScaffold(
      title: 'Question Practice',
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.info_outline),
          tooltip: 'How to use Question Practice',
          onPressed: () => _push(const HelpPage()),
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => _push(const SettingsPage()),
        ),
      ],
      floatingActionButton: M3EExtendedFab(
        label: 'Import',
        icon: const Icon(Icons.add),
        onPressed: () => _push(const ImportPage()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (inProgress != null) ...[
            _ResumeCard(
              session: inProgress,
              onResume: () => _resume(inProgress.id),
              onDiscard: () => _discard(inProgress.id),
            ),
            const SizedBox(height: 12),
          ],
          _QuickAction(
            icon: Icons.error_outline,
            title: 'Review past errors',
            subtitle: stats == null
                ? 'Checking the queue…'
                : stats.dueErrors == 0
                ? 'No errors are due yet'
                : '${stats.dueErrors} due after the 48-hour wait',
            badge: stats?.dueErrors.toString(),
            onPressed: () => _push(const PastErrorsPage()),
          ),
          const SizedBox(height: 8),
          _QuickAction(
            icon: Icons.style_outlined,
            title: 'Cards',
            subtitle: stats == null
                ? 'Concepts, errors and basic cards'
                : stats.unexportedCards == 0
                ? 'Nothing waiting to export'
                : '${stats.unexportedCards} cards ready to export',
            badge: stats == null ? null : stats.unexportedCards.toString(),
            onPressed: () => _push(const CardsPage()),
          ),
          const SizedBox(height: 28),
          SectionTitle(
            'Topics',
            trailing: M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.shuffle),
              selectedIcon: const Icon(Icons.shuffle_on_outlined),
              isSelected: settings.shuffleTopics,
              tooltip: settings.shuffleTopics
                  ? 'Disable shuffled practice'
                  : 'Shuffle topics into one practice',
              onPressed: () => _toggleShuffle(settings),
            ),
          ),
          if (settings.shuffleTopics) ...[
            M3EButton.filled(
              onPressed: _starting ? null : _startMixed,
              icon: const Icon(Icons.shuffle),
              label: Text(_starting ? 'Starting…' : 'Start shuffled practice'),
            ),
            const SizedBox(height: 8),
            Text(
              'Questions from every topic, in a random order.',
              style: M3ETheme.of(context).typography.baseline.bodySmall
                  .copyWith(
                    color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
          ],
          topics.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: M3ELoadingIndicator()),
            ),
            error: (error, stackTrace) => EmptyState(
              icon: Icons.warning_amber_outlined,
              title: 'Could not load topics',
              message: '$error',
              action: M3EButton.text(
                onPressed: () => ref.invalidate(topicSummariesProvider),
                child: const Text('Try again'),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.library_books_outlined,
                  title: 'No practices yet',
                  message:
                      'Import a JSON practice file to create your first topic.',
                  action: M3EButton.filled(
                    onPressed: () => _push(const ImportPage()),
                    child: const Text('Import a practice'),
                  ),
                );
              }
              return Column(
                children: [
                  for (final summary in items) ...[
                    _TopicCard(
                      summary: summary,
                      onPressed: () =>
                          _push(TopicPage(topicId: summary.topic.id)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => page));
  }

  Future<void> _toggleShuffle(AppSettings settings) async {
    await ref
        .read(settingsRepositoryProvider)
        .save(settings.copyWith(shuffleTopics: !settings.shuffleTopics));
  }

  Future<void> _startMixed() async {
    setState(() => _starting = true);
    try {
      final start = ref.read(sessionServiceProvider);
      final session = await start.startMixed();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SessionPage(start: session),
        ),
      );
    } on SessionException catch (error) {
      if (mounted) {
        await showSnack(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _resume(int id) async {
    try {
      final start = await ref.read(sessionServiceProvider).resume(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SessionPage(start: start),
        ),
      );
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    }
  }

  Future<void> _discard(int id) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Discard session?',
      message: 'The answers and error cards from this unfinished session will be deleted.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(sessionServiceProvider).discard(id);
    if (mounted) ref.invalidate(homeStatsProvider);
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.session,
    required this.onResume,
    required this.onDiscard,
  });

  final PracticeSession session;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final mode = switch (session.mode) {
      SessionMode.mixed => 'Shuffled practice',
      SessionMode.pastErrors => 'Past errors',
      SessionMode.practice => 'Practice',
    };
    return TonalBox(
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session in progress',
            style: theme.typography.emphasized.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('$mode · ${session.total} questions'),
          const SizedBox(height: 12),
          Row(
            children: [
              M3EButton.filled(
                onPressed: onResume,
                child: const Text('Resume'),
              ),
              const SizedBox(width: 8),
              M3EButton.text(
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return M3ECard(
      variant: M3ECardVariant.filled,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.typography.emphasized.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: theme.typography.baseline.labelMedium.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.summary, required this.onPressed});

  final TopicSummary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = (summary.accuracy * 100).round();
    return M3ECard(
      variant: M3ECardVariant.outlined,
      onPressed: onPressed,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (summary.topic.priority != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'P${summary.topic.priority}',
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  summary.topic.name,
                  style: theme.typography.emphasized.titleMedium,
                ),
              ),
              if (summary.dueErrorCount > 0)
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (summary.topic.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary.topic.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${summary.practiceCount} practices · ${summary.questionCount} questions',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                summary.answeredCount == 0
                    ? 'Not started'
                    : '$accuracy% accuracy',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearScore(value: summary.progress),
        ],
      ),
    );
  }
}
