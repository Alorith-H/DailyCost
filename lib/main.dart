import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/providers.dart';
import 'data/repositories/settings_repository.dart';
import 'features/settings/application/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 中文数字/日期格式（本地符号数据，无网络）
  Intl.defaultLocale = 'zh_CN';
  await initializeDateFormatting('zh_CN');

  // 打开本地库并预载设置，避免启动时主题闪烁
  final db = await AppDatabase.open();
  final settings = await SettingsRepository(db).readAll();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsProvider.overrideWith(() => SettingsNotifier(settings)),
      ],
      child: const DailyCostApp(),
    ),
  );
}
