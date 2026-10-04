import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// 应用数据库句柄。生产用 [open]；测试用 [open] 并传入 ffi 工厂与内存路径。
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  /// 打开（或创建）数据库。
  ///
  /// [factory]/[dbPath] 主要供测试注入（sqflite_common_ffi + 内存库）；
  /// 生产环境默认使用应用文档目录下的 dailycost.db。
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? dbPath,
  }) async {
    final path = dbPath ??
        p.join((await getApplicationDocumentsDirectory()).path, 'dailycost.db');
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (final sql in schemaSql) {
            await db.execute(sql);
          }
          final batch = db.batch();
          settingsSeed.forEach((key, value) {
            batch.insert('settings', {'key': key, 'value': value});
          });
          await batch.commit(noResult: true);
        },
      ),
    );
    return AppDatabase(db);
  }

  Future<void> close() => db.close();
}
