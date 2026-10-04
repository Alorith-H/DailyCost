import 'package:sqflite/sqflite.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/enums.dart';
import '../db/app_database.dart';
import '../db/schema.dart';

/// settings 表仓储（key-value）。
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<AppSettings> readAll() async {
    final rows = await _db.db.query('settings');
    final map = {
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
    return AppSettings(
      themeMode: ThemePref.fromSettingsValue(map[SettingsKeys.themeMode]),
      coffeePriceFen: int.tryParse(map[SettingsKeys.coffeePriceFen] ?? '') ??
          AppSettings.defaults.coffeePriceFen,
    );
  }

  Future<void> setValue(String key, String value) async {
    await _db.db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setThemeMode(ThemePref pref) =>
      setValue(SettingsKeys.themeMode, pref.settingsValue);

  Future<void> setCoffeePriceFen(int fen) =>
      setValue(SettingsKeys.coffeePriceFen, '$fen');
}
