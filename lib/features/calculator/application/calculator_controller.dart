/// 试算器纯计算逻辑（可单测，不依赖 Flutter）。
library;

import '../../../core/constants.dart';

/// 试算结果。
class CalculatorResult {
  const CalculatorResult({
    required this.dailyCost,
    required this.coffeePerDay,
    required this.coffeeTotal,
    required this.totalCost,
  });

  static const empty = CalculatorResult(
    dailyCost: null,
    coffeePerDay: null,
    coffeeTotal: null,
    totalCost: null,
  );

  /// 日均（元/天）；输入不完整时为 null
  final double? dailyCost;

  /// 每天 ≈ 几杯咖啡
  final double? coffeePerDay;

  /// 整笔钱 ≈ 几杯咖啡
  final double? coffeeTotal;

  /// 总价（元）
  final double? totalCost;
}

/// 由价格与时长即时计算日均 + 咖啡对比。
///
/// [durationUnit] 取 kDurationUnitDays 的键（天/周/月/年）。
/// 价格与时长解析失败或 <= 0 时返回 [CalculatorResult.empty]。
CalculatorResult computeCalculator({
  required String priceText,
  required String durationText,
  required String durationUnit,
  required double coffeePriceYuan,
}) {
  final price = double.tryParse(priceText.trim());
  final duration = double.tryParse(durationText.trim());
  final unitDays = kDurationUnitDays[durationUnit] ?? 1;

  if (price == null || price <= 0 || duration == null || duration <= 0) {
    return CalculatorResult.empty;
  }

  final totalDays = duration * unitDays;
  final daily = price / totalDays;
  final safeCoffee = coffeePriceYuan > 0 ? coffeePriceYuan : 1.0;

  return CalculatorResult(
    dailyCost: daily,
    coffeePerDay: daily / safeCoffee,
    coffeeTotal: price / safeCoffee,
    totalCost: price,
  );
}
