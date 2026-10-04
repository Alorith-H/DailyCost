import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
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
      // 旧库可能没有该键：默认开启
      autoUpdateCheck: map[SettingsKeys.autoUpdateCheck] != '0',
      fxRates: _parseFxRates(map[SettingsKeys.fxRates]),
      notifyExpiry: map[SettingsKeys.notifyExpiry] != '0',
      notifyRenewal: map[SettingsKeys.notifyRenewal] != '0',
      notifyWeekly: map[SettingsKeys.notifyWeekly] != '0',
      notifyBackup: map[SettingsKeys.notifyBackup] != '0',
    );
  }

  /// 读取用户覆盖值并与默认离线汇率表合并。
  Map<String, double> _parseFxRates(String? raw) {
    final overrides = <String, double>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final rate = (v as num?)?.toDouble();
          if (rate != null && rate > 0) overrides[k] = rate;
        });
      } catch (_) {
        // 忽略损坏的 JSON，回退默认
      }
    }
    return {...kDefaultFxToCny, ...overrides};
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

  Future<void> setAutoUpdateCheck(bool enabled) =>
      setValue(SettingsKeys.autoUpdateCheck, enabled ? '1' : '0');

  /// 覆盖单个币种汇率（其余保持不变）。
  Future<void> setFxRate(String currency, double rateToCny) async {
    final current = await readAll();
    final merged = {...current.fxRates, currency: rateToCny};
    await setValue(SettingsKeys.fxRates, jsonEncode(merged));
  }

  Future<void> setNotify(String key, bool enabled) =>
      setValue(key, enabled ? '1' : '0');
}
