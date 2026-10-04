/// 导入与恢复：CSV 导入、备份 zip 恢复。
///
/// 恢复只替换数据库/照片文件；由于旧句柄仍持有旧文件，
/// 数据在应用下次启动时生效（提示用户重启）。
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/item.dart';
import 'csv_codec.dart';

class ImportService {
  /// 解析 CSV 并批量入库，返回导入条数。
  Future<({int imported, int skipped})> importCsv(
    String content,
    Future<void> Function(ItemDraft draft) insert,
  ) async {
    // 去掉 Excel 保存的 BOM，避免首列列名匹配失败
    final result = csvToDrafts(content.replaceAll('﻿', ''));
    for (final draft in result.drafts) {
      await insert(draft);
    }
    return (imported: result.drafts.length, skipped: result.skipped);
  }

  /// 从备份 zip 恢复：覆盖数据库与照片目录（下次启动生效）。
  Future<void> restoreBackup({
    required String zipPath,
    required String dbPath,
    required String photosDirPath,
  }) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 先解到临时目录校验，再覆盖，避免半截备份毁掉现有数据
    final tmpDir = Directory.systemTemp.createTempSync('dailycost_restore_');
    var foundDb = false;
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      final target = File(p.join(tmpDir.path, name));
      await target.create(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
      if (name == 'dailycost.db') foundDb = true;
    }
    if (!foundDb) {
      throw const FormatException('备份文件缺少 dailycost.db');
    }

    // 覆盖照片
    final photosSrc = Directory(p.join(tmpDir.path, 'photos'));
    final photosDst = Directory(photosDirPath);
    if (await photosDst.exists()) {
      await photosDst.delete(recursive: true);
    }
    await photosDst.create(recursive: true);
    if (await photosSrc.exists()) {
      await for (final entity in photosSrc.list()) {
        if (entity is File) {
          await entity.copy(p.join(photosDst.path, p.basename(entity.path)));
        }
      }
    }

    // 覆盖数据库
    await File(p.join(tmpDir.path, 'dailycost.db')).copy(dbPath);
    await tmpDir.delete(recursive: true);
  }
}
