import 'package:daily_cost/features/calculator/application/calculator_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('价格 + 时长（天）→ 日均', () {
    final r = computeCalculator(
      priceText: '300',
      durationText: '30',
      durationUnit: '天',
      coffeePriceYuan: 15,
    );
    expect(r.dailyCost, closeTo(10.0, 0.001));
    expect(r.coffeePerDay, closeTo(10 / 15, 0.001));
    expect(r.coffeeTotal, closeTo(20, 0.001));
    expect(r.totalCost, closeTo(300, 0.001));
  });

  test('单位换算：周/月/年', () {
    double daily(String unit) => computeCalculator(
      priceText: '365',
      durationText: '1',
      durationUnit: unit,
      coffeePriceYuan: 15,
    ).dailyCost!;
    expect(daily('天'), closeTo(365, 0.001));
    expect(daily('周'), closeTo(365 / 7, 0.001));
    expect(daily('月'), closeTo(365 / 30, 0.001));
    expect(daily('年'), closeTo(1, 0.001));
  });

  test('非法输入 → 空结果', () {
    for (final (price, duration) in [
      ('', '30'),
      ('300', ''),
      ('abc', '30'),
      ('-5', '30'),
      ('300', '0'),
      ('300', '-1'),
    ]) {
      final r = computeCalculator(
        priceText: price,
        durationText: duration,
        durationUnit: '天',
        coffeePriceYuan: 15,
      );
      expect(r.dailyCost, isNull, reason: 'price=$price duration=$duration');
    }
  });

  test('咖啡单价为 0 时不除零（按 ¥1 兜底）', () {
    final r = computeCalculator(
      priceText: '100',
      durationText: '10',
      durationUnit: '天',
      coffeePriceYuan: 0,
    );
    expect(r.dailyCost, closeTo(10, 0.001));
    expect(r.coffeePerDay, closeTo(10, 0.001));
  });
}
