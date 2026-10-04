import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/calc/calc_engine.dart';
import '../../../domain/models/calc_result.dart';
import '../../../domain/models/daily_summary.dart';
import '../../../domain/models/item.dart';
import '../../settings/application/settings_providers.dart';

/// 有效（未软删除）记录列表 + CRUD。
///
/// sqflite 没有变更流，因此所有写操作经由本 Notifier 并重查生效，
/// 派生 Provider（calcResults/dailySummary）自动重建。
class ItemsNotifier extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() => _reload();

  Future<List<Item>> _reload() =>
      ref.read(itemRepositoryProvider).findAll();

  Future<void> addItem(ItemDraft draft) async {
    await ref.read(itemRepositoryProvider).insert(draft, draft.tags);
    state = AsyncData(await _reload());
  }

  Future<void> updateItem(Item item) async {
    await ref.read(itemRepositoryProvider).update(item, item.tags);
    state = AsyncData(await _reload());
  }

  Future<void> softDelete(int id) async {
    await ref.read(itemRepositoryProvider).softDelete(id);
    state = AsyncData(await _reload());
  }

  Future<void> restore(int id) async {
    await ref.read(itemRepositoryProvider).restore(id);
    state = AsyncData(await _reload());
  }
}

final itemsProvider =
    AsyncNotifierProvider<ItemsNotifier, List<Item>>(ItemsNotifier.new);

/// 每条记录的计算结果（按 id 索引，金额已折算人民币）。
final calcResultsProvider = Provider<Map<int, CalcResult>>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  return {
    for (final item in items)
      item.id: calculate(
        item.toCalcInputs(fxRate: rates[item.currency] ?? 1.0),
        today: today,
      ),
  };
});

/// 首页汇总（今日/昨日总额、环比、在用数）。
final dailySummaryProvider = Provider<DailySummary>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  return summarize(
    items.map((e) => e.toCalcInputs(fxRate: rates[e.currency] ?? 1.0)),
    today: today,
  );
});
