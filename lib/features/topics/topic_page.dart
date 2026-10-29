import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';
import 'anki_deck_picker.dart';

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

    return AppScaffold(
      title: summary.value?.topic.name ?? 'Topic',
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit topic',
          onPressed: summary.value == null
              ? null
              : () => _editTopic(summary.value!.topic),
        ),
      ],
      body: summary.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (data.topic.priority != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: M3ETheme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'P${data.topic.priority}',
                      style: M3ETheme.of(context)
                          .typography
                          .baseline
                          .labelMedium
                          .copyWith(
                            color: M3ETheme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                'Anki deck: ${data.topic.ankiDeck ?? '$defaultDeck (default)'}',
                style: M3ETheme.of(context).typography.baseline.labelSmall
                    .copyWith(
                      color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              if (data.topic.description.isNotEmpty) ...[
                Text(
                  data.topic.description,
                  style: M3ETheme.of(context).typography.baseline.bodyLarge
                      .copyWith(
                        color: M3ETheme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
              ],
              _TopicStats(summary: data),
              const SizedBox(height: 28),
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
                  return Column(
                    children: [
                      for (final practice in items) ...[
                        _PracticeCard(
                          summary: practice,
                          onPressed: _starting
                              ? null
                              : () => _startPractice(practice.practice),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
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
                      label: const Text('Choose AnkiDroid deck'),
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

class _TopicStats extends StatelessWidget {
  const _TopicStats({required this.summary});

  final TopicSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final accuracy = summary.answeredCount == 0
        ? '—'
        : '${(summary.accuracy * 100).round()}%';
    final progress = '${(summary.progress * 100).round()}%';
    return TonalBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatValue(
                  label: 'Accuracy',
                  value: accuracy,
                  caption:
                      '${summary.correctCount}/${summary.answeredCount} answers',
                ),
              ),
              Expanded(
                child: StatValue(
                  label: 'Progress',
                  value: progress,
                  caption:
                      '${summary.correctQuestionCount}/${summary.questionCount} learned',
                ),
              ),
              Expanded(
                child: StatValue(
                  label: 'Active errors',
                  value: '${summary.activeErrorCount}',
                  caption: '${summary.dueErrorCount} due now',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${summary.sessionCount} completed sessions',
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearScore(value: summary.progress),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.summary, required this.onPressed});

  final PracticeSummary summary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final score = summary.lastScore;
    return M3ECard(
      variant: M3ECardVariant.filled,
      onPressed: onPressed,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.practice.name,
                  style: theme.typography.emphasized.titleSmall,
                ),
                if (summary.practice.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    summary.practice.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${summary.questionCount} questions'
                  '${score == null ? '' : ' · Last score ${(score * 100).round()}%'}',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.play_arrow, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
