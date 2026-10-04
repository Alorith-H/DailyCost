import 'package:sqflite/sqflite.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../db/app_database.dart';

/// items / item_tags 仓储。金额在边界处分↔元转换（库存分）。
class ItemRepository {
  ItemRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(ItemDraft draft, List<String> tags) async {
    final now = DateTime.now();
    final db = _db.db;
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('items', {
        ..._itemToRow(
          name: draft.name,
          price: draft.price,
          residual: draft.residual,
          category: draft.category,
          purchaseDate: draft.purchaseDate,
          endDate: draft.endDate,
          usageDays: draft.usageDays,
          totalUses: draft.totalUses,
          usesPerDay: draft.usesPerDay,
          totalHours: draft.totalHours,
          hoursPerDay: draft.hoursPerDay,
          cycleUnit: draft.cycleUnit,
          cycleLength: draft.cycleLength,
          calcMode: draft.calcMode,
          depreciation: draft.depreciation,
          note: draft.note,
          createdAt: now,
          updatedAt: now,
        ),
      });
      await _replaceTags(txn, id, tags);
    });
    return id;
  }

  Future<void> update(Item item, List<String> tags) async {
    final now = DateTime.now();
    await _db.db.transaction((txn) async {
      await txn.update(
        'items',
        {
          ..._itemToRow(
            name: item.name,
            price: item.price,
            residual: item.residual,
            category: item.category,
            purchaseDate: item.purchaseDate,
            endDate: item.endDate,
            usageDays: item.usageDays,
            totalUses: item.totalUses,
            usesPerDay: item.usesPerDay,
            totalHours: item.totalHours,
            hoursPerDay: item.hoursPerDay,
            cycleUnit: item.cycleUnit,
            cycleLength: item.cycleLength,
            calcMode: item.calcMode,
            depreciation: item.depreciation,
            note: item.note,
            createdAt: item.createdAt,
            updatedAt: now,
          ),
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await _replaceTags(txn, item.id, tags);
    });
  }

  /// 软删除（回收站预留）。
  Future<void> softDelete(int id) async {
    await _db.db.update(
      'items',
      {'deleted_at': _tsToDb(DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restore(int id) async {
    await _db.db.update(
      'items',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Item>> findAll({bool includeDeleted = false}) async {
    final rows = await _db.db.query(
      'items',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'purchase_date DESC, id DESC',
    );
    return _mapRowsWithTags(rows);
  }

  Future<Item?> findById(int id) async {
    final rows = await _db.db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await _mapRowsWithTags(rows);
    return items.first;
  }

  // ---------- 内部 ----------

  Future<List<Item>> _mapRowsWithTags(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final tagRows = await _db.db.rawQuery(
      'SELECT item_id, name FROM item_tags '
      'JOIN tags ON tags.id = item_tags.tag_id '
      'WHERE item_id IN (${ids.map((_) => '?').join(',')}) '
      'ORDER BY tags.name',
      ids,
    );
    final tagsByItem = <int, List<String>>{};
    for (final r in tagRows) {
      tagsByItem.putIfAbsent(r['item_id'] as int, () => []).add(r['name'] as String);
    }
    return rows.map((r) {
      final id = r['id'] as int;
      return _rowToItem(r, tagsByItem[id] ?? const []);
    }).toList();
  }

  Future<void> _replaceTags(Transaction txn, int itemId, List<String> tags) async {
    await txn.delete('item_tags', where: 'item_id = ?', whereArgs: [itemId]);
    for (final name in tags) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      await txn.execute(
        'INSERT OR IGNORE INTO tags(name) VALUES (?)',
        [trimmed],
      );
      final rows = await txn.query(
        'tags',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [trimmed],
        limit: 1,
      );
      final tagId = rows.first['id'] as int;
      await txn.execute(
        'INSERT OR IGNORE INTO item_tags(item_id, tag_id) VALUES (?, ?)',
        [itemId, tagId],
      );
    }
  }

  Map<String, Object?> _itemToRow({
    required String name,
    required double price,
    required double residual,
    required String category,
    required DateTime purchaseDate,
    required DateTime? endDate,
    required int? usageDays,
    required int? totalUses,
    required double? usesPerDay,
    required int? totalHours,
    required double? hoursPerDay,
    required CycleUnit? cycleUnit,
    required int? cycleLength,
    required CalcMode calcMode,
    required DepreciationMethod depreciation,
    required String note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => {
    'name': name,
    'price_fen': _yuanToFen(price),
    'residual_fen': _yuanToFen(residual),
    'category': category,
    'purchase_date': _dateToDb(purchaseDate),
    'end_date': endDate == null ? null : _dateToDb(endDate),
    'usage_days': usageDays,
    'total_uses': totalUses,
    'uses_per_day': usesPerDay,
    'total_hours': totalHours,
    'hours_per_day': hoursPerDay,
    'cycle_unit': cycleUnit?.name,
    'cycle_length': cycleLength,
    'calc_mode': calcMode.name,
    'depreciation': depreciation.name,
    'note': note,
    'created_at': _tsToDb(createdAt),
    'updated_at': _tsToDb(updatedAt),
    'deleted_at': null,
  };

  Item _rowToItem(Map<String, Object?> r, List<String> tags) => Item(
    id: r['id'] as int,
    name: r['name'] as String,
    price: _fenToYuan(r['price_fen'] as int),
    residual: _fenToYuan(r['residual_fen'] as int),
    category: r['category'] as String,
    purchaseDate: _dateFromDb(r['purchase_date'] as String),
    endDate: r['end_date'] == null ? null : _dateFromDb(r['end_date'] as String),
    usageDays: r['usage_days'] as int?,
    totalUses: r['total_uses'] as int?,
    usesPerDay: (r['uses_per_day'] as num?)?.toDouble(),
    totalHours: r['total_hours'] as int?,
    hoursPerDay: (r['hours_per_day'] as num?)?.toDouble(),
    cycleUnit: r['cycle_unit'] == null
        ? null
        : CycleUnit.values.asNameMap()[r['cycle_unit'] as String],
    cycleLength: r['cycle_length'] as int?,
    calcMode: CalcMode.values.byName(r['calc_mode'] as String),
    depreciation: DepreciationMethod.values.byName(r['depreciation'] as String),
    note: r['note'] as String,
    tags: tags,
    createdAt: _tsFromDb(r['created_at'] as String),
    updatedAt: _tsFromDb(r['updated_at'] as String),
    deletedAt: r['deleted_at'] == null ? null : _tsFromDb(r['deleted_at'] as String),
  );

  static int _yuanToFen(double yuan) => (yuan * 100).round();
  static double _fenToYuan(int fen) => fen / 100.0;
  static String _dateToDb(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  static DateTime _dateFromDb(String s) {
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static String _tsToDb(DateTime d) => d.toIso8601String();
  static DateTime _tsFromDb(String s) => DateTime.parse(s);
}
