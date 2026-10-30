import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final inProgress =
        ref.watch(inProgressSessionsProvider).value ??
        const <PracticeSession>[];
    final width = MediaQuery.sizeOf(context).width;

    return AppPage(
      title: 'question practice',
      subtitle: inProgress.isEmpty ? null : _pausedLabel(inProgress.length),
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.info_outline),
          tooltip: 'How to use question practice',
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
      padding: EdgeInsets.fromLTRB(
        width >= 600 ? 24 : 20,
        4,
        width >= 600 ? 24 : 20,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (inProgress.isNotEmpty) ...[
          for (final session in inProgress) ...[
            _ResumeCard(
              session: session,
              onResume: () => _resume(session.id),
              onDiscard: () => _discard(session.id),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
        ],
        _QuickActions(stats: stats, compact: width < 380),
        const SizedBox(height: 30),
        SectionTitle(
          'Topics',
          overline: 'Your library',
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
          _ShuffleBanner(
            starting: _starting,
            onStart: _startMixed,
            onDisable: () => _toggleShuffle(settings),
          ),
          const SizedBox(height: 14),
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
            return AppGroup(
              variant: M3ECardVariant.filled,
              children: [
                for (final summary in items)
                  _TopicRow(
                    summary: summary,
                    onPressed: () =>
                        _push(TopicPage(topicId: summary.topic.id)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _pausedLabel(int count) =>
      count == 1 ? '1 session paused' : '$count sessions paused';

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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.stats, required this.compact});

  final HomeStats? stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final due = stats?.dueErrors;
    final cards = stats?.unexportedCards;
    final pending = stats?.incompleteErrorCards ?? 0;
    final errors = _QuickTile(
      icon: Icons.error_outline,
      title: 'Review past errors',
      value: due?.toString() ?? '—',
      subtitle: stats == null
          ? 'Checking the queue…'
          : due == 0
          ? 'No errors are due yet'
          : '$due due after the 48-hour wait',
      tone: due != null && due > 0 ? PillTone.error : PillTone.primary,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const PastErrorsPage()),
      ),
    );
    final cardTile = _QuickTile(
      icon: Icons.style_outlined,
      title: 'Cards',
      value: cards?.toString() ?? '—',
      subtitle: stats == null
          ? 'Concepts, errors and basic cards'
          : cards == 0
          ? 'Nothing waiting to export'
          : '$cards cards ready to export',
      badge: pending > 0 ? '$pending pending' : null,
      tone: cards != null && cards > 0 ? PillTone.secondary : PillTone.neutral,
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => const CardsPage())),
    );
    if (compact) {
      return Column(children: [errors, const SizedBox(height: 10), cardTile]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: errors),
          const SizedBox(width: 12),
          Expanded(child: cardTile),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.tone,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final PillTone tone;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon, tone: tone, size: 42),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: theme.typography.emphasized.headlineMedium.copyWith(
                      color: tone == PillTone.error
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      height: 1,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Pill(badge!, tone: PillTone.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(title, style: theme.typography.baseline.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShuffleBanner extends StatelessWidget {
  const _ShuffleBanner({
    required this.starting,
    required this.onStart,
    required this.onDisable,
  });

  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shuffle,
                color: theme.colorScheme.onSecondaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shuffled practice',
                  style: theme.typography.emphasized.titleSmall.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.close),
                tooltip: 'Turn off shuffled practice',
                onPressed: onDisable,
              ),
            ],
          ),
          Text(
            'Questions from every topic, in a random order.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSecondaryContainer.withValues(
                alpha: 0.8,
              ),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            onPressed: starting ? null : onStart,
            label: starting ? 'Starting…' : 'Start shuffled practice',
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.play_circle_outline,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session in progress',
                      style: theme.typography.emphasized.titleSmall.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$mode · ${session.total} questions',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      'Started ${DateFormat.MMMd().add_Hm().format(session.startedAt.toLocal())}',
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Discard session',
                onPressed: onDiscard,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            onPressed: onResume,
            label: 'Resume',
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.summary, required this.onPressed});

  final TopicSummary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = (summary.accuracy * 100).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    summary.topic.priority == null
                        ? Icons.folder_outlined
                        : Icons.flag_outlined,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                summary.topic.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.baseline.titleMedium,
                              ),
                            ),
                            if (summary.dueErrorCount > 0) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                            ],
                          ],
                        ),
                        if (summary.topic.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary.topic.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (summary.topic.priority != null) ...[
                    Pill('P${summary.topic.priority}'),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      '${summary.practiceCount} practices · ${summary.relevantQuestionCount} questions',
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    summary.answeredCount == 0
                        ? 'Not started'
                        : '$accuracy% accuracy',
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: summary.answeredCount == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearScore(value: summary.progress),
            ],
          ),
        ),
      ),
    );
  }
}
