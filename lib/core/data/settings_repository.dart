import '../database/daos/settings_dao.dart';
import '../domain/models.dart';
import '../platform/secure_key_store.dart';

class SettingsRepository {
  SettingsRepository(this._dao, this._keyStore);

  final SettingsDao _dao;
  final SecureKeyStore _keyStore;

  static const _lookupModeKey = 'lookup_mode';
  static const _webEngineKey = 'web_engine';
  static const _aiProviderKey = 'ai_provider';
  static const _aiBaseUrlKey = 'ai_base_url';
  static const _aiModelKey = 'ai_model';
  static const _shuffleTopicsKey = 'shuffle_topics';
  static const _dynamicColorKey = 'dynamic_color';
  static const _ankiDeckKey = 'anki_deck';

  Stream<AppSettings> watch() {
    return _dao.watchAll().map(_fromMap);
  }

  Future<AppSettings> load() async => _fromMap(await _dao.getAll());

  Future<void> save(AppSettings settings) async {
    await _dao.setValue(_lookupModeKey, settings.lookupMode.name);
    await _dao.setValue(_webEngineKey, settings.webEngine.name);
    await _dao.setValue(_aiProviderKey, settings.aiProvider.name);
    await _dao.setValue(_aiBaseUrlKey, settings.aiBaseUrl.trim());
    await _dao.setValue(_aiModelKey, settings.aiModel.trim());
    await _dao.setValue(_shuffleTopicsKey, settings.shuffleTopics.toString());
    await _dao.setValue(_dynamicColorKey, settings.dynamicColor.toString());
    await _dao.setValue(_ankiDeckKey, settings.ankiDeck.trim());
  }

  Future<bool> hasApiKey() async {
    final key = await _keyStore.readApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  Future<String?> readApiKey() => _keyStore.readApiKey();

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _keyStore.deleteApiKey();
    } else {
      await _keyStore.writeApiKey(trimmed);
    }
  }

  Future<void> deleteApiKey() => _keyStore.deleteApiKey();

  AppSettings _fromMap(Map<String, String> map) {
    const defaults = AppSettings();
    return AppSettings(
      lookupMode: _enumByName(
        LookupMode.values,
        map[_lookupModeKey],
        defaults.lookupMode,
      ),
      webEngine: _enumByName(
        WebEngine.values,
        map[_webEngineKey],
        defaults.webEngine,
      ),
      aiProvider: _enumByName(
        AiProvider.values,
        map[_aiProviderKey],
        defaults.aiProvider,
      ),
      aiBaseUrl: _nonEmpty(map[_aiBaseUrlKey], defaults.aiBaseUrl),
      aiModel: map[_aiModelKey] ?? defaults.aiModel,
      shuffleTopics: _bool(map[_shuffleTopicsKey], defaults.shuffleTopics),
      dynamicColor: _bool(map[_dynamicColorKey], defaults.dynamicColor),
      ankiDeck: _nonEmpty(map[_ankiDeckKey], defaults.ankiDeck),
    );
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  bool _bool(String? raw, bool fallback) {
    if (raw == null) return fallback;
    return raw.toLowerCase() == 'true';
  }

  String _nonEmpty(String? raw, String fallback) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}
