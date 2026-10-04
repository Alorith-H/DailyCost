/// DailyCost 计价引擎（纯 Dart，无 I/O，永不抛异常）。
///
/// 核心公式：**日均成本 = (购买价格 - 残值) ÷ 使用天数**
///
/// 全局约定：
/// - 天数计算**含购买日**：N 天 = purchaseDate .. purchaseDate+N-1，
///   elapsed = clamp((today-purchaseDate).inDays + 1, 0, N)，购买当天已用 1 天。
/// - 到期日模式 N = (endDate-purchaseDate).inDays + 1（含到期日当天）。
/// - 非法输入一律规范化（见 calculate 文档）；表单校验请用 validateInputs。
library;

import 'dart:math' as math;

import '../models/calc_inputs.dart';
import '../models/calc_result.dart';
import '../models/daily_summary.dart';
import '../models/enums.dart';

/// 订阅周期单位对应的天数（月按 30 天、年按 365 天，便于心算）。
const Map<CycleUnit, int> kCycleUnitDays = {
  CycleUnit.weekly: 7,
  CycleUnit.monthly: 30,
  CycleUnit.yearly: 365,
};

/// 周期总天数 = 单位天数 × 周期数；周期数 <= 0 时钳为 1。
int cycleDaysFor(CycleUnit unit, int length) =>
    kCycleUnitDays[unit]! * math.max(1, length);

/// 计算问题的字段。
enum CalcIssueField {
  price,
  residual,
  purchaseDate,
  endDate,
  usageDays,
  totalUses,
  usesPerDay,
  totalHours,
  hoursPerDay,
  cycleLength,
}

/// 问题级别：error 阻断保存，warning 仅提示。
enum CalcIssueSeverity { error, warning }

/// 表单校验问题（中文提示）。
class CalcIssue {
  const CalcIssue({
    required this.field,
    required this.messageZh,
    this.severity = CalcIssueSeverity.error,
  });

