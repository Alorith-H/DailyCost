import 'package:daily_cost/data/db/app_database.dart';
import 'package:daily_cost/data/db/schema.dart';
import 'package:daily_cost/data/repositories/settings_repository.dart';
import 'package:daily_cost/domain/models/app_settings.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('种子行存在', () async {
    final settings = await repo.readAll();
    expect(settings.themeMode, ThemePref.system);
    expect(settings.coffeePriceFen, 1500);
    expect(settings.coffeePriceYuan, closeTo(15.0, 0.001));
  });

  test('写入后读回', () async {
    await repo.setThemeMode(ThemePref.dark);
    await repo.setCoffeePriceFen(2500);
    final settings = await repo.readAll();
    expect(settings.themeMode, ThemePref.dark);
    expect(settings.coffeePriceFen, 2500);
  });

  test('未知键读取回退默认值', () async {
    await repo.setValue(SettingsKeys.coffeePriceFen, 'not-a-number');
    final settings = await repo.readAll();
    expect(settings.coffeePriceFen, AppSettings.defaults.coffeePriceFen);
  });

  test('setValue 覆盖已存在的键', () async {
    await repo.setValue('theme_mode', 'light');
    await repo.setValue('theme_mode', 'dark');
    final settings = await repo.readAll();
    expect(settings.themeMode, ThemePref.dark);
  });
}
