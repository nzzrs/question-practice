import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import 'anki_deck_picker.dart';
import 'topic_stats_page.dart';

enum _PracticeAction { delete, markDone, markActive }

class TopicPage extends ConsumerStatefulWidget {
  const TopicPage({required this.topicId, super.key});

  final int topicId;

  @override
  ConsumerState<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends ConsumerState<TopicPage> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(topicSummaryProvider(widget.topicId));
    final practices = ref.watch(practiceSummariesProvider(widget.topicId));
    final defaultDeck =
        ref.watch(settingsProvider).value?.ankiDeck ?? 'Question Practice';

    return AppPage(
      title: summary.value?.topic.name ?? 'Topic',
      titleWidget: summary.value == null
          ? null
          : Text(
              summary.value!.topic.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.insights_outlined),
          tooltip: 'Topic statistics',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TopicStatsPage(topicId: widget.topicId),
            ),
          ),
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit topic',
          onPressed: summary.value == null
              ? null
              : () => _editTopic(summary.value!.topic),
        ),
      ],
      children: [
        summary.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
          error: (error, stackTrace) => EmptyState(
            icon: Icons.warning_amber_outlined,
            title: 'Could not load this topic',
            message: '$error',
          ),
          data: (data) {
            if (data == null) {
              return const EmptyState(
                icon: Icons.search_off,
                title: 'Topic not found',
                message: 'This topic may have been removed.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (data.topic.priority != null) ...[
                      Pill(
                        'P${data.topic.priority}',
                        tone: PillTone.primary,
                        icon: Icons.flag_outlined,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Pill(
                      '${data.sessionCount} sessions',
                      tone: PillTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Anki deck: ${data.topic.ankiDeck ?? '$defaultDeck (default)'}',
                  style: M3ETheme.of(context).typography.baseline.labelSmall
                      .copyWith(
                        color: M3ETheme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                if (data.topic.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    data.topic.description,
                    style: M3ETheme.of(context).typography.baseline.bodyLarge
                        .copyWith(
                          color: M3ETheme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
                const SizedBox(height: 20),
                _TopicHero(summary: data),
                const SizedBox(height: 24),
                const SectionTitle('Practices'),
                practices.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: M3ELoadingIndicator()),
                  ),
                  error: (error, stackTrace) => Text('$error'),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.library_books_outlined,
                        title: 'No practices here',
                        message: 'Import a practice file that names this topic to add practices.',
                      );
                    }
                    return AppGroup(
                      children: [
                        for (final practice in items)
                          AppGroupRow(
                            title: practice.practice.name,
                            titleMaxLines: 2,
                            subtitle: practice.practice.description.isEmpty
                                ? null
                                : practice.practice.description,
                            leading: IconBadge(Icons.play_arrow_outlined),
                            trailing: _PracticeTrailing(summary: practice),
                            onTap: _starting
                                ? null
                                : () => _startPractice(practice.practice),
                            onLongPress: _starting
                                ? null
                                : () => _showPracticeActions(practice),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _startPractice(Practice practice) async {
    setState(() => _starting = true);
    try {
      final start = await ref
          .read(sessionServiceProvider)
          .startPractice(practice.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SessionPage(start: start),
        ),
      );
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _showPracticeActions(PracticeSummary summary) async {
    final practice = summary.practice;
    final action = await M3EDialog.show<_PracticeAction>(
      context,
      dialog: M3EDialog(
        title: practice.name,
        content: Text(
          practice.isDone
              ? 'This practice is marked as done. You can still open it.'
              : 'Mark this practice as done when you no longer need it in your active list.',
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(_PracticeAction.delete),
            child: const Text('Delete'),
          ),
          M3EButton.filled(
            onPressed: () => Navigator.of(context).pop(
              practice.isDone
                  ? _PracticeAction.markActive
                  : _PracticeAction.markDone,
            ),
            child: Text(practice.isDone ? 'Mark active' : 'Mark as done'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _PracticeAction.delete:
        final confirmed = await confirmDialog(
          context,
          title: 'Delete practice?',
          message:
              'This removes "${practice.name}", its questions, sessions and cards. It cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!confirmed) return;
        await ref.read(topicRepositoryProvider).deletePractice(practice.id);
        if (mounted) await showSnack(context, 'Practice deleted.');
      case _PracticeAction.markDone:
        await ref
            .read(topicRepositoryProvider)
            .setPracticeDone(practice.id, true);
        if (mounted) await showSnack(context, 'Practice marked as done.');
      case _PracticeAction.markActive:
        await ref
            .read(topicRepositoryProvider)
            .setPracticeDone(practice.id, false);
        if (mounted) await showSnack(context, 'Practice marked active.');
    }
  }

  Future<void> _editTopic(Topic topic) async {
    final name = TextEditingController(text: topic.name);
    final description = TextEditingController(text: topic.description);
    final priority = TextEditingController(
      text: topic.priority?.toString() ?? '',
    );
    final deck = TextEditingController(text: topic.ankiDeck ?? '');
    String? error;
    final saved = await M3EDialog.show<bool>(
      context,
      dialog: StatefulBuilder(
        builder: (context, setDialogState) {
          return M3EDialog(
            title: 'Edit topic',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  M3ETextField(
                    controller: name,
                    label: 'Name',
                    isRequired: true,
                  ),
                  const SizedBox(height: 12),
                  M3ETextField(
                    controller: description,
                    label: 'Description',
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 12),
                  M3ETextField(
                    controller: priority,
                    label: 'Priority (1 highest, optional)',
                    keyboardType: TextInputType.number,
                    errorText: error,
                  ),
                  const SizedBox(height: 12),
                  M3ETextField(
                    controller: deck,
                    label: 'AnkiDroid deck',
                    supportingText:
                        'Blank uses the default deck from Settings.',
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: M3EButton.tonal(
                      onPressed: () async {
                        final selected = await showAnkiDeckPicker(
                          context,
                          ref,
                          current: deck.text,
                        );
                        if (selected == null) return;
                        setDialogState(() => deck.text = selected);
                      },
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Browse decks'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              M3EButton.text(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              M3EButton.filled(
                onPressed: () async {
                  final trimmedName = name.text.trim();
                  final parsedPriority = priority.text.trim().isEmpty
                      ? null
                      : int.tryParse(priority.text.trim());
                  if (trimmedName.isEmpty) {
                    setDialogState(() => error = 'Name is required.');
                    return;
                  }
                  if (priority.text.trim().isNotEmpty &&
                      (parsedPriority == null ||
                          parsedPriority < 1 ||
                          parsedPriority > 5)) {
                    setDialogState(() => error = 'Use a number from 1 to 5.');
                    return;
                  }
                  await ref
                      .read(topicRepositoryProvider)
                      .updateTopic(
                        id: topic.id,
                        name: trimmedName,
                        description: description.text.trim(),
                        priority: parsedPriority,
                        ankiDeck: deck.text.trim().isEmpty
                            ? null
                            : deck.text.trim(),
                      );
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    description.dispose();
    priority.dispose();
    deck.dispose();
    if (saved == true && mounted) {
      await showSnack(context, 'Topic updated.');
    }
  }
}

class _TopicHero extends StatelessWidget {
  const _TopicHero({required this.summary});

  final TopicSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = summary.answeredCount == 0
        ? 0.0
        : summary.accuracy.clamp(0, 1).toDouble();
    final accuracyLabel = summary.answeredCount == 0
        ? '—'
        : '${(accuracy * 100).round()}%';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(
                value: accuracy,
                label: accuracyLabel,
                caption: 'Accuracy',
                size: 116,
                strokeWidth: 11,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: theme.typography.baseline.labelMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(summary.progress * 100).round()}%',
                      style: theme.typography.emphasized.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.correctQuestionCount}/${summary.questionCount} learned',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearScore(value: summary.progress),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Active errors',
                  value: '${summary.activeErrorCount}',
                  icon: Icons.error_outline,
                  caption: '${summary.dueErrorCount} due now',
                  tone: summary.activeErrorCount > 0
                      ? MetricTone.error
                      : MetricTone.neutral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: 'Answers',
                  value: '${summary.correctCount}/${summary.answeredCount}',
                  icon: Icons.check_circle_outline,
                  caption: '${summary.sessionCount} sessions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeTrailing extends StatelessWidget {
  const _PracticeTrailing({required this.summary});

  final PracticeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final score = summary.lastScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${summary.questionCount} questions',
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          Pill(
            '${(score * 100).round()}%',
            tone: score >= 0.7 ? PillTone.success : PillTone.error,
          ),
        ],
        if (summary.practice.isDone) ...[
          const SizedBox(height: 2),
          const Pill('Done', tone: PillTone.success, icon: Icons.check),
        ],
      ],
    );
  }
}
