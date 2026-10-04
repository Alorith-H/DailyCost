import 'package:daily_cost/data/providers.dart';
import 'package:daily_cost/data/repositories/settings_repository.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  test('设置持久化：状态变更写库并可读回', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsProvider.overrideWith(() => SettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    // 初始为默认
    expect(container.read(settingsProvider).themeMode, ThemePref.system);

    await container.read(settingsProvider.notifier).setThemeMode(ThemePref.dark);
    await container
        .read(settingsProvider.notifier)
        .setCoffeePriceFen(2500);

    // 状态已更新
    expect(container.read(settingsProvider).themeMode, ThemePref.dark);
    expect(container.read(settingsProvider).coffeePriceFen, 2500);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(container.read(coffeePriceProvider), closeTo(25.0, 0.001));

    // 已落库，重新读回一致（round-trip）
    final loaded = await SettingsRepository(db).readAll();
    expect(loaded.themeMode, ThemePref.dark);
    expect(loaded.coffeePriceFen, 2500);
  });
}
