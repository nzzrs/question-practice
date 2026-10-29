import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<Map<String, String>> watchAll() {
    return select(settings)
        .watch()
        .map((rows) => {for (final row in rows) row.key: row.value});
  }

  Future<Map<String, String>> getAll() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<String?> getValue(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(
      settings,
    ).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  Future<void> removeValue(String key) {
    return (delete(settings)..where((s) => s.key.equals(key))).go();
  }

  Future<void> clear() {
    return delete(settings).go();
  }
}
