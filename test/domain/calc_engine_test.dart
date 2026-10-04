import 'dart:math' as math;

import 'package:daily_cost/domain/calc/calc_engine.dart';
import 'package:daily_cost/domain/models/calc_inputs.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final purchase = DateTime(2026, 10, 1);
  CalcInputs input({
    double price = 300,
    double residual = 30,
    double tcoExtra = 0,
    double? aprPercent,
    int? installmentMonths,
    CalcMode mode = CalcMode.fixedDays,
    DepreciationMethod depreciation = DepreciationMethod.straightLine,
    DateTime? purchaseDate,
    DateTime? endDate,
    int? usageDays = 30,
    int? totalUses,
    double? usesPerDay,
    int? totalHours,
    double? hoursPerDay,
    CycleUnit? cycleUnit,
    int? cycleLength,
  }) => CalcInputs(
    price: price,
    residual: residual,
    tcoExtra: tcoExtra,
    aprPercent: aprPercent,
    installmentMonths: installmentMonths,
    mode: mode,
    depreciation: depreciation,
    purchaseDate: purchaseDate ?? purchase,
    endDate: endDate,
    usageDays: usageDays,
    totalUses: totalUses,
    usesPerDay: usesPerDay,
    totalHours: totalHours,
    hoursPerDay: hoursPerDay,
    cycleUnit: cycleUnit,
    cycleLength: cycleLength,
  );

  group('cycleDaysFor', () {
    test('单位天数 × 周期数', () {
      expect(cycleDaysFor(CycleUnit.weekly, 2), 14);
      expect(cycleDaysFor(CycleUnit.monthly, 1), 30);
      expect(cycleDaysFor(CycleUnit.yearly, 1), 365);
    });
    test('周期数 <= 0 钳为 1', () {
      expect(cycleDaysFor(CycleUnit.monthly, 0), 30);
      expect(cycleDaysFor(CycleUnit.monthly, -3), 30);
    });
  });

  group('固定天数模式', () {
    test('日均 = (P-R)/N', () {
      final r = calculate(
        input(price: 300, residual: 30, usageDays: 30),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(9.0, 0.001));
      expect(r.totalDays, 30);
    });

    test('天数为 0 钳为 1，validateInputs 报错', () {
      final r = calculate(input(usageDays: 0), today: DateTime(2026, 10, 15));
      expect(r.totalDays, 1);
      expect(r.dailyCost, closeTo(270.0, 0.001));
      final issues = validateInputs(input(usageDays: 0));
      expect(issues.map((e) => e.field), contains(CalcIssueField.usageDays));
    });

    test('浮点卫生：99.99 / 7', () {
      final r = calculate(
        input(price: 99.99, residual: 0, usageDays: 7),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(99.99 / 7, 0.0001));
    });
  });

  group('到期日模式', () {
    test('N = 到期日-购买日+1（含首尾）', () {
      final r = calculate(
        input(
          mode: CalcMode.endDate,
          usageDays: null,
          endDate: DateTime(2026, 10, 31),
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.totalDays, 31);
      expect(r.dailyCost, closeTo(270 / 31, 0.001));
    });

    test('到期日=购买日 → N=1', () {
      final r = calculate(
        input(mode: CalcMode.endDate, usageDays: null, endDate: purchase),
        today: purchase,
      );
      expect(r.totalDays, 1);
      expect(r.dailyCost, closeTo(270.0, 0.001));
    });

    test('到期日早于购买日 → N=1，validate 报错', () {
      final r = calculate(
        input(
          mode: CalcMode.endDate,
          usageDays: null,
          endDate: DateTime(2026, 9, 30),
        ),
        today: purchase,
      );
      expect(r.totalDays, 1);
      final issues = validateInputs(
        input(mode: CalcMode.endDate, usageDays: null, endDate: DateTime(2026, 9, 30)),
      );
      expect(
        issues.map((e) => e.messageZh),
        contains('到期日须晚于购买日'),
      );
    });
  });

  group('订阅周期模式', () {
    test('日均 = 价格/周期天数，忽略残值', () {
      final withResidual = calculate(
        input(
          price: 300,
          residual: 100,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.monthly,
          cycleLength: 1,
        ),
        today: DateTime(2026, 10, 15),
      );
      final noResidual = calculate(
        input(
          price: 300,
          residual: 0,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.monthly,
          cycleLength: 1,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(withResidual.dailyCost, closeTo(300 / 30, 0.001));
      expect(withResidual.dailyCost, noResidual.dailyCost);
    });

    test('周期数 > 1：每 2 周 = 14 天', () {
      final r = calculate(
        input(
          price: 140,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.weekly,
          cycleLength: 2,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(10.0, 0.001));
      expect(r.totalDays, 14);
    });

    test('本周期进度与周期内余额', () {
      // 购买 10-01，7 天周期，今天 10-03 → 本周期第 3/7 天
      final r = calculate(
        input(
          price: 70,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.weekly,
          cycleLength: 1,
        ),
        today: DateTime(2026, 10, 3),
      );
      expect(r.elapsedDays, 3);
      expect(r.progress, closeTo(3 / 7, 0.001));
      expect(r.remainingValue, closeTo(70 * (1 - 3 / 7), 0.001));
    });

    test('永不过期', () {
      final r = calculate(
        input(
          price: 30,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.monthly,
          cycleLength: 1,
        ),
        today: DateTime(2030, 1, 1),
      );
      expect(r.status, ItemStatus.inUse);
    });
  });

  group('实际天数模式', () {
    test('含购买日：当天 1 天、次日 2 天', () {
      final day0 = calculate(
        input(price: 270, residual: 0, mode: CalcMode.actualDays, usageDays: null),
        today: purchase,
      );
      expect(day0.dailyCost, closeTo(270.0, 0.001));
      expect(day0.totalDays, isNull);

      final day1 = calculate(
        input(price: 270, residual: 0, mode: CalcMode.actualDays, usageDays: null),
        today: DateTime(2026, 10, 2),
      );
      expect(day1.dailyCost, closeTo(135.0, 0.001));
    });

    test('开放式：progress/remainingValue 为 null，永不过期', () {
      final r = calculate(
        input(mode: CalcMode.actualDays, usageDays: null),
        today: DateTime(2030, 1, 1),
      );
      expect(r.progress, isNull);
      expect(r.remainingValue, isNull);
      expect(r.status, ItemStatus.inUse);
    });
  });

  group('按次模式', () {
    test('costPerUse 与 daily', () {
      final r = calculate(
        input(
          price: 100,
          residual: 0,
          mode: CalcMode.perUse,
          usageDays: null,
          totalUses: 10,
          usesPerDay: 2,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.costPerUse, closeTo(10.0, 0.001));
      expect(r.dailyCost, closeTo(20.0, 0.001));
      expect(r.totalDays, closeTo(5.0, 0.001));
    });

    test('总次数为 0 钳为 1；每日次数为 0 → 日均 0、开放式、validate 报错', () {
      final r = calculate(
        input(
          price: 100,
          residual: 0,
          mode: CalcMode.perUse,
          usageDays: null,
          totalUses: 0,
          usesPerDay: 0,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.costPerUse, closeTo(100.0, 0.001));
      expect(r.dailyCost, 0);
      expect(r.totalDays, isNull);
      final issues = validateInputs(
        input(
          mode: CalcMode.perUse,
          usageDays: null,
          totalUses: 0,
          usesPerDay: 0,
        ),
      );
      expect(issues.map((e) => e.field), contains(CalcIssueField.totalUses));
      expect(issues.map((e) => e.field), contains(CalcIssueField.usesPerDay));
    });
  });

  group('按小时模式', () {
    test('costPerHour 与 daily', () {
      final r = calculate(
        input(
          price: 240,
          residual: 40,
          mode: CalcMode.perHour,
          usageDays: null,
          totalHours: 20,
          hoursPerDay: 2,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.costPerHour, closeTo(10.0, 0.001));
      expect(r.dailyCost, closeTo(20.0, 0.001));
      expect(r.totalDays, closeTo(10.0, 0.001));
    });
  });

  group('remainingValueAt', () {
    test('直线折旧：t=0→P、t=N→R、中点', () {
      double v(double t) => remainingValueAt(
        price: 300,
        residual: 30,
        method: DepreciationMethod.straightLine,
        totalDays: 30,
        elapsedDays: t,
      );
      expect(v(0), closeTo(300, 0.001));
      expect(v(30), closeTo(30, 0.001));
      expect(v(15), closeTo(300 - 270 / 2, 0.001));
    });

    test('余额递减：t=0→P、t=N→R、中点= P×√(R/P)', () {
      double v(double t) => remainingValueAt(
        price: 300,
        residual: 30,
        method: DepreciationMethod.decliningBalance,
        totalDays: 30,
        elapsedDays: t,
      );
      expect(v(0), closeTo(300, 0.001));
      expect(v(30), closeTo(30, 0.01));
      expect(v(15), closeTo(300 * 0.316227766, 0.01)); // √0.1≈0.3162
    });

    test('余额递减且 R<=0 回退直线', () {
      final v = remainingValueAt(
        price: 300,
        residual: 0,
        method: DepreciationMethod.decliningBalance,
        totalDays: 30,
        elapsedDays: 15,
      );
      expect(v, closeTo(150, 0.001));
    });

    test('t 钳制在 [0,N]', () {
      expect(
        remainingValueAt(
          price: 300,
          residual: 30,
          method: DepreciationMethod.straightLine,
          totalDays: 30,
          elapsedDays: -5,
        ),
        closeTo(300, 0.001),
      );
      expect(
        remainingValueAt(
          price: 300,
          residual: 30,
          method: DepreciationMethod.straightLine,
          totalDays: 30,
          elapsedDays: 999,
        ),
        closeTo(30, 0.001),
      );
    });
  });

  group('规范化与状态', () {
    test('残值<0 钳为 0', () {
      final r = calculate(
        input(price: 100, residual: -5, usageDays: 10),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(10.0, 0.001));
    });

    test('残值>价格 → 日均 0 + validate 警告', () {
      final r = calculate(
        input(price: 100, residual: 150, usageDays: 10),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, 0);
      final issues = validateInputs(input(price: 100, residual: 150, usageDays: 10));
      final warn = issues.firstWhere((e) => e.field == CalcIssueField.residual);
      expect(warn.severity, CalcIssueSeverity.warning);
    });

    test('残值=价格 → 日均 0，进度照走，剩余价值=价格', () {
      final r = calculate(
        input(price: 100, residual: 100, usageDays: 10),
        today: DateTime(2026, 10, 6), // 已用 6/10 天
      );
      expect(r.dailyCost, 0);
      expect(r.progress, closeTo(0.6, 0.001));
      expect(r.remainingValue, closeTo(100, 0.001));
    });

    test('未来购买日 → notStarted、elapsed=0，不计入总额', () {
      final future = input(
        purchaseDate: DateTime(2026, 10, 20),
        price: 100,
        residual: 0,
        usageDays: 10,
      );
      final r = calculate(future, today: DateTime(2026, 10, 15));
      expect(r.status, ItemStatus.notStarted);
      expect(r.elapsedDays, 0);
      expect(r.progress, 0);
      final s = summarize([future], today: DateTime(2026, 10, 15));
      expect(s.todayTotal, 0);
      expect(s.activeCount, 0);
    });

    test('状态流转：末日当天在用，次日已到期', () {
      // 购买 10-01，N=3 → 10-01..10-03 在用；10-04 已到期
      final it = input(price: 30, residual: 0, usageDays: 3);
      expect(calculate(it, today: DateTime(2026, 10, 3)).status, ItemStatus.inUse);
      expect(calculate(it, today: DateTime(2026, 10, 4)).status, ItemStatus.expired);
    });

    test('折旧方式只影响剩余价值，不影响日均（六模式矩阵）', () {
      for (final mode in CalcMode.values) {
        CalcInputs make(DepreciationMethod m) => input(
          price: 300,
          residual: 30,
          mode: mode,
          depreciation: m,
          usageDays: mode == CalcMode.fixedDays ? 30 : null,
          endDate: mode == CalcMode.endDate ? DateTime(2026, 10, 31) : null,
          cycleUnit: mode == CalcMode.subscription ? CycleUnit.monthly : null,
          cycleLength: mode == CalcMode.subscription ? 1 : null,
          totalUses: mode == CalcMode.perUse ? 10 : null,
          usesPerDay: mode == CalcMode.perUse ? 2 : null,
          totalHours: mode == CalcMode.perHour ? 20 : null,
          hoursPerDay: mode == CalcMode.perHour ? 2 : null,
        );
        final straight = calculate(
          make(DepreciationMethod.straightLine),
          today: DateTime(2026, 10, 15),
        );
        final declining = calculate(
          make(DepreciationMethod.decliningBalance),
          today: DateTime(2026, 10, 15),
        );
        expect(straight.dailyCost, declining.dailyCost, reason: 'mode=$mode');
      }
    });
  });

  group('summarize 环比', () {
    test('今日开始的记录只进今日总额', () {
      final it = input(
        purchaseDate: DateTime(2026, 10, 15),
        price: 300,
        residual: 30,
        usageDays: 30,
      );
      final s = summarize([it], today: DateTime(2026, 10, 15));
      expect(s.todayTotal, closeTo(9, 0.001));
      expect(s.yesterdayTotal, 0);
      expect(s.delta, closeTo(9, 0.001));
      expect(s.deltaPercent, isNull);
      expect(s.activeCount, 1);
    });

    test('昨日是末日的记录只进昨日总额', () {
      // 购买 10-01，N=3 → 末日 10-03；今天 10-04 已到期
      final it = input(price: 30, residual: 0, usageDays: 3);
      final s = summarize([it], today: DateTime(2026, 10, 4));
      expect(s.todayTotal, 0);
      expect(s.yesterdayTotal, closeTo(10, 0.001));
      expect(s.delta, closeTo(-10, 0.001));
      expect(s.deltaPercent, closeTo(-1.0, 0.001));
      expect(s.activeCount, 0);
    });

    test('actualDays 随天数变化产生环比', () {
      // 购买 10-01，P-R=270：昨天(10-14)=270/14，今天(10-15)=270/15
      final it = input(
        price: 270,
        residual: 0,
        mode: CalcMode.actualDays,
        usageDays: null,
      );
      final s = summarize([it], today: DateTime(2026, 10, 15));
      expect(s.todayTotal, closeTo(270 / 15, 0.001));
      expect(s.yesterdayTotal, closeTo(270 / 14, 0.001));
      expect(s.delta, closeTo(270 / 15 - 270 / 14, 0.001));
      expect(s.deltaPercent, isNotNull);
    });

    test('totalDailyCost 与 summarize.todayTotal 一致', () {
      final items = [
        input(price: 300, residual: 30, usageDays: 30),
        input(price: 70, residual: 0, mode: CalcMode.subscription, usageDays: null,
            cycleUnit: CycleUnit.weekly, cycleLength: 1),
      ];
      final today = DateTime(2026, 10, 15);
      expect(
        totalDailyCost(items, today: today),
        closeTo(summarize(items, today: today).todayTotal, 0.0001),
      );
    });
  });

  group('分期与 TCO', () {
    test('等额本息：零利率均摊', () {
      final plan = installmentPlan(principal: 1200, aprPercent: 0, months: 12);
      expect(plan.monthlyPayment, closeTo(100, 0.001));
      expect(plan.totalInterest, closeTo(0, 0.001));
      expect(plan.totalPaid, closeTo(1200, 0.001));
    });

    test('等额本息：12%/12 期公式对照', () {
      // monthly = P×r×(1+r)^n/((1+r)^n-1)，r=0.01、n=12
      final plan = installmentPlan(principal: 12000, aprPercent: 12, months: 12);
      final r = 0.01;
      final pow = math.pow(1 + r, 12).toDouble();
      final expectedMonthly = 12000 * r * pow / (pow - 1);
      expect(plan.monthlyPayment, closeTo(expectedMonthly, 0.001));
      expect(plan.totalPaid, closeTo(expectedMonthly * 12, 0.001));
      expect(plan.totalInterest, closeTo(expectedMonthly * 12 - 12000, 0.001));
      expect(plan.monthlyPayment, closeTo(1066.185, 0.01));
    });

    test('期数 <= 0 钳为 1；负利率按 0 处理', () {
      final plan = installmentPlan(principal: 600, aprPercent: -5, months: 0);
      expect(plan.monthlyPayment, closeTo(600, 0.001));
      expect(plan.totalPaid, closeTo(600, 0.001));
    });

    test('分期改变日均基数为总还款额', () {
      // 1200 全款分 12 期零利率 → 总额仍 1200，残值 0，120 天 → 日均 10
      final zeroApr = calculate(
        input(
          price: 1200,
          residual: 0,
          usageDays: 120,
          installmentMonths: 12,
          aprPercent: 0,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(zeroApr.dailyCost, closeTo(10, 0.001));
      expect(zeroApr.monthlyPayment, closeTo(100, 0.001));
      expect(zeroApr.totalInterest, closeTo(0, 0.001));

      // 带利息：总额 ≈ 1392.73 → 日均 ≈ 11.6
      final withInterest = calculate(
        input(
          price: 1200,
          residual: 0,
          usageDays: 120,
          installmentMonths: 12,
          aprPercent: 12,
        ),
        today: DateTime(2026, 10, 15),
      );
      final plan = installmentPlan(principal: 1200, aprPercent: 12, months: 12);
      expect(withInterest.totalCost, closeTo(plan.totalPaid, 0.001));
      expect(withInterest.dailyCost, closeTo(plan.totalPaid / 120, 0.001));
    });

    test('TCO 附加成本并入日均', () {
      // 300 价格 + 60 维护 - 30 残值 = 330 / 30 天 = 11
      final r = calculate(
        input(price: 300, residual: 30, usageDays: 30, tcoExtra: 60),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(11, 0.001));
      expect(r.totalCost, closeTo(360, 0.001));
    });

    test('分期 + TCO 同时生效', () {
      final plan = installmentPlan(principal: 1200, aprPercent: 12, months: 12);
      final r = calculate(
        input(
          price: 1200,
          residual: 0,
          usageDays: 365,
          installmentMonths: 12,
          aprPercent: 12,
          tcoExtra: 100,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.totalCost, closeTo(plan.totalPaid + 100, 0.001));
      expect(r.dailyCost, closeTo((plan.totalPaid + 100) / 365, 0.001));
    });

    test('订阅模式忽略分期但仍计 TCO', () {
      final r = calculate(
        input(
          price: 300,
          residual: 0,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.monthly,
          cycleLength: 1,
          installmentMonths: 12,
          aprPercent: 12,
          tcoExtra: 30,
        ),
        today: DateTime(2026, 10, 15),
      );
      expect(r.dailyCost, closeTo(330 / 30, 0.001));
      expect(r.monthlyPayment, isNull);
    });

    test('validateInputs：分期与订阅冲突给出警告', () {
      final issues = validateInputs(
        input(
          price: 300,
          mode: CalcMode.subscription,
          usageDays: null,
          cycleUnit: CycleUnit.monthly,
          cycleLength: 1,
          installmentMonths: 6,
          aprPercent: 10,
        ),
      );
      expect(
        issues.map((e) => e.messageZh),
        contains('订阅周期不支持分期，已按周期费用计算'),
      );
    });
  });
}