  final CalcIssueField field;
  final String messageZh;
  final CalcIssueSeverity severity;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

double _clamp01(double x) => x.clamp(0.0, 1.0);

/// 剩余价值曲线（有限 N 模式）。
///
/// - 直线折旧：P - (P-R)×t/N
/// - 余额递减：P × (R/P)^(t/N)（t=N 时恰好等于 R）
/// - R <= 0 且余额递减时回退直线折旧
///
/// t 钳制在 [0, N]；N <= 0 按 1 处理；金额输入钳制为 P >= R >= 0。
double remainingValueAt({
  required double price,
  required double residual,
  required DepreciationMethod method,
  required double totalDays,
  required double elapsedDays,
}) {
  final p = math.max(0.0, price);
  final r = residual.clamp(0.0, p);
  final n = math.max(1.0, totalDays);
  final t = elapsedDays.clamp(0.0, n);

  if (method == DepreciationMethod.decliningBalance && r > 0) {
    return p * math.pow(r / p, t / n).toDouble();
  }
  // 直线折旧（余额递减且 R<=0 时也走这里）
  return p - (p - r) * (t / n);
}

/// 计算一条记录在 `today` 的完整结果。永不抛异常。
///
/// 规范化规则：
/// - 天数/次数/小时/周期数 <= 0 → 分母钳为 1；每日次数/小时 <= 0 → 钳为 0（日均为 0）
/// - 残值钳制到 [0, 价格]；残值 >= 价格时日均为 0（总额永不出负数）
/// - 购买日在未来 → status=notStarted、elapsed=0、progress=0
///   （dailyCost 仍按公式给出预计值；是否计入总额由 summarize 的 status 过滤）
/// - subscription：日均 = 价格/周期天数，**忽略残值与折旧**，永不过期，
///   progress 为当前周期内位置，remainingValue 为周期内直线余额
/// - actualDays：totalDays=null（开放式），effectiveDays = max(1, (today-purchaseDate).inDays+1)
/// - perUse：costPerUse=(P-R)/总次数，日均=costPerUse×每日次数，
///   totalDays=总次数/每日次数（每日次数为 0 时开放式）
/// - perHour：与 perUse 同构，单位换成小时
CalcResult calculate(CalcInputs input, {DateTime? today}) {
  final now = _dateOnly(today ?? DateTime.now());
  final purchase = _dateOnly(input.purchaseDate);

  final price = math.max(0.0, input.price);
  final residual = input.residual.clamp(0.0, price);

  // 含购买日的已用天数；购买日之前为 0
  final rawElapsed = now.difference(purchase).inDays + 1;
  final notStarted = rawElapsed <= 0;

  double daily;
  double? totalDays;
  double elapsedDays;
  double? progress;
  double? remainingValue;
  double? costPerUse;
  double? costPerHour;

  switch (input.mode) {
    case CalcMode.fixedDays:
      final n = math.max(1, input.usageDays ?? 1).toDouble();
      totalDays = n;
      daily = (price - residual) / n;

    case CalcMode.endDate:
      final end = input.endDate;
      // 到期日须晚于购买日才有跨度；否则钳为 1 天
      final span = end == null ? 1 : end.difference(purchase).inDays + 1;
      final n = math.max(1, span).toDouble();
      totalDays = n;
      daily = (price - residual) / n;

    case CalcMode.subscription:
      final cycleDays =
          cycleDaysFor(input.cycleUnit ?? CycleUnit.monthly, input.cycleLength ?? 1)
              .toDouble();
      totalDays = cycleDays;
      daily = price / cycleDays;

    case CalcMode.actualDays:
      final effectiveDays = math.max(1, rawElapsed).toDouble();
      daily = (price - residual) / effectiveDays;
      totalDays = null;

    case CalcMode.perUse:
      final uses = math.max(1, input.totalUses ?? 1).toDouble();
      final perDay = math.max(0.0, input.usesPerDay ?? 0.0);
      costPerUse = (price - residual) / uses;
      daily = costPerUse * perDay;
      totalDays = perDay > 0 ? uses / perDay : null;

    case CalcMode.perHour:
      final hours = math.max(1, input.totalHours ?? 1).toDouble();
      final perDay = math.max(0.0, input.hoursPerDay ?? 0.0);
      costPerHour = (price - residual) / hours;
      daily = costPerHour * perDay;
      totalDays = perDay > 0 ? hours / perDay : null;
  }

  // 状态与进度
  final ItemStatus status;
  if (notStarted) {
    status = ItemStatus.notStarted;
    elapsedDays = 0;
    progress = 0;
    remainingValue = price;
    return CalcResult(
      dailyCost: math.max(0.0, daily),
      totalDays: totalDays,
      elapsedDays: elapsedDays,
      progress: progress,
      remainingValue: remainingValue,
      costPerUse: costPerUse,
      costPerHour: costPerHour,
      status: status,
    );
  }

  final openEnded = totalDays == null;

  if (input.mode == CalcMode.subscription) {
    final cycleDays = cycleDaysFor(
      input.cycleUnit ?? CycleUnit.monthly,
      input.cycleLength ?? 1,
    ).toDouble();
    final dayInCycle = ((now.difference(purchase).inDays) % cycleDays) + 1;
    elapsedDays = dayInCycle;
    progress = _clamp01(dayInCycle / cycleDays);
    // 周期内直线余额
    remainingValue = price * (1 - dayInCycle / cycleDays);
    status = ItemStatus.inUse;
  } else if (openEnded) {
    elapsedDays = math.max(0.0, rawElapsed.toDouble());
    progress = null;
    remainingValue = null;
    status = ItemStatus.inUse;
  } else {
    final n = totalDays;
    final expired = rawElapsed > n;
    status = expired ? ItemStatus.expired : ItemStatus.inUse;
    elapsedDays = rawElapsed.clamp(0, n).toDouble();
    progress = _clamp01(elapsedDays / n);
    remainingValue = remainingValueAt(
      price: price,
      residual: residual,
      method: input.depreciation,
      totalDays: n,
      elapsedDays: elapsedDays,
    );
  }

  return CalcResult(
    dailyCost: math.max(0.0, daily),
    totalDays: totalDays,
    elapsedDays: elapsedDays,
    progress: progress,
    remainingValue: remainingValue,
    costPerUse: costPerUse,
    costPerHour: costPerHour,
    status: status,
  );
}

/// 在用物品（status == inUse）的日均之和。
double totalDailyCost(Iterable<CalcInputs> items, {DateTime? today}) =>
    summarize(items, today: today).todayTotal;

/// 汇总今日/昨日总额与环比。未开始与已到期物品不计入总额。
DailySummary summarize(Iterable<CalcInputs> items, {DateTime? today}) {
  final now = _dateOnly(today ?? DateTime.now());
  final yesterday = now.subtract(const Duration(days: 1));

  double todayTotal = 0;
  double yesterdayTotal = 0;
  var activeCount = 0;

  for (final input in items) {
    final r = calculate(input, today: now);
    if (r.status == ItemStatus.inUse) {
      todayTotal += r.dailyCost;
      activeCount++;
    }
    final ry = calculate(input, today: yesterday);
    if (ry.status == ItemStatus.inUse) {
      yesterdayTotal += ry.dailyCost;
    }
  }

  final delta = todayTotal - yesterdayTotal;
  return DailySummary(
    todayTotal: todayTotal,
    yesterdayTotal: yesterdayTotal,
    delta: delta,
    deltaPercent: yesterdayTotal == 0 ? null : delta / yesterdayTotal,
    activeCount: activeCount,
  );
}

/// 表单校验（中文提示）。error 阻断保存，warning 仅提示。
/// 结果按字段语义返回，不抛异常。
List<CalcIssue> validateInputs(CalcInputs input, {DateTime? today}) {
  final issues = <CalcIssue>[];

  if (input.price < 0) {
    issues.add(const CalcIssue(
      field: CalcIssueField.price,
      messageZh: '价格不能为负',
    ));
  }
  if (input.residual < 0) {
    issues.add(const CalcIssue(
      field: CalcIssueField.residual,
      messageZh: '残值不能为负',
    ));
  } else if (input.residual > input.price) {
    issues.add(const CalcIssue(
      field: CalcIssueField.residual,
      messageZh: '残值不应高于价格',
      severity: CalcIssueSeverity.warning,
    ));
  }

  switch (input.mode) {
    case CalcMode.fixedDays:
      if ((input.usageDays ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.usageDays,
          messageZh: '使用天数须大于 0',
        ));
      }
    case CalcMode.endDate:
      final end = input.endDate;
      if (end == null) {
        issues.add(const CalcIssue(
          field: CalcIssueField.endDate,
          messageZh: '请选择到期日',
        ));
      } else if (end.difference(input.purchaseDate).inDays < 1) {
        issues.add(const CalcIssue(
          field: CalcIssueField.endDate,
          messageZh: '到期日须晚于购买日',
        ));
      }
    case CalcMode.subscription:
      if ((input.cycleLength ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.cycleLength,
          messageZh: '周期数须大于 0',
        ));
      }
    case CalcMode.actualDays:
      break; // 无模式专属输入
    case CalcMode.perUse:
      if ((input.totalUses ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.totalUses,
          messageZh: '预估总次数须大于 0',
        ));
      }
      if ((input.usesPerDay ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.usesPerDay,
          messageZh: '每日次数须大于 0',
        ));
      }
    case CalcMode.perHour:
      if ((input.totalHours ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.totalHours,
          messageZh: '预估总小时须大于 0',
        ));
      }
      if ((input.hoursPerDay ?? 0) <= 0) {
        issues.add(const CalcIssue(
          field: CalcIssueField.hoursPerDay,
          messageZh: '每日小时须大于 0',
        ));
      }
  }

  return issues;
}
