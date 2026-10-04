/// 预算引擎（纯函数）：执行情况、财务健康评分、购买力。
///
/// 口径：预算对比的是「日均总支出 × 周期天数」（在用物品的持续消耗），
/// 而非单次购买金额——与应用的核心指标一致。
library;

import '../../../domain/models/budget.dart';

/// 一条预算的执行情况。
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spent,
  });

  final Budget budget;

  /// 周期内折算支出 = 日均 × 周期天数
  final double spent;

  /// 预算额度
  double get limit => budget.amount;

  /// 使用率（可 > 1）
  double get ratio => limit <= 0 ? 0 : spent / limit;

  bool get over => spent > limit;
}

/// 计算各预算执行情况。
///
/// [dailyByCategory]：分类 → 该分类日均支出；[dailyTotal]：全部日均支出。
List<BudgetStatus> evaluateBudgets(
  List<Budget> budgets, {
  required double dailyTotal,
  required Map<String, double> dailyByCategory,
}) {
  return [
    for (final b in budgets)
      BudgetStatus(
        budget: b,
        spent: (b.category == null
                ? dailyTotal
                : (dailyByCategory[b.category] ?? 0)) *
            b.period.days,
      ),
  ];
}

/// 财务健康评分 0-100。
///
/// 透明口径：起评 100；每条超支预算按超出比例扣分（超 10% 扣 10 分以此类推，
/// 单条最多扣 40）；无预算时不奖不扣；全部有结余（使用率 ≤ 80%）加 5 分封顶 100。
double healthScore(List<BudgetStatus> statuses) {
  if (statuses.isEmpty) return 100;
  var score = 100.0;
  var allComfortable = true;
  for (final s in statuses) {
    if (s.over) {
      final excess = s.ratio - 1.0;
      score -= (excess * 100).clamp(0, 40);
    } else if (s.ratio > 0.8) {
      allComfortable = false;
    }
  }
  if (allComfortable && !statuses.any((s) => s.over)) score += 5;
  return score.clamp(0, 100);
}

/// 购买力分析。
class PurchasingPower {
  const PurchasingPower({
    required this.dailyPower,
    required this.monthlyPower,
    required this.yearlyPower,
    required this.affordableOneYearItem,
    required this.affordableThreeYearItem,
  });

  /// 每日可支配预算（元）
  final double dailyPower;

  /// 折算月度/年度消费力
  final double monthlyPower;
  final double yearlyPower;

  /// 按 1 年使用期可负担的单品价格（日预算 × 365）
  final double affordableOneYearItem;

  /// 按 3 年使用期可负担的单品价格
  final double affordableThreeYearItem;
}

/// 由日预算推算购买力。日预算取「每天」总预算；无则为 null。
PurchasingPower purchasingPower(double dailyBudget) {
  final d = dailyBudget > 0 ? dailyBudget : 0.0;
  return PurchasingPower(
    dailyPower: d,
    monthlyPower: d * 30,
    yearlyPower: d * 365,
    affordableOneYearItem: d * 365,
    affordableThreeYearItem: d * 365 * 3,
  );
}
