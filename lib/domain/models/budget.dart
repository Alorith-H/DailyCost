/// 预算：日/周/月/年周期 + 可选分类子预算。金额单位为元。
library;

/// 预算周期。
enum BudgetPeriod {
  daily('每天'),
  weekly('每周'),
  monthly('每月'),
  yearly('每年');

  const BudgetPeriod(this.labelZh);

  final String labelZh;

  /// 周期折算天数（与应用其他地方的口径一致：月=30、年=365）。
  double get days => switch (this) {
    BudgetPeriod.daily => 1,
    BudgetPeriod.weekly => 7,
    BudgetPeriod.monthly => 30,
    BudgetPeriod.yearly => 365,
  };
}

/// 一条预算。[category] 为 null 表示总预算。
class Budget {
  const Budget({
    required this.id,
    required this.period,
    required this.category,
    required this.amount,
    required this.createdAt,
  });

  final int id;
  final BudgetPeriod period;
  final String? category;
  final double amount;
  final DateTime createdAt;
}

/// 新建/更新预算草稿（period+category 唯一）。
class BudgetDraft {
  const BudgetDraft({
    required this.period,
    required this.category,
    required this.amount,
  });

  final BudgetPeriod period;
  final String? category;
  final double amount;
}
