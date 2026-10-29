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
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final due = ref.watch(dueErrorsProvider);
    final history = ref.watch(resolvedErrorsProvider);

    return AppPage(
      title: 'Past errors',
      showBack: true,
      children: [
        Text(
          'Errors come back after 48 hours. Answering one correctly removes it from the queue but keeps it in your history.',
          style: theme.typography.baseline.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        due.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: M3ELoadingIndicator()),
          ),
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
                SectionTitle(
                  'Due now',
                  count: cards.length,
                  trailing: Pill(
                    '${cards.length} waiting',
                    tone: PillTone.error,
                  ),
                ),
                AppGroup(
                  children: [
                    for (final card in cards) _ErrorTile(card: card, due: true),
                  ],
                ),
                const SizedBox(height: 14),
                AppPrimaryButton(
                  onPressed: _starting ? null : _start,
                  label: _starting
                      ? 'Starting…'
                      : 'Review ${cards.length} error${cards.length == 1 ? '' : 's'}',
                  icon: Icons.play_arrow,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        SectionTitle(
          'Resolved history',
          trailing: M3EButton.text(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            child: Text(_showHistory ? 'Hide' : 'Show'),
          ),
        ),
        history.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => Text('$error'),
          data: (cards) {
            if (cards.isEmpty) {
              return Text(
                'Resolved errors appear here.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            if (!_showHistory) {
              return Text(
                '${cards.length} resolved error${cards.length == 1 ? '' : 's'}.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return AppGroup(
              children: [
                for (final card in cards) _ErrorTile(card: card, due: false),
              ],
            );
          },
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  card.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                due
                    ? 'Due ${DateFormat.MMMd().format(date.toLocal())}'
                    : 'Resolved ${DateFormat.MMMd().format(date.toLocal())}',
                tone: due ? PillTone.error : PillTone.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You: ${card.wrongAnswer}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          Text(
            'Correct: ${card.correctAnswer}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
