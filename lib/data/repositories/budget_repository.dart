import 'package:sqflite/sqflite.dart';

import '../../domain/models/budget.dart';
import '../db/app_database.dart';

/// budgets 仓储。金额库存分。
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  /// 新增或更新（period+category 唯一）。
  Future<void> upsert(BudgetDraft draft) async {
    await _db.db.insert('budgets', {
      'period': draft.period.name,
      'category': draft.category,
      'amount_fen': (draft.amount * 100).round(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(int id) async {
    await _db.db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> findAll() async {
    final rows = await _db.db.query('budgets', orderBy: 'period, category');
    return [
      for (final r in rows)
        Budget(
          id: r['id'] as int,
          period: BudgetPeriod.values.byName(r['period'] as String),
          category: r['category'] as String?,
          amount: (r['amount_fen'] as int) / 100.0,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }
}
