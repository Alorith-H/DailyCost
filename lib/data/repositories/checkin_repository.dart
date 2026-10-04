import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

/// checkins 仓储：使用打卡。
class CheckinRepository {
  CheckinRepository(this._db);

  final AppDatabase _db;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 打卡（同一天重复打卡幂等）。返回是否为新打卡。
  Future<bool> checkIn(int itemId, DateTime day, {String note = ''}) async {
    final before = await countSince(itemId, day);
    await _db.db.insert('checkins', {
      'item_id': itemId,
      'checked_on': _date(day),
      'note': note,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final after = await countSince(itemId, day);
    return after > before;
  }

  /// 撤销某天打卡。
  Future<void> undoCheckIn(int itemId, DateTime day) async {
    await _db.db.delete(
      'checkins',
      where: 'item_id = ? AND checked_on = ?',
      whereArgs: [itemId, _date(day)],
    );
  }

  /// 自 [since]（含）以来的打卡天数。
  Future<int> countSince(int itemId, DateTime since) async {
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM checkins '
      'WHERE item_id = ? AND checked_on >= ?',
      [itemId, _date(since)],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 最近一次打卡日期；从未打卡返回 null。
  Future<DateTime?> lastCheckIn(int itemId) async {
    final rows = await _db.db.rawQuery(
      'SELECT MAX(checked_on) AS d FROM checkins WHERE item_id = ?',
      [itemId],
    );
    final raw = rows.first['d'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// 打卡日期列表（用于统计）。
  Future<List<DateTime>> checkInsSince(int itemId, DateTime since) async {
    final rows = await _db.db.query(
      'checkins',
      columns: ['checked_on'],
      where: 'item_id = ? AND checked_on >= ?',
      whereArgs: [itemId, _date(since)],
      orderBy: 'checked_on',
    );
    return [
      for (final r in rows) DateTime.parse(r['checked_on'] as String),
    ];
  }
}
