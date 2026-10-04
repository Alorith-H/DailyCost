import 'dart:io';

import 'package:daily_cost/data/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 打开独立的测试库（Windows 主机走 sqflite_common_ffi）。
///
/// 两个坑：
/// 1. `:memory:` 路径在 sqflite 中是共享连接，测试之间会串数据 → 用独立临时文件；
/// 2. `databaseFactoryFfi` 走后台 isolate，`testWidgets` 的 FakeAsync 下
///    future 不会完成 → 用同 isolate 的 `databaseFactoryFfiNoIsolate`。
///
/// 调用方用完请 [AppDatabase.close]。
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('dailycost_test_');
  return AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    dbPath: '${dir.path}${Platform.pathSeparator}test.db',
  );
}
