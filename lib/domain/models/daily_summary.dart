/// 首页汇总：今日日均总支出及环比。
class DailySummary {
  const DailySummary({
    required this.todayTotal,
    required this.yesterdayTotal,
    required this.delta,
    required this.deltaPercent,
    required this.activeCount,
  });

  static const empty = DailySummary(
    todayTotal: 0,
    yesterdayTotal: 0,
    delta: 0,
    deltaPercent: null,
    activeCount: 0,
  );

  /// 今日日均总支出（元/天）= 在用物品日均之和
  final double todayTotal;

  /// 昨日口径的总额（元/天）
  final double yesterdayTotal;

  /// 环比差额 = todayTotal - yesterdayTotal
  final double delta;

  /// 环比百分比（如 0.043 表示 +4.3%）；昨日为 0 时为 null
  final double? deltaPercent;

  /// 在用物品数
  final int activeCount;
}
