import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/calc/calc_engine.dart';
import '../../../domain/models/budget.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/item.dart';
import '../../budget/application/budget_engine.dart';
import '../../home/application/home_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../stats/application/stats_engine.dart';

/// 过去 N 天的每日日均总支出。
final trendProvider = Provider.family<List<TrendPoint>, int>((ref, days) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  final from = today.subtract(Duration(days: days - 1));
  return dailyTrend(
    [
      for (final it in items)
        it.toCalcInputs(fxRate: rates[it.currency] ?? 1.0),
    ],
    from: from,
    to: today,
  );
});

/// 分类日均份额（在用物品）。
final categorySharesProvider = Provider<List<CategoryShare>>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  return categoryShares({
    for (final it in items) it.category: it.toCalcInputs(fxRate: rates[it.currency] ?? 1.0),
  }, today: today);
});

/// 散点：摊薄天数 × 日均。
final scatterPointsProvider = Provider<List<ScatterPoint>>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  return scatterPoints({
    for (final it in items) it.name: it.toCalcInputs(fxRate: rates[it.currency] ?? 1.0),
  }, today: today);
});

/// TOP10 榜单。
final topListsProvider = Provider<TopLists>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);
  return topLists({
    for (final it in items) it.name: it.toCalcInputs(fxRate: rates[it.currency] ?? 1.0),
  }, today: today);
});

/// 订阅类记录（续费管理）。
final subscriptionItemsProvider = Provider<List<Item>>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  return [
    for (final it in items)
      if (it.calcMode == CalcMode.subscription) it,
  ];
});

/// 预算 CRUD 状态。
class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() =>
      ref.read(budgetRepositoryProvider).findAll();

  Future<void> save(BudgetDraft draft) async {
    await ref.read(budgetRepositoryProvider).upsert(draft);
    state = AsyncData(await ref.read(budgetRepositoryProvider).findAll());
  }

  Future<void> remove(int id) async {
    await ref.read(budgetRepositoryProvider).delete(id);
    state = AsyncData(await ref.read(budgetRepositoryProvider).findAll());
  }
}

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(BudgetsNotifier.new);

/// 预算执行情况。
final budgetStatusProvider = Provider<List<BudgetStatus>>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final today = ref.watch(todayProvider);
  final rates = ref.watch(fxRatesProvider);

  double dailyTotal = 0;
  final dailyByCategory = <String, double>{};
  for (final it in items) {
    final r = calculate(
      it.toCalcInputs(fxRate: rates[it.currency] ?? 1.0),
      today: today,
    );
    if (r.status == ItemStatus.inUse) {
      dailyTotal += r.dailyCost;
      dailyByCategory[it.category] =
          (dailyByCategory[it.category] ?? 0) + r.dailyCost;
    }
  }
  return evaluateBudgets(
    budgets,
    dailyTotal: dailyTotal,
    dailyByCategory: dailyByCategory,
  );
});

/// 财务健康评分。
final healthScoreProvider = Provider<double>(
  (ref) => healthScore(ref.watch(budgetStatusProvider)),
);

/// 购买力（取「每天」总预算；无预算时为 null）。
final purchasingPowerProvider = Provider<PurchasingPower?>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  for (final b in budgets) {
    if (b.period == BudgetPeriod.daily && b.category == null) {
      return purchasingPower(b.amount);
    }
  }
  return null;
});
