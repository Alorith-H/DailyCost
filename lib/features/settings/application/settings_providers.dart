import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/schema.dart';
import '../../../data/providers.dart';
import '../../../domain/models/app_settings.dart';
import '../../../domain/models/enums.dart';

/// 设置状态。初始值由 main() 预载后覆写（避免启动时主题闪烁）。
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier([AppSettings? initial]) : _initial = initial;

  final AppSettings? _initial;

  @override
  AppSettings build() {
    return _initial ?? AppSettings.defaults;
  }

  Future<void> setThemeMode(ThemePref pref) async {
    state = state.copyWith(themeMode: pref);
    await ref.read(settingsRepositoryProvider).setThemeMode(pref);
  }

  Future<void> setCoffeePriceFen(int fen) async {
    state = state.copyWith(coffeePriceFen: fen);
    await ref.read(settingsRepositoryProvider).setCoffeePriceFen(fen);
  }

  Future<void> setAutoUpdateCheck(bool enabled) async {
    state = state.copyWith(autoUpdateCheck: enabled);
    await ref.read(settingsRepositoryProvider).setAutoUpdateCheck(enabled);
  }

  Future<void> setFxRate(String currency, double rateToCny) async {
    state = state.copyWith(
      fxRates: {...state.fxRates, currency: rateToCny},
    );
    await ref.read(settingsRepositoryProvider).setFxRate(currency, rateToCny);
  }

  Future<void> setNotifyExpiry(bool v) async {
    state = state.copyWith(notifyExpiry: v);
    await ref.read(settingsRepositoryProvider)
        .setNotify(SettingsKeys.notifyExpiry, v);
  }

  Future<void> setNotifyRenewal(bool v) async {
    state = state.copyWith(notifyRenewal: v);
    await ref.read(settingsRepositoryProvider)
        .setNotify(SettingsKeys.notifyRenewal, v);
  }

  Future<void> setNotifyWeekly(bool v) async {
    state = state.copyWith(notifyWeekly: v);
    await ref.read(settingsRepositoryProvider)
        .setNotify(SettingsKeys.notifyWeekly, v);
  }

  Future<void> setNotifyBackup(bool v) async {
    state = state.copyWith(notifyBackup: v);
    await ref.read(settingsRepositoryProvider)
        .setNotify(SettingsKeys.notifyBackup, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// 供 MaterialApp 使用的主题模式。
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingsProvider).themeMode) {
    ThemePref.system => ThemeMode.system,
    ThemePref.light => ThemeMode.light,
    ThemePref.dark => ThemeMode.dark,
  };
});

/// 咖啡单价（元），供试算器对比。
final coffeePriceProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider).coffeePriceYuan,
);

/// 离线汇率表（1 外币 → 人民币）。
final fxRatesProvider = Provider<Map<String, double>>(
  (ref) => ref.watch(settingsProvider).fxRates,
);
