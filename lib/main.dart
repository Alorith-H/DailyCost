import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // 数据库口令：首次生成 256 位随机口令，存入系统安全存储（Keystore/Keychain）
  const storage = FlutterSecureStorage();
  var passphrase = await storage.read(key: 'db_passphrase');
  if (passphrase == null || passphrase.isEmpty) {
    final rnd = Random.secure();
    passphrase = List.generate(
      32,
      (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.write(key: 'db_passphrase', value: passphrase);
  }

  // 打开加密库并预载设置，避免启动时主题闪烁
  final db = await AppDatabase.open(password: passphrase);
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
