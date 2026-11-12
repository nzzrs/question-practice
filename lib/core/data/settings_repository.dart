import '../database/daos/settings_dao.dart';
import '../domain/list_sort.dart';
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
  static const _dynamicColorKey = 'dynamic_color';
  static const _soundsEnabledKey = 'sounds_enabled';
  static const _soundVolumeKey = 'sound_volume';
  static const _ankiDeckKey = 'anki_deck';
  static const _homeTopicSortKey = 'home_topic_sort';

  static String _topicPracticeSortKey(int topicId) =>
      'topic_practice_sort_$topicId';

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
    await _dao.setValue(_dynamicColorKey, settings.dynamicColor.toString());
    await _dao.setValue(_soundsEnabledKey, settings.soundsEnabled.toString());
    await _dao.setValue(
      _soundVolumeKey,
      settings.soundVolume.clamp(0.0, 1.0).toString(),
    );
    await _dao.setValue(_ankiDeckKey, settings.ankiDeck.trim());
  }

  /// The saved order of the Home topic list, or null for the default
  /// priority-and-name order.
  Stream<ListSort?> watchHomeTopicSort() {
    return _dao.watchValue(_homeTopicSortKey).map(ListSort.tryDecode);
  }

  Future<ListSort?> loadHomeTopicSort() async {
    return ListSort.tryDecode(await _dao.getValue(_homeTopicSortKey));
  }

  Future<void> saveHomeTopicSort(ListSort sort) {
    return _dao.setValue(_homeTopicSortKey, sort.encode());
  }

  /// The saved practice order for one topic.
  ///
  /// An absent value falls back to the existing name-ascending order.
  Stream<ListSort> watchTopicPracticeSort(int topicId) {
    return _dao
        .watchValue(_topicPracticeSortKey(topicId))
        .map((raw) => ListSort.tryDecode(raw) ?? ListSort.defaultByName);
  }

  Future<ListSort> loadTopicPracticeSort(int topicId) async {
    final raw = await _dao.getValue(_topicPracticeSortKey(topicId));
    return ListSort.tryDecode(raw) ?? ListSort.defaultByName;
  }

  Future<void> saveTopicPracticeSort(int topicId, ListSort sort) {
    return _dao.setValue(_topicPracticeSortKey(topicId), sort.encode());
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
      dynamicColor: _bool(map[_dynamicColorKey], defaults.dynamicColor),
      soundsEnabled: _bool(map[_soundsEnabledKey], defaults.soundsEnabled),
      soundVolume: _volume(map[_soundVolumeKey], defaults.soundVolume),
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

  double _volume(String? raw, double fallback) {
    final value = double.tryParse(raw?.trim() ?? '');
    if (value == null) return fallback;
    return value.clamp(0.0, 1.0);
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
