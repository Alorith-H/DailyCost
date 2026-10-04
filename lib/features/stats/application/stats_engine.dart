/// 统计引擎（纯函数）：趋势、分类份额、散点、TOP10 榜单。
///
/// 榜单口径（公开约定）：
/// - 最贵：总成本（TCO+利息）降序
/// - 最超值：在用物品日均升序
/// - 最浪费：摊薄率（(总成本-残值)/已用天数）降序——用得少而摊得多
library;

import '../../../domain/calc/calc_engine.dart';
import '../../../domain/models/calc_inputs.dart';
import '../../../domain/models/calc_result.dart';
import '../../../domain/models/enums.dart';

/// 某一天的总额点。
class TrendPoint {
  const TrendPoint({required this.date, required this.total});

  final DateTime date;
  final double total;
}

/// 过去 [from..to]（含两端）每日「日均总支出」序列。
List<TrendPoint> dailyTrend(
  Iterable<CalcInputs> items, {
  required DateTime from,
  required DateTime to,
}) {
  final result = <TrendPoint>[];
  var day = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  while (!day.isAfter(end)) {
    result.add(TrendPoint(
      date: day,
      total: totalDailyCost(items, today: day),
    ));
    day = day.add(const Duration(days: 1));
  }
  return result;
}

/// 分类日均份额（仅计在用物品）。
class CategoryShare {
  const CategoryShare({required this.category, required this.total});

  final String category;
  final double total;
}

List<CategoryShare> categoryShares(
  Map<String, CalcInputs> itemsByCategory, {
  DateTime? today,
}) {
  final totals = <String, double>{};
  itemsByCategory.forEach((category, input) {
    final r = calculate(input, today: today);
    if (r.status == ItemStatus.inUse) {
      totals[category] = (totals[category] ?? 0) + r.dailyCost;
    }
  });
  final shares = [
    for (final e in totals.entries)
      CategoryShare(category: e.key, total: e.value),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return shares;
}

/// 散点点位：x = 摊薄总天数（开放式取已用天数），y = 日均。
class ScatterPoint {
  const ScatterPoint({required this.x, required this.y, required this.name});

  final double x;
  final double y;
  final String name;
}

List<ScatterPoint> scatterPoints(
  Map<String, CalcInputs> itemsByName, {
  DateTime? today,
}) {
  return [
    for (final e in itemsByName.entries)
      () {
        final r = calculate(e.value, today: today);
        return ScatterPoint(
          x: r.totalDays ?? r.elapsedDays.clamp(1, double.infinity),
          y: r.dailyCost,
          name: e.key,
        );
      }(),
  ];
}

/// 榜单条目。
class TopEntry {
  const TopEntry({required this.name, required this.value, required this.detail});

  final String name;
  final double value;
  final String detail;
}

/// 三个榜单（每榜最多 10 条）。
class TopLists {
  const TopLists({
    required this.mostExpensive,
    required this.bestValue,
    required this.mostWasteful,
  });

  final List<TopEntry> mostExpensive;
  final List<TopEntry> bestValue;
  final List<TopEntry> mostWasteful;
}

TopLists topLists(
  Map<String, CalcInputs> itemsByName, {
  DateTime? today,
}) {
  final entries = <({String name, CalcResult result})>[];
  itemsByName.forEach((name, input) {
    entries.add((name: name, result: calculate(input, today: today)));
  });

  final expensive = [...entries]
    ..sort((a, b) => b.result.totalCost.compareTo(a.result.totalCost));
  final bestValue = [
    for (final e in entries)
      if (e.result.status == ItemStatus.inUse) e,
  ]..sort((a, b) => a.result.dailyCost.compareTo(b.result.dailyCost));
  final wasteful = [
    for (final e in entries)
      if (e.result.elapsedDays >= 1) e,
  ]..sort((a, b) {
    final ra = (a.result.totalCost) / a.result.elapsedDays;
    final rb = (b.result.totalCost) / b.result.elapsedDays;
    return rb.compareTo(ra);
  });

  return TopLists(
    mostExpensive: [
      for (final e in expensive.take(10))
        TopEntry(
          name: e.name,
          value: e.result.totalCost,
          detail: '日均 ${e.result.dailyCost.toStringAsFixed(2)}',
        ),
    ],
    bestValue: [
      for (final e in bestValue.take(10))
        TopEntry(
          name: e.name,
          value: e.result.dailyCost,
          detail: '总成本 ${e.result.totalCost.toStringAsFixed(0)}',
        ),
    ],
    mostWasteful: [
      for (final e in wasteful.take(10))
        TopEntry(
          name: e.name,
          value: e.result.totalCost / e.result.elapsedDays,
          detail: '已用 ${e.result.elapsedDays.toInt()} 天',
        ),
    ],
  );
}
