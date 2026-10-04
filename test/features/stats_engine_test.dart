import 'package:daily_cost/domain/models/budget.dart';
import 'package:daily_cost/domain/models/calc_inputs.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/features/budget/application/budget_engine.dart';
import 'package:daily_cost/features/stats/application/stats_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final purchase = DateTime(2026, 10, 1);
  CalcInputs fixed({
    double price = 300,
    double residual = 30,
    int days = 30,
  }) => CalcInputs(
    price: price,
    residual: residual,
    mode: CalcMode.fixedDays,
    depreciation: DepreciationMethod.straightLine,
    purchaseDate: purchase,
    usageDays: days,
  );

  group('stats_engine', () {
    test('dailyTrend：序列长度与逐日总额', () {
      final trend = dailyTrend(
        [fixed(price: 300, residual: 30, days: 30)],
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 5),
      );
      expect(trend, hasLength(5));
      // 10-01 起在用，每天 9 元
      for (final p in trend) {
        expect(p.total, closeTo(9, 0.001));
      }
    });

    test('categoryShares：只计在用并按金额降序', () {
      final shares = categoryShares({
        '数码': fixed(price: 300, residual: 30, days: 30),
        '餐饮': fixed(price: 60, residual: 0, days: 30),
        '未来': CalcInputs(
          price: 999,
          residual: 0,
          mode: CalcMode.fixedDays,
          depreciation: DepreciationMethod.straightLine,
          purchaseDate: DateTime(2027, 1, 1),
          usageDays: 10,
        ),
      }, today: DateTime(2026, 10, 15));
      expect(shares, hasLength(2));
      expect(shares.first.category, '数码');
      expect(shares.first.total, closeTo(9, 0.001));
    });

    test('topLists：三个榜单口径', () {
      final tops = topLists({
        '贵家伙': fixed(price: 900, residual: 0, days: 30),
        '便宜货': fixed(price: 30, residual: 0, days: 30),
        '短命鬼': fixed(price: 300, residual: 0, days: 3),
      }, today: DateTime(2026, 10, 15));
      expect(tops.mostExpensive.first.name, '贵家伙');
      expect(tops.bestValue.first.name, '便宜货');
      expect(tops.mostWasteful.first.name, '短命鬼');
    });

    test('scatterPoints：x=总天数 y=日均', () {
      final points = scatterPoints({
        'A': fixed(price: 300, residual: 30, days: 30),
      }, today: DateTime(2026, 10, 15));
      expect(points.single.x, closeTo(30, 0.001));
      expect(points.single.y, closeTo(9, 0.001));
    });
  });

  group('budget_engine', () {
    Budget b(BudgetPeriod p, double amount, {String? category}) => Budget(
      id: 1,
      period: p,
      category: category,
      amount: amount,
      createdAt: DateTime(2026),
    );

    test('evaluateBudgets：周期折算', () {
      final statuses = evaluateBudgets(
        [
          b(BudgetPeriod.monthly, 300),
          b(BudgetPeriod.daily, 10, category: '数码'),
        ],
        dailyTotal: 9,
        dailyByCategory: {'数码': 9},
      );
      // 月预算：9×30 = 270 / 300 = 0.9
      expect(statuses[0].spent, closeTo(270, 0.001));
      expect(statuses[0].ratio, closeTo(0.9, 0.001));
      expect(statuses[0].over, isFalse);
      // 分类日预算：9×1 = 9 / 10
      expect(statuses[1].ratio, closeTo(0.9, 0.001));
    });

    test('healthScore：超支扣分、余量加分', () {
      expect(healthScore([]), 100);
      final comfortable = [
        BudgetStatus(budget: b(BudgetPeriod.monthly, 1000), spent: 500),
      ];
      expect(healthScore(comfortable), 100); // 100 + 5 封顶

      final over = [
        BudgetStatus(budget: b(BudgetPeriod.monthly, 100), spent: 150),
      ];
      // 超 50% → 扣 50 封顶 40 → 60
      expect(healthScore(over), closeTo(60, 0.001));
    });

    test('purchasingPower', () {
      final p = purchasingPower(30);
      expect(p.monthlyPower, closeTo(900, 0.001));
      expect(p.yearlyPower, closeTo(10950, 0.001));
      expect(p.affordableOneYearItem, closeTo(10950, 0.001));
      expect(p.affordableThreeYearItem, closeTo(32850, 0.001));
    });
  });
}
