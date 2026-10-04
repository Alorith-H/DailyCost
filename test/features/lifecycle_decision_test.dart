import 'package:daily_cost/features/decisions/application/decision_engine.dart';
import 'package:daily_cost/features/lifecycle/application/lifecycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lifecycle_engine', () {
    test('使用率与值不值评分', () {
      expect(usageRate(checkinDays: 15), closeTo(0.5, 0.001));
      expect(usageRate(checkinDays: 40), 1.0); // 超出窗口封顶
      expect(worthScore(checkinDays: 15), closeTo(50, 0.001));
    });

    test('后悔指数：贵且不用 → 高；常用 → 低', () {
      final regretful = regretIndex(
        dailyCost: 15,
        coffeePriceYuan: 15,
        checkinDays: 0,
      );
      final loved = regretIndex(
        dailyCost: 15,
        coffeePriceYuan: 15,
        checkinDays: 30,
      );
      expect(regretful, closeTo(100, 0.001));
      expect(loved, closeTo(0, 0.001));
    });

    test('闲置检测与冷静期', () {
      final today = DateTime(2026, 10, 15);
      expect(
        isLikelyIdle(lastCheckIn: null, today: today),
        isTrue,
      );
      expect(
        isLikelyIdle(
          lastCheckIn: DateTime(2026, 10, 1),
          today: today,
        ),
        isTrue,
      );
      expect(
        isLikelyIdle(
          lastCheckIn: DateTime(2026, 10, 10),
          today: today,
        ),
        isFalse,
      );

      expect(
        cooldownDaysLeft(
          cooldownUntil: DateTime(2026, 10, 18),
          today: today,
        ),
        3,
      );
      expect(
        cooldownDaysLeft(
          cooldownUntil: DateTime(2026, 10, 12),
          today: today,
        ),
        -3,
      );
      expect(cooldownDaysLeft(cooldownUntil: null, today: today), isNull);
    });
  });

  group('decision_engine', () {
    test('买 vs 租', () {
      final r = buyVsRent(
        buyPrice: 1200,
        residual: 200,
        rentPerMonth: 100,
        months: 12,
      );
      expect(r.buyTotal, closeTo(1000, 0.001));
      expect(r.rentTotal, closeTo(1200, 0.001));
      expect(r.buyCheaper, isTrue);
    });

    test('全款 vs 分期（等额本息一致）', () {
      final r = fullVsInstallment(price: 1200, aprPercent: 12, months: 12);
      expect(r.fullPrice, closeTo(1200, 0.001));
      expect(r.monthlyPayment, closeTo(106.6185, 0.01));
      expect(r.totalPaid, closeTo(r.monthlyPayment * 12, 0.01));
      expect(r.interestCost, greaterThan(0));
    });

    test('新品 vs 二手', () {
      final r = newVsUsed(
        newPrice: 1000,
        usedPrice: 600,
        newDays: 365,
        usedDays: 365,
      );
      expect(r.usedCheaper, isTrue);
      expect(r.dailyUsed, closeTo(600 / 365, 0.001));
    });

    test('年限敏感性：日均随年限递减', () {
      final points = sensitivity(effectiveCost: 3650);
      expect(points.first.days, 30);
      expect(points.first.daily, closeTo(3650 / 30, 0.001));
      expect(points.last.days, 1825);
      for (var i = 1; i < points.length; i++) {
        expect(points[i].daily, lessThan(points[i - 1].daily));
      }
    });
  });
}
