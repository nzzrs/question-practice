import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/platform/anki_gateway.dart';

/// Shows the AnkiDroid decks. Returns a deck name, an empty string for the
/// default deck, or null when the picker is cancelled.
Future<String?> showAnkiDeckPicker(
  BuildContext context,
  WidgetRef ref, {
  String? current,
  bool allowDefault = true,
}) async {
  final custom = TextEditingController(text: current ?? '');
  final defaultDeck =
      ref.read(settingsProvider).value?.ankiDeck ?? 'Question Practice';
  final result = await M3EDialog.show<String>(
    context,
    dialog: M3EDialog(
      title: 'AnkiDroid deck',
      content: _DeckPickerBody(
        gateway: ref.read(ankiGatewayProvider),
        current: current,
        defaultDeck: defaultDeck,
        custom: custom,
        allowDefault: allowDefault,
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: () {
            final name = custom.text.trim();
            if (name.isNotEmpty) Navigator.of(context).pop(name);
          },
          child: const Text('Use typed name'),
        ),
      ],
    ),
  );
  custom.dispose();
  return result;
}

class _DeckPickerBody extends StatefulWidget {
  const _DeckPickerBody({
    required this.gateway,
    required this.current,
    required this.defaultDeck,
    required this.custom,
    required this.allowDefault,
  });

  final AnkiGateway gateway;
  final String? current;
  final String defaultDeck;
  final TextEditingController custom;
  final bool allowDefault;

  @override
  State<_DeckPickerBody> createState() => _DeckPickerBodyState();
}

class _DeckPickerBodyState extends State<_DeckPickerBody> {
  List<String> _decks = const [];
  String? _message;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await widget.gateway.status();
    if (!status.installed) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'AnkiDroid is not installed. Type a deck name instead.';
        });
      }
      return;
    }
    if (!status.apiAvailable) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Enable the AnkiDroid API in AnkiDroid settings to load decks.';
        });
      }
      return;
    }
    if (!status.permissionGranted) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Grant AnkiDroid database permission in Settings to load decks.';
        });
      }
      return;
    }
    final decks = await widget.gateway.deckNames();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _decks = decks;
      if (decks.isEmpty) {
        _message =
            'No decks found. Type a new deck name; it is created on export.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The default deck applies when this topic has no deck of its own.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.allowDefault)
              _DeckOption(
                title: 'Use default deck',
                subtitle: widget.defaultDeck,
                selected: (widget.current ?? '').trim().isEmpty,
                onPressed: () => Navigator.of(context).pop(''),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: M3ELoadingIndicator()),
              )
            else ...[
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _message!,
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              for (final deck in _decks)
                _DeckOption(
                  title: deck,
                  selected: widget.current == deck,
                  onPressed: () => Navigator.of(context).pop(deck),
                ),
              const SizedBox(height: 12),
              M3ETextField(
                controller: widget.custom,
                label: 'Or type a deck name',
                placeholder: 'Created on export if missing',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckOption extends StatelessWidget {
  const _DeckOption({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: M3ECard(
        variant: M3ECardVariant.outlined,
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.typography.baseline.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.typography.baseline.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
