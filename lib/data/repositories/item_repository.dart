import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../../domain/models/item_cost.dart';
import '../db/app_database.dart';

/// items / item_tags / item_costs 仓储。金额在边界处分↔元转换（库存分）。
class ItemRepository {
  ItemRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(ItemDraft draft, List<String> tags) async {
    final now = DateTime.now();
    late int id;
    await _db.db.transaction((txn) async {
      id = await txn.insert('items', {
        ..._draftToRow(draft, createdAt: now, updatedAt: now),
      });
      await _replaceTags(txn, id, tags);
      await _replaceCosts(txn, id, draft.extraCosts, now);
    });
    return id;
  }

  Future<void> update(Item item, List<String> tags) async {
    final now = DateTime.now();
    await _db.db.transaction((txn) async {
      await txn.update(
        'items',
        {
          ..._draftToRow(
            ItemDraft(
              name: item.name,
              price: item.price,
              residual: item.residual,
              category: item.category,
              purchaseDate: item.purchaseDate,
              currency: item.currency,
              aprPercent: item.aprPercent,
              installmentMonths: item.installmentMonths,
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
              tags: item.tags,
              photos: item.photos,
              extraCosts: const [],
            ),
            createdAt: item.createdAt,
            updatedAt: now,
          ),
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await _replaceTags(txn, item.id, tags);
      await _replaceCosts(
        txn,
        item.id,
        [
          for (final c in item.extraCosts)
            ItemCostDraft(category: c.category, amount: c.amount, note: c.note),
        ],
        now,
      );
    });
  }

  /// 软删除（回收站预留）。
  Future<void> softDelete(int id) async {
    await _db.db.update(
      'items',
      {'deleted_at': DateTime.now().toIso8601String()},
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

  /// 清空回收站：硬删除 30 天前软删除的记录。
  Future<void> purgeDeletedBefore(DateTime cutoff) async {
    await _db.db.delete(
      'items',
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// 彻底删除（含软删除记录），不可恢复。
  Future<void> hardDelete(int id) async {
    await _db.db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Item>> findAll({bool includeDeleted = false}) async {
    final rows = await _db.db.query(
      'items',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'purchase_date DESC, id DESC',
    );
    return _mapRowsWithRelations(rows);
  }

  Future<Item?> findById(int id) async {
    final rows = await _db.db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await _mapRowsWithRelations(rows);
    return items.first;
  }

  // ---------- 内部 ----------

  Future<List<Item>> _mapRowsWithRelations(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = ids.map((_) => '?').join(',');

    final tagRows = await _db.db.rawQuery(
      'SELECT item_id, name FROM item_tags '
      'JOIN tags ON tags.id = item_tags.tag_id '
      'WHERE item_id IN ($placeholders) ORDER BY tags.name',
      ids,
    );
    final tagsByItem = <int, List<String>>{};
    for (final r in tagRows) {
      tagsByItem.putIfAbsent(r['item_id'] as int, () => []).add(r['name'] as String);
    }

    final costRows = await _db.db.rawQuery(
      'SELECT * FROM item_costs WHERE item_id IN ($placeholders) ORDER BY id',
      ids,
    );
    final costsByItem = <int, List<ItemCost>>{};
    for (final r in costRows) {
      final cost = _rowToCost(r);
      costsByItem.putIfAbsent(cost.itemId, () => []).add(cost);
    }

    return rows.map((r) {
      final id = r['id'] as int;
      return _rowToItem(
        r,
        tagsByItem[id] ?? const [],
        costsByItem[id] ?? const [],
      );
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

  Future<void> _replaceCosts(
    Transaction txn,
    int itemId,
    List<ItemCostDraft> costs,
    DateTime now,
  ) async {
    await txn.delete('item_costs', where: 'item_id = ?', whereArgs: [itemId]);
    for (final c in costs) {
      await txn.insert('item_costs', {
        'item_id': itemId,
        'category': c.category,
        'amount_fen': _yuanToFen(c.amount),
        'note': c.note,
        'created_at': now.toIso8601String(),
      });
    }
  }

  Map<String, Object?> _draftToRow(
    ItemDraft d, {
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => {
    'name': d.name,
    'price_fen': _yuanToFen(d.price),
    'residual_fen': _yuanToFen(d.residual),
    'category': d.category,
    'purchase_date': _dateToDb(d.purchaseDate),
    'currency': d.currency,
    'apr_percent': d.aprPercent,
    'installment_months': d.installmentMonths,
    'end_date': d.endDate == null ? null : _dateToDb(d.endDate!),
    'usage_days': d.usageDays,
    'total_uses': d.totalUses,
    'uses_per_day': d.usesPerDay,
    'total_hours': d.totalHours,
    'hours_per_day': d.hoursPerDay,
    'cycle_unit': d.cycleUnit?.name,
    'cycle_length': d.cycleLength,
    'calc_mode': d.calcMode.name,
    'depreciation': d.depreciation.name,
    'note': d.note,
    'photos': jsonEncode(d.photos),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': null,
  };

  Item _rowToItem(
    Map<String, Object?> r,
    List<String> tags,
    List<ItemCost> costs,
  ) => Item(
    id: r['id'] as int,
    name: r['name'] as String,
    price: _fenToYuan(r['price_fen'] as int),
    residual: _fenToYuan(r['residual_fen'] as int),
    category: r['category'] as String,
    purchaseDate: _dateFromDb(r['purchase_date'] as String),
    currency: r['currency'] as String? ?? 'CNY',
    aprPercent: (r['apr_percent'] as num?)?.toDouble(),
    installmentMonths: r['installment_months'] as int?,
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
    photos: (jsonDecode(r['photos'] as String? ?? '[]') as List<dynamic>)
        .cast<String>(),
    extraCosts: costs,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
    deletedAt: r['deleted_at'] == null ? null : DateTime.parse(r['deleted_at'] as String),
  );

  ItemCost _rowToCost(Map<String, Object?> r) => ItemCost(
    id: r['id'] as int,
    itemId: r['item_id'] as int,
    category: r['category'] as String,
    amount: _fenToYuan(r['amount_fen'] as int),
    note: r['note'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
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
}
