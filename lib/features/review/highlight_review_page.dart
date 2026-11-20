import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'highlight_card_actions.dart';
import 'highlight_review_view.dart';
import 'suggested_cards_sheet.dart';

/// Reviews saved highlights one at a time.
///
/// Opened from Cards with every visible highlight, or with a single highlight
/// when its row is tapped. Highlights are read live from the database, so a
/// card made or a highlight deleted here is reflected without closing the
/// review. The card-making actions live inside the shared
/// [HighlightReviewView] and disappear once a highlight has a card.
class HighlightReviewPage extends ConsumerStatefulWidget {
  const HighlightReviewPage({
    required this.highlights,
    this.initialHighlightId,
    this.title = 'Review notes',
    super.key,
  });

  final List<StudyHighlight> highlights;
  final int? initialHighlightId;
  final String title;

  @override
  ConsumerState<HighlightReviewPage> createState() =>
      _HighlightReviewPageState();
}

class _HighlightReviewPageState extends ConsumerState<HighlightReviewPage> {
  final _scroll = ScrollController();
  late final Set<int> _ids;
  late int _index;
  int _kept = 0;
  int _cards = 0;
  bool _busy = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ids = {for (final highlight in widget.highlights) highlight.id};
    final initialId = widget.initialHighlightId;
    final found = initialId == null
        ? -1
        : widget.highlights.indexWhere(
            (highlight) => highlight.id == initialId,
          );
    _index = found < 0 ? 0 : found;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _advanceFrom(int index, int length) {
    if (index + 1 >= length) {
      setState(() => _finished = true);
      return;
    }
    setState(() => _index = index + 1);
    _resetScroll();
  }

  void _goBack(int index) {
    if (index == 0) return;
    setState(() => _index = index - 1);
    _resetScroll();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _keep(StudyHighlight highlight, int index, int length) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(reviewServiceProvider).keepHighlight(highlight.id);
      _kept++;
      if (!mounted) return;
      _advanceFrom(index, length);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makeCard(
    StudyHighlight highlight,
    int index,
    int length,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final created = await convertHighlightToCard(context, ref, highlight);
      if (!mounted || created == 0) return;
      _cards += created;
      _advanceFrom(index, length);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suggestCards(
    StudyHighlight highlight,
    int index,
    int length,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final added = await suggestCardsFromHighlight(context, highlight);
      if (!mounted || added == 0) return;
      _cards += added;
      _advanceFrom(index, length);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteHighlight(StudyHighlight highlight, int length) async {
    if (_busy) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete note?',
      message:
          'The saved note "${highlight.text}" is removed from Cards. '
          'Cards already made from it stay.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(cardRepositoryProvider).deleteHighlight(highlight.id);
      if (!mounted) return;
      final remaining = math.max(0, length - 1);
      setState(() {
        _ids.remove(highlight.id);
        if (remaining == 0) {
          _finished = true;
        } else if (_index >= remaining) {
          _index = remaining - 1;
        }
      });
      _resetScroll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveReview(child: _buildPage(context));
  }

  Widget _buildPage(BuildContext context) {
    final theme = M3ETheme.of(context);
    final live = ref.watch(highlightsProvider).value ?? widget.highlights;
    final highlights = [
      for (final highlight in live)
        if (_ids.contains(highlight.id)) highlight,
    ];

    if (_finished || highlights.isEmpty) {
      final changed = _kept > 0 || _cards > 0;
      return AppPage(
        title: 'Notes reviewed',
        focus: true,
        onBack: () => Navigator.of(context).pop(true),
        scrollController: _scroll,
        variant: M3EAppBarVariant.small,
        children: [
          const SizedBox(height: 32),
          Center(child: IconBadge(Icons.check_circle_outline, size: 72)),
          const SizedBox(height: 16),
          Text(
            highlights.isEmpty && !changed
                ? 'No notes to review'
                : 'Note review complete',
            textAlign: TextAlign.center,
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            changed
                ? [
                    if (_kept > 0)
                      '$_kept note${_kept == 1 ? '' : 's'} kept',
                    if (_cards > 0)
                      '$_cards card${_cards == 1 ? '' : 's'} created',
                  ].join(' and ')
                : 'No notes were changed.',
            textAlign: TextAlign.center,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Done',
            icon: Icons.check,
          ),
        ],
      );
    }

    final index = _index >= highlights.length ? highlights.length - 1 : _index;
    final highlight = highlights[index];
    final last = index == highlights.length - 1;
    return AppPage(
      title: widget.title,
      showBack: true,
      focus: true,
      scrollController: _scroll,
      variant: M3EAppBarVariant.small,
      bottomBar: AppActionDock(
        child: Row(
          children: [
            if (index > 0) ...[
              M3EButton.text(
                onPressed: _busy ? null : () => _goBack(index),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: AppPrimaryButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (!highlight.isKept) {
                          _keep(highlight, index, highlights.length);
                        } else {
                          _advanceFrom(index, highlights.length);
                        }
                      },
                label: _busy
                    ? 'Saving…'
                    : !highlight.isKept
                    ? last
                          ? 'Keep & done'
                          : 'Keep & next'
                    : last
                    ? 'Done'
                    : 'Next',
                icon: !highlight.isKept ? Icons.check : Icons.arrow_forward,
              ),
            ),
            if (!highlight.isKept) ...[
              const SizedBox(width: 4),
              M3EButton.text(
                onPressed: _busy
                    ? null
                    : () => _advanceFrom(index, highlights.length),
                child: const Text('Skip'),
              ),
            ],
          ],
        ),
      ),
      children: [
        Text(
          'Item ${index + 1} of ${highlights.length}',
          style: theme.typography.baseline.labelMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearScore(value: (index + 1) / highlights.length),
        const SizedBox(height: 22),
        Text(
          'Review the note',
          style: theme.typography.emphasized.headlineSmall,
        ),
        const SizedBox(height: 16),
        HighlightReviewView(
          key: ValueKey('highlight-review-${highlight.id}'),
          highlight: highlight,
          onMakeCard: () => _makeCard(highlight, index, highlights.length),
          onSuggestCards: () =>
              _suggestCards(highlight, index, highlights.length),
          onKeep: highlight.isKept
              ? null
              : () => _keep(highlight, index, highlights.length),
          onDelete: () => _deleteHighlight(highlight, highlights.length),
        ),
      ],
    );
  }
}
