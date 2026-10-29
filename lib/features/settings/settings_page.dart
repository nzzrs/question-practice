import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/anki_gateway.dart';
import '../../core/ui/widgets.dart';
import '../help/help_page.dart';
import '../lookup/domain/lookup_service.dart';
import '../topics/anki_deck_picker.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _deck = TextEditingController();
  final _apiKey = TextEditingController();
  AiProvider _provider = AiProvider.openai;
  List<String> _models = const [];
  bool _loadingModels = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _deck.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();
    if (!_loaded && settingsAsync.hasValue) {
      _loaded = true;
      _provider = settings.aiProvider;
      _baseUrl.text = settings.aiBaseUrl;
      _model.text = settings.aiModel;
      _deck.text = settings.ankiDeck;
    }
    final theme = M3ETheme.of(context);
    final hasKey = ref.watch(hasApiKeyProvider).value ?? false;

    return AppScaffold(
      title: 'Settings',
      showBack: true,
      actions: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(Icons.help_outline),
          tooltip: 'How to use it',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const HelpPage()),
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SectionTitle('Appearance'),
          _SwitchRow(
            title: 'Use wallpaper colors',
            subtitle:
                'Apply Material You colors from the device when available.',
            value: settings.dynamicColor,
            onChanged: (value) => _save(settings.copyWith(dynamicColor: value)),
          ),
          const SizedBox(height: 28),
          const SectionTitle('Looking up terms'),
          Text(
            'Choose what happens when you select text in a question and tap Define.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          M3ESegmentedButton<LookupMode>(
            segments: const [
              M3ESegment(value: LookupMode.web, label: 'Web search'),
              M3ESegment(value: LookupMode.ai, label: 'AI'),
            ],
            selected: {settings.lookupMode},
            onSelectionChanged: (values) {
              if (values.isEmpty) return;
              _save(settings.copyWith(lookupMode: values.first));
            },
          ),
          const SizedBox(height: 12),
          if (settings.lookupMode == LookupMode.web) ...[
            Text('Search engine', style: theme.typography.baseline.labelMedium),
            const SizedBox(height: 8),
            M3ESegmentedButton<WebEngine>(
              segments: const [
                M3ESegment(value: WebEngine.duckDuckGo, label: 'DuckDuckGo'),
                M3ESegment(value: WebEngine.wikipedia, label: 'Wikipedia'),
              ],
              selected: {settings.webEngine},
              onSelectionChanged: (values) {
                if (values.isEmpty) return;
                _save(settings.copyWith(webEngine: values.first));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'A Custom Tab opens inside the app. The selected term and context are saved as a missing concept so you can fill the definition later.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text('Provider', style: theme.typography.baseline.labelMedium),
            const SizedBox(height: 8),
            M3EChipGroup(
              groupLabel: 'AI provider',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final provider in AiProvider.values)
                    M3EChip(
                      type: M3EChipType.filter,
                      label: _providerLabel(provider),
                      selected: _provider == provider,
                      onPressed: () {
                        setState(() {
                          _provider = provider;
                          _models = const [];
                          _baseUrl.text = _baseUrlFor(provider, _baseUrl.text);
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            M3ETextField(
              controller: _baseUrl,
              label: 'Base URL',
              placeholder: 'https://api.openai.com/v1',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Text('Model', style: theme.typography.baseline.labelMedium),
            const SizedBox(height: 8),
            M3EDropdownMenu<String>(
              items: [
                for (final model in _modelOptions)
                  M3EDropdownItem(
                    label: model,
                    value: model,
                    selected: model == _model.text.trim(),
                  ),
              ],
              singleSelect: true,
              searchEnabled: true,
              fieldStyle: const M3EDropdownFieldStyle(
                hintText: 'Load available models',
              ),
              emptyBuilder: (context) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No models loaded. Tap Load models.',
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() => _model.text = selection.first.value);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                M3EButton.tonal(
                  onPressed: _loadingModels ? null : _loadModels,
                  icon: const Icon(Icons.refresh),
                  label: Text(_loadingModels ? 'Loading…' : 'Load models'),
                ),
                if (_model.text.trim().isNotEmpty)
                  Text(
                    _model.text.trim(),
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            M3ETextField(
              controller: _apiKey,
              label: hasKey ? 'Replace API key' : 'API key',
              obscureText: true,
              showPasswordToggle: true,
              supportingText: hasKey
                  ? 'A key is saved in Android secure storage.'
                  : 'Stored in Android secure storage, never in the database.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                M3EButton.filled(
                  onPressed: _busy ? null : () => _saveAi(settings),
                  child: Text(_busy ? 'Saving…' : 'Save AI settings'),
                ),
                M3EButton.tonal(
                  onPressed: _busy ? null : _saveKey,
                  child: const Text('Save key'),
                ),
                if (hasKey)
                  M3EButton.text(
                    onPressed: _busy ? null : _removeKey,
                    child: const Text('Remove key'),
                  ),
                M3EButton.text(
                  onPressed: _busy ? null : _testConnection,
                  child: const Text('Test connection'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The app sends the selected term, question and topic to the endpoint you choose. It never logs the key. '
              'OpenAI, Groq and OpenRouter use their chat-completions endpoint; Gemini uses its native generateContent API. '
              'Load models to pick from the provider list, or type the base URL and load again if the list is unavailable.',
              style: theme.typography.baseline.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const SectionTitle('AnkiDroid'),
          ref
              .watch(ankiStatusProvider)
              .when(
                loading: () => const Center(child: M3ELoadingIndicator()),
                error: (error, stackTrace) => Text('$error'),
                data: (status) => _AnkiStatusCard(
                  status: status,
                  onCheck: () => ref.invalidate(ankiStatusProvider),
                  onPermission: _requestAnkiPermission,
                  onOpen: () => ref.read(ankiGatewayProvider).openAnkiDroid(),
                ),
              ),
          const SizedBox(height: 12),
          M3ETextField(
            controller: _deck,
            label: 'Deck name',
            supportingText: 'Default for topics without their own deck. Created if missing.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              M3EButton.tonal(
                onPressed: () async {
                  final name = _deck.text.trim();
                  if (name.isEmpty) {
                    await showSnack(context, 'Deck name cannot be empty.');
                    return;
                  }
                  await _save(settings.copyWith(ankiDeck: name));
                  if (!context.mounted) return;
                  await showSnack(context, 'Deck name saved.');
                },
                child: const Text('Save deck name'),
              ),
              M3EButton.text(
                onPressed: _busy ? null : _browseDecks,
                child: const Text('Browse decks'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionTitle('Data'),
          Text(
            'Practices, sessions, error cards, concepts and settings live only on this device.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          M3EButton.outlined(
            onPressed: _busy ? null : _eraseAll,
            icon: const Icon(Icons.delete_outline),
            child: const Text('Erase all data'),
          ),
          const SizedBox(height: 32),
          const SectionTitle('About'),
          Text(
            'Question Practice 1.0.0\nLocal-first practice with error cards and Anki export.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
  }

  List<String> get _modelOptions {
    final current = _model.text.trim();
    return <String>{if (current.isNotEmpty) current, ..._models}.toList()
      ..sort();
  }

  Future<void> _loadModels() async {
    final rawBaseUrl = _baseUrl.text.trim();
    final baseUrl = rawBaseUrl.isEmpty
        ? _baseUrlFor(_provider, rawBaseUrl)
        : rawBaseUrl;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      await showSnack(context, 'Enter a valid http(s) base URL first.');
      return;
    }
    final key = _apiKey.text.trim().isNotEmpty
        ? _apiKey.text.trim()
        : await ref.read(settingsRepositoryProvider).readApiKey();
    if (!mounted) return;
    if (key == null || key.trim().isEmpty) {
      await showSnack(context, 'Save an API key or paste one first.');
      return;
    }
    setState(() => _loadingModels = true);
    try {
      final models = await ref
          .read(lookupServiceProvider)
          .listModels(provider: _provider, baseUrl: baseUrl, apiKey: key);
      if (!mounted) return;
      setState(() {
        _models = models;
        if (_model.text.trim().isEmpty && models.isNotEmpty) {
          _model.text = models.first;
        }
      });
      if (models.isEmpty) {
        await showSnack(context, 'The provider returned no models.');
      }
    } on LookupException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  String _providerLabel(AiProvider provider) {
    return switch (provider) {
      AiProvider.openai => 'OpenAI',
      AiProvider.groq => 'Groq',
      AiProvider.openRouter => 'OpenRouter',
      AiProvider.gemini => 'Gemini',
      AiProvider.custom => 'Custom',
    };
  }

  Future<void> _saveAi(AppSettings settings) async {
    final baseUrl = _baseUrl.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isNotEmpty &&
        (uri == null ||
            !(uri.isScheme('http') || uri.isScheme('https')) ||
            uri.host.isEmpty)) {
      await showSnack(context, 'Enter a valid http(s) base URL.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _save(
        settings.copyWith(
          aiProvider: _provider,
          aiBaseUrl: baseUrl.isEmpty ? settings.aiBaseUrl : baseUrl,
          aiModel: _model.text.trim(),
        ),
      );
      if (!mounted) return;
      await showSnack(context, 'AI settings saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      await showSnack(context, 'Paste an API key first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).saveApiKey(key);
      _apiKey.clear();
      ref.invalidate(hasApiKeyProvider);
      if (mounted) await showSnack(context, 'API key saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeKey() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Remove API key?',
      message: 'AI lookup will stop working until a new key is saved.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(settingsRepositoryProvider).deleteApiKey();
    ref.invalidate(hasApiKeyProvider);
    if (mounted) await showSnack(context, 'API key removed.');
  }

  Future<void> _testConnection() async {
    setState(() => _busy = true);
    try {
      final definition = await ref.read(lookupServiceProvider).testConnection();
      if (!mounted) return;
      await M3EDialog.show<void>(
        context,
        dialog: M3EDialog(
          title: 'Connection works',
          content: Text('The provider returned: $definition'),
          actions: [
            M3EButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on LookupException catch (error) {
      if (mounted) {
        await M3EDialog.show<void>(
          context,
          dialog: M3EDialog(
            title: 'Connection failed',
            content: Text(error.message),
            actions: [
              M3EButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestAnkiPermission() async {
    await ref.read(ankiGatewayProvider).requestPermission();
    ref.invalidate(ankiStatusProvider);
  }

  Future<void> _browseDecks() async {
    final selected = await showAnkiDeckPicker(
      context,
      ref,
      current: _deck.text.trim(),
      allowDefault: false,
    );
    if (selected == null || selected.trim().isEmpty || !mounted) return;
    setState(() => _deck.text = selected.trim());
  }

  Future<void> _eraseAll() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Erase all data?',
      message: 'This deletes every practice, session, answer, error card, concept and the saved API key. It cannot be undone.',
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).clearAll();
      await ref.read(settingsRepositoryProvider).deleteApiKey();
      ref.invalidate(settingsProvider);
      ref.invalidate(hasApiKeyProvider);
      ref.invalidate(topicSummariesProvider);
      ref.invalidate(homeStatsProvider);
      if (!mounted) return;
      await showSnack(context, 'All data erased.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _baseUrlFor(AiProvider provider, String current) {
    return switch (provider) {
      AiProvider.openai => 'https://api.openai.com/v1',
      AiProvider.groq => 'https://api.groq.com/openai/v1',
      AiProvider.openRouter => 'https://openrouter.ai/api/v1',
      AiProvider.gemini => 'https://generativelanguage.googleapis.com/v1beta',
      AiProvider.custom => current,
    };
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.baseline.bodyLarge),
              Text(
                subtitle,
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        M3ESwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _AnkiStatusCard extends StatelessWidget {
  const _AnkiStatusCard({
    required this.status,
    required this.onCheck,
    required this.onPermission,
    required this.onOpen,
  });

  final AnkiStatus status;
  final VoidCallback onCheck;
  final VoidCallback onPermission;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final installed = status.installed;
    final api = status.apiAvailable;
    final permission = status.permissionGranted;
    final cloze = status.conceptModelAvailable;
    return TonalBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(label: 'AnkiDroid installed', ok: installed),
          _StatusLine(label: 'API enabled', ok: api),
          _StatusLine(label: 'Database permission', ok: permission),
          _StatusLine(label: 'Cloze note type', ok: cloze),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              M3EButton.text(
                onPressed: onCheck,
                child: const Text('Check again'),
              ),
              if (installed && !permission)
                M3EButton.tonal(
                  onPressed: onPermission,
                  child: const Text('Grant permission'),
                ),
              if (installed)
                M3EButton.text(
                  onPressed: onOpen,
                  child: const Text('Open AnkiDroid'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.typography.baseline.bodySmall),
        ],
      ),
    );
  }
}
