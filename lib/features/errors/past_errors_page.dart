import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../practice/domain/session_service.dart';
import '../practice/session_page.dart';

class PastErrorsPage extends ConsumerStatefulWidget {
  const PastErrorsPage({super.key});

  @override
  ConsumerState<PastErrorsPage> createState() => _PastErrorsPageState();
}

class _PastErrorsPageState extends ConsumerState<PastErrorsPage> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final due = ref.watch(dueErrorsProvider);
    final history = ref.watch(resolvedErrorsProvider);
    return AppScaffold(
      title: 'Past errors',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Errors come back after 48 hours. Answering one correctly removes it from the queue but keeps it in your history.',
            style: M3ETheme.of(context).typography.baseline.bodySmall.copyWith(
              color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          due.when(
            loading: () => const Center(child: M3ELoadingIndicator()),
            error: (error, stackTrace) => EmptyState(
              icon: Icons.warning_amber_outlined,
              title: 'Could not load errors',
              message: '$error',
            ),
            data: (cards) {
              if (cards.isEmpty) {
                return const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing due yet',
                  message:
                      'New errors wait 48 hours before they are offered again.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('Due now · ${cards.length}'),
                  for (final card in cards) ...[
                    _ErrorTile(card: card, due: true),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  M3EButton.filled(
                    onPressed: _starting ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _starting
                          ? 'Starting…'
                          : 'Review ${cards.length} error${cards.length == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          SectionTitle('Resolved history'),
          history.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => Text('$error'),
            data: (cards) {
              if (cards.isEmpty) {
                return Text(
                  'Resolved errors appear here.',
                  style: M3ETheme.of(context).typography.baseline.bodySmall
                      .copyWith(
                        color: M3ETheme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                );
              }
              return Column(
                children: [
                  for (final card in cards) ...[
                    _ErrorTile(card: card, due: false),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final start = await ref.read(sessionServiceProvider).startPastErrors();
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
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.card, required this.due});

  final ErrorCard card;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final date = card.resolvedAt ?? card.dueAt;
    return M3ECard(
      variant: M3ECardVariant.outlined,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.question, style: theme.typography.baseline.titleSmall),
          const SizedBox(height: 6),
          Text(
            'You: ${card.wrongAnswer}',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          Text(
            'Correct: ${card.correctAnswer}',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            due
                ? 'Due ${DateFormat.yMMMd().add_Hm().format(date.toLocal())}'
                : 'Resolved ${DateFormat.yMMMd().format(date.toLocal())}',
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
