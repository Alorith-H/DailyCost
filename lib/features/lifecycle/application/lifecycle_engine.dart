/// 生命周期引擎（纯函数）：冷静期计算。
///
/// 原打卡相关口径（使用率/值不值评分/后悔指数/疑似闲置）已随打卡功能移除。
library;

/// 冷静期剩余天数（负数表示已结束）；无冷静期返回 null。
int? cooldownDaysLeft({required DateTime? cooldownUntil, required DateTime today}) {
  if (cooldownUntil == null) return null;
  final until = DateTime(cooldownUntil.year, cooldownUntil.month, cooldownUntil.day);
  final now = DateTime(today.year, today.month, today.day);
  return until.difference(now).inDays;
}
