/// 生命周期引擎（纯函数）：使用率、值不值评分、后悔指数、闲置检测。
///
/// 公开口径：
/// - 使用率 = 近 [windowDays] 天打卡天数 / 窗口天数
/// - 值不值评分 = 使用率 × 100（用得越多越值）
/// - 后悔指数 = clamp01(日均 / 咖啡单价) × (1 - 使用率) × 100
///   （花得比咖啡贵还不怎么用 → 后悔拉满）
/// - 疑似闲置 = 连续 [idleDays] 天（默认 14）无打卡
library;

/// 使用率 0..1。
double usageRate({required int checkinDays, int windowDays = 30}) {
  if (windowDays <= 0) return 0;
  return (checkinDays / windowDays).clamp(0.0, 1.0);
}

/// 值不值评分 0..100。
double worthScore({required int checkinDays, int windowDays = 30}) =>
    usageRate(checkinDays: checkinDays, windowDays: windowDays) * 100;

/// 后悔指数 0..100。
double regretIndex({
  required double dailyCost,
  required double coffeePriceYuan,
  required int checkinDays,
  int windowDays = 30,
}) {
  final coffee = coffeePriceYuan > 0 ? coffeePriceYuan : 1.0;
  final costFactor = (dailyCost / coffee).clamp(0.0, 1.0);
  final rate = usageRate(checkinDays: checkinDays, windowDays: windowDays);
  return costFactor * (1 - rate) * 100;
}

/// 是否疑似闲置。
bool isLikelyIdle({
  required DateTime? lastCheckIn,
  required DateTime today,
  int idleDays = 14,
}) {
  if (lastCheckIn == null) return true;
  return today.difference(lastCheckIn).inDays >= idleDays;
}

/// 冷静期剩余天数（负数表示已结束）；无冷静期返回 null。
int? cooldownDaysLeft({required DateTime? cooldownUntil, required DateTime today}) {
  if (cooldownUntil == null) return null;
  final until = DateTime(cooldownUntil.year, cooldownUntil.month, cooldownUntil.day);
  final now = DateTime(today.year, today.month, today.day);
  return until.difference(now).inDays;
}
