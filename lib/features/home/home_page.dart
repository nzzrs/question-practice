import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/list_sort.dart';
import '../../core/domain/models.dart';
import '../../core/domain/natural_compare.dart';
import '../../core/domain/plural.dart';
import '../../core/ui/sort_dialog.dart';
import '../../core/ui/widgets.dart';
import '../errors/past_errors_page.dart';
import '../export/cards_page.dart';
import '../help/help_page.dart';
import '../import/import_page.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import '../settings/settings_page.dart';
import '../topics/archived_topics_sheet.dart';
import '../topics/topic_actions.dart';
import '../topics/topic_page.dart';

/// Text scale from which Home switches to layouts that stack instead of
/// squeezing two columns side by side.
const _largeTextThreshold = 1.3;

bool _usesLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 >= _largeTextThreshold;

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
    final archived =
        ref.watch(archivedTopicSummariesProvider).value ??
        const <TopicSummary>[];
    final topicSort = ref.watch(homeTopicSortProvider).value;
    final stats = ref.watch(homeStatsProvider).value;
    final inProgress =
        ref.watch(inProgressSessionsProvider).value ??
        const <PracticeSession>[];
    final width = MediaQuery.sizeOf(context).width;
    final largeText = _usesLargeText(context);
    final theme = M3ETheme.of(context);

    return AppPage(
      title: 'Questions',
      // A large app bar cannot grow its fixed title band with the text scale,
      // so it overflows once the title is scaled up. The small bar keeps the
      // full title readable, and the paused count moves into the content.
      variant: largeText
          ? M3EAppBarVariant.small
          : M3EAppBarVariant.largeFlexible,
      subtitle: inProgress.isEmpty || largeText
          ? null
          : _pausedLabel(inProgress.length),
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.help_outline),
          tooltip: 'How to use Questions',
          onPressed: () => _push(const HelpPage()),
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => _push(const SettingsPage()),
        ),
      ],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          M3EFab(
            icon: const Icon(Icons.shuffle),
            size: M3EFabSize.regular,
            color: M3EFabColor.secondary,
            tooltip: 'Start shuffled practice',
            onPressed: _starting ? null : _showShuffleOptions,
          ),
          const SizedBox(height: 12),
          M3EExtendedFab(
            label: 'Import',
            icon: const Icon(Icons.add),
            onPressed: () => _push(const ImportPage()),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        width >= 600 ? 24 : 20,
        4,
        width >= 600 ? 24 : 20,
        188 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (inProgress.isNotEmpty) ...[
          if (largeText)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _pausedLabel(inProgress.length),
                style: theme.typography.baseline.labelLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
        _QuickActions(stats: stats, compact: width < 380 || largeText),
        const SizedBox(height: 30),
        SectionTitle(
          'Topics',
          overline: 'Your library',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.sort),
                tooltip: 'Sort topics',
                onPressed: () =>
                    _chooseTopicSort(topicSort ?? ListSort.defaultByName),
              ),
              M3EIconButton(
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.archive_outlined),
                tooltip: 'Archived topics',
                onPressed: _showArchivedTopics,
              ),
            ],
          ),
        ),
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
              if (archived.isNotEmpty) {
                return EmptyState(
                  icon: Icons.archive_outlined,
                  title: 'No active topics',
                  message:
                      'Every topic is archived. Open archived topics to '
                      'restore one.',
                  action: M3EButton.tonal(
                    onPressed: _showArchivedTopics,
                    child: const Text('Open archived topics'),
                  ),
                );
              }
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
            final sorted = _sortedTopics(items, topicSort);
            return AppGroup(
              variant: M3ECardVariant.filled,
              children: [
                for (final summary in sorted)
                  _TopicRow(
                    summary: summary,
                    onPressed: () =>
                        _push(TopicPage(topicId: summary.topic.id)),
                    onLongPress: () => showTopicActions(context, ref, summary),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _pausedLabel(int count) => '${formatCount(count, 'session')} paused';

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => page));
  }

  Future<void> _chooseTopicSort(ListSort current) async {
    final applied = await showListSortDialog(
      context,
      title: 'Sort topics',
      initial: current,
      description:
          'Increasing: A to Z or oldest first. Decreasing: Z to A or newest '
          'first. Recency uses the date the topic was created.',
    );
    if (applied == null || !mounted) return;
    await ref.read(settingsRepositoryProvider).saveHomeTopicSort(applied);
  }

  List<TopicSummary> _sortedTopics(List<TopicSummary> items, ListSort? sort) {
    if (sort == null) return items;
    final sorted = List<TopicSummary>.of(items);
    final direction = sort.direction == ListSortDirection.increasing ? 1 : -1;
    sorted.sort((a, b) {
      final comparison = switch (sort.field) {
        ListSortField.name => compareNatural(a.topic.name, b.topic.name),
        ListSortField.recency => a.topic.createdAt.compareTo(b.topic.createdAt),
      };
      final tieBreak = a.topic.id.compareTo(b.topic.id);
      return (comparison != 0 ? comparison : tieBreak) * direction;
    });
    return sorted;
  }

  Future<void> _showArchivedTopics() async {
    final selected = await M3EBottomSheet.show<TopicSummary>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) => const ArchivedTopicsSheet(),
    );
    if (selected == null || !mounted) return;
    await showTopicActions(context, ref, selected);
  }

  Future<void> _showShuffleOptions() async {
    final count = await M3EBottomSheet.show<int>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) => const _ShuffleOptionsSheet(),
    );
    if (count != null && mounted) await _startMixed(count);
  }

  Future<void> _startMixed(int count) async {
    setState(() => _starting = true);
    try {
      final start = ref.read(sessionServiceProvider);
      final session = await start.startMixed(limit: count);
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
          ? 'Concepts, errors, basic cards, skipped questions and notes'
          : cards == 0 && pending == 0
          ? 'Nothing waiting to export'
          : cards == 0
          ? '${formatCount(pending, 'error')} to review'
          : pending == 0
          ? '${formatCount(cards!, 'card')} ready to export'
          : '${formatCount(cards!, 'card')} ready · '
                '${formatCount(pending, 'error')} to review',
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
    final largeText = _usesLargeText(context);
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
              // The count and its status pill stack when large text leaves the
              // row too narrow, instead of forcing the pill past the card edge.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  if (badge != null) Pill(badge!, tone: PillTone.error),
                ],
              ),
              const SizedBox(height: 3),
              Text(title, style: theme.typography.baseline.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: largeText ? 4 : 2,
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

class _ShuffleOptionsSheet extends ConsumerStatefulWidget {
  const _ShuffleOptionsSheet();

  @override
  ConsumerState<_ShuffleOptionsSheet> createState() =>
      _ShuffleOptionsSheetState();
}

class _ShuffleOptionsSheetState extends ConsumerState<_ShuffleOptionsSheet> {
  static const _defaultCount = 15;
  static const _invalidMessage = 'Enter a whole number of at least 1.';

  final _count = TextEditingController(text: '$_defaultCount');
  int? _chosen = _defaultCount;
  String? _error;

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  int? _parseCount(String raw) {
    final value = int.tryParse(raw.trim());
    return value == null || value <= 0 ? null : value;
  }

  void _onCountChanged(String raw) {
    final parsed = _parseCount(raw);
    setState(() {
      _chosen = parsed;
      _error = parsed == null ? _invalidMessage : null;
    });
  }

  String _helperText(int? available) {
    final chosen = _chosen;
    if (available == null) {
      return 'Only unsolved, unskipped questions are included. If you ask for '
          'more than are available, the session includes all of them.';
    }
    if (chosen != null && chosen > available) {
      return 'Only $available eligible '
          '${available == 1 ? 'question is' : 'questions are'} available, so '
          'the session will include all of them.';
    }
    return available == 1
        ? '1 eligible question is available.'
        : '$available eligible questions are available.';
  }

  void _start() {
    final chosen = _chosen;
    if (chosen != null) Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final available = ref.watch(mixedEligibleCountProvider).value;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.shuffle, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Start shuffled practice',
                    style: theme.typography.emphasized.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Mixed questions from every topic, unsolved and unskipped only, '
              'in random order.',
              style: theme.typography.baseline.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            M3ETextField(
              key: const ValueKey('shuffle-question-count'),
              controller: _count,
              label: 'Questions',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: _error,
              supportingText: _helperText(available),
              onChanged: _onCountChanged,
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              onPressed: _chosen == null ? null : _start,
              label: 'Start practice',
              icon: Icons.play_arrow,
            ),
          ],
        ),
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
    final practiceName = session.practiceName.trim();
    final topicName = session.topicName.trim();
    final title =
        session.mode == SessionMode.practice && practiceName.isNotEmpty
        ? practiceName
        : mode;
    final details = [
      if (session.mode == SessionMode.practice && topicName.isNotEmpty)
        topicName,
      '${session.answeredCount}/${session.total} answered',
    ].join(' · ');
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
                      title,
                      style: theme.typography.baseline.titleSmall.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      details,
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
  const _TopicRow({
    required this.summary,
    required this.onPressed,
    required this.onLongPress,
  });

  final TopicSummary summary;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final largeText = _usesLargeText(context);
    final accuracy = (summary.accuracy * 100).round();
    final counts = Text(
      '${formatCount(summary.practiceCount, 'practice')} · '
      '${formatCount(summary.relevantQuestionCount, 'question')}',
      style: theme.typography.baseline.labelSmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final accuracyLabel = Text(
      summary.answeredCount == 0 ? 'Not started' : '$accuracy% accuracy',
      style: theme.typography.baseline.labelSmall.copyWith(
        color: summary.answeredCount == 0
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
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
                                maxLines: largeText ? 4 : 2,
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
                            maxLines: largeText ? 4 : 2,
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
              // At large text the counts no longer fit beside the accuracy
              // figure, so they run onto separate lines instead of squeezing.
              if (largeText)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (summary.topic.priority != null)
                      Pill('P${summary.topic.priority}'),
                    counts,
                    accuracyLabel,
                  ],
                )
              else
                Row(
                  children: [
                    if (summary.topic.priority != null) ...[
                      Pill('P${summary.topic.priority}'),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: counts),
                    const SizedBox(width: 8),
                    accuracyLabel,
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
