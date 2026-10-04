import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
