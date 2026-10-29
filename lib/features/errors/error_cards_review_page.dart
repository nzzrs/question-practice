import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import 'error_card_review_view.dart';

class ErrorCardsReviewPage extends ConsumerStatefulWidget {
  const ErrorCardsReviewPage({
    required this.cards,
    this.title = 'Review error cards',
    super.key,
  });

  final List<ErrorCard> cards;
  final String title;

  @override
  ConsumerState<ErrorCardsReviewPage> createState() =>
      _ErrorCardsReviewPageState();
}

class _ErrorCardsReviewPageState extends ConsumerState<ErrorCardsReviewPage> {
  final _bias = TextEditingController();
  final _vaccine = TextEditingController();
  int _index = 0;
  int _saved = 0;
  bool _busy = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _prepareCard();
  }

  @override
  void dispose() {
    _bias.dispose();
    _vaccine.dispose();
    super.dispose();
  }

  ErrorCard? get _card =>
      _index < widget.cards.length ? widget.cards[_index] : null;

  void _prepareCard() {
    final card = _card;
    _bias.text = card?.bias ?? '';
    _vaccine.text = card?.vaccine ?? '';
  }

  void _advance() {
    if (_index + 1 >= widget.cards.length) {
      setState(() => _finished = true);
      ref.invalidate(homeStatsProvider);
      return;
    }
    setState(() {
      _index++;
      _prepareCard();
    });
  }

  Future<void> _save() async {
    final card = _card;
    if (card == null) return;
    if (_bias.text.trim().isEmpty || _vaccine.text.trim().isEmpty) {
      await showSnack(
        context,
        'Write both the flawed assumption and the prevention note.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewServiceProvider)
          .saveErrorDetails(
            cardId: card.id,
            bias: _bias.text,
            vaccine: _vaccine.text,
          );
      _saved++;
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    if (widget.cards.isEmpty) {
      return AppScaffold(
        title: widget.title,
        showBack: true,
        body: const EmptyState(
          icon: Icons.style_outlined,
          title: 'No error cards',
          message: 'Wrong answers create error cards for review.',
        ),
      );
    }
    if (_finished) {
      return AppScaffold(
        title: 'Review complete',
        showBack: false,
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _saved == 0 ? 'No cards changed' : 'Review complete',
              textAlign: TextAlign.center,
              style: theme.typography.emphasized.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _saved == 0
                  ? 'No card details were saved.'
                  : '$_saved card${_saved == 1 ? '' : 's'} updated.',
              textAlign: TextAlign.center,
              style: theme.typography.baseline.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            M3EButton.filled(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final card = _card!;
    return AppScaffold(
      title: widget.title,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Card ${_index + 1} of ${widget.cards.length}',
            style: theme.typography.baseline.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearScore(value: (_index + 1) / widget.cards.length),
          const SizedBox(height: 24),
          Text(
            card.needsDetails
                ? 'Complete the error card'
                : 'Check the error card',
            style: theme.typography.emphasized.headlineSmall,
          ),
          const SizedBox(height: 16),
          ErrorCardReviewView(card: card, bias: _bias, vaccine: _vaccine),
          const SizedBox(height: 20),
          Row(
            children: [
              M3EButton.filled(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_busy ? 'Saving…' : 'Save'),
              ),
              const SizedBox(width: 8),
              M3EButton.text(
                onPressed: _busy ? null : _advance,
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
