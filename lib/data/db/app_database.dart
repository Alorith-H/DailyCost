import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'schema.dart';

/// 应用数据库句柄（SQLCipher 加密）。
///
/// - 生产：[open] 传入 [password]，数据库整体加密（密钥存系统安全存储）；
/// - 测试：不传 [password] 为明文，可配合 sqflite_common_ffi 在主机运行；
/// - 旧明文库（v0.1.0）首次带密码打开失败时自动 `PRAGMA rekey` 就地加密迁移。
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? dbPath,
    String? password,
  }) async {
    final path = dbPath ??
        p.join((await getApplicationDocumentsDirectory()).path, 'dailycost.db');
    final f = factory ?? databaseFactory;
    try {
      return AppDatabase(await _openWith(f, path, password));
    } catch (_) {
      if (password == null || password.isEmpty) rethrow;
      // 旧明文库：明文打开 → rekey 就地加密 → 再带密码打开
      await _encryptLegacy(f, path, password);
      return AppDatabase(await _openWith(f, path, password));
    }
  }

  static Future<Database> _openWith(
    DatabaseFactory f,
    String path,
    String? password,
  ) {
    final OpenDatabaseOptions options;
    if (password == null || password.isEmpty) {
      options = OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      options = SqlCipherOpenDatabaseOptions(
        version: schemaVersion,
        password: password,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    return f.openDatabase(path, options: options);
  }

  static Future<void> _onConfigure(Database db) =>
      db.execute('PRAGMA foreign_keys = ON');

  static Future<void> _onCreate(Database db, int version) async {
    for (final sql in schemaSql) {
      await db.execute(sql);
    }
    final batch = db.batch();
    settingsSeed.forEach((key, value) {
      batch.insert('settings', {'key': key, 'value': value});
    });
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      for (final sql in migrationV1ToV2) {
        await db.execute(sql);
      }
    }
  }

  static Future<void> _encryptLegacy(
    DatabaseFactory f,
    String path,
    String password,
  ) async {
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      final escaped = password.replaceAll("'", "''");
      await db.execute("PRAGMA rekey = '$escaped'");
    } finally {
      await db.close();
    }
  }

  Future<void> close() => db.close();
}
