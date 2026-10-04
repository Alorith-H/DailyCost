/// 购物决策引擎（纯函数）：买vs租、全款vs分期、新品vs二手、年限敏感性。
library;

import '../../../domain/calc/calc_engine.dart';

/// 买 vs 租。
class BuyVsRent {
  const BuyVsRent({
    required this.buyTotal,
    required this.rentTotal,
    required this.buyCheaper,
  });

  /// 买断净支出 = 价格 - 残值（用完还能卖）
  final double buyTotal;

  /// 租金合计 = 月租 × 月数
  final double rentTotal;

  final bool buyCheaper;
}

BuyVsRent buyVsRent({
  required double buyPrice,
  required double residual,
  required double rentPerMonth,
  required int months,
}) {
  final buy = (buyPrice - residual).clamp(0.0, double.infinity);
  final rent = rentPerMonth.clamp(0.0, double.infinity) * (months < 1 ? 1 : months);
  return BuyVsRent(buyTotal: buy, rentTotal: rent, buyCheaper: buy <= rent);
}

/// 全款 vs 分期。
class FullVsInstallment {
  const FullVsInstallment({
    required this.fullPrice,
    required this.totalPaid,
    required this.monthlyPayment,
    required this.interestCost,
  });

  final double fullPrice;
  final double totalPaid;
  final double monthlyPayment;
  final double interestCost;
}

FullVsInstallment fullVsInstallment({
  required double price,
  required double aprPercent,
  required int months,
}) {
  final plan = installmentPlan(
    principal: price,
    aprPercent: aprPercent,
    months: months,
  );
  return FullVsInstallment(
    fullPrice: price,
    totalPaid: plan.totalPaid,
    monthlyPayment: plan.monthlyPayment,
    interestCost: plan.totalInterest,
  );
}

/// 新品 vs 二手（各自按使用天数摊薄）。
class NewVsUsed {
  const NewVsUsed({
    required this.dailyNew,
    required this.dailyUsed,
    required this.usedCheaper,
  });

  final double dailyNew;
  final double dailyUsed;
  final bool usedCheaper;
}

NewVsUsed newVsUsed({
  required double newPrice,
  required double usedPrice,
  required double newDays,
  required double usedDays,
}) {
  double daily(double price, double days) =>
      price / (days <= 0 ? 1 : days);
  final dn = daily(newPrice, newDays);
  final du = daily(usedPrice, usedDays);
  return NewVsUsed(dailyNew: dn, dailyUsed: du, usedCheaper: du <= dn);
}

/// 年限敏感性：不同使用天数下的日均。
class SensitivityPoint {
  const SensitivityPoint({required this.days, required this.daily});

  final int days;
  final double daily;
}

List<SensitivityPoint> sensitivity({
  required double effectiveCost,
  List<int> dayOptions = const [30, 90, 180, 365, 730, 1095, 1825],
}) {
  return [
    for (final d in dayOptions)
      SensitivityPoint(days: d, daily: effectiveCost / (d <= 0 ? 1 : d)),
  ];
}
