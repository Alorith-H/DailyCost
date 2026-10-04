import 'enums.dart';

/// 计价引擎的输入。所有金额单位为元（调用方负责按汇率折算）；日期仅含年月日。
///
/// 模式专属字段只在对应模式下有意义，其余模式忽略。
class CalcInputs {
  const CalcInputs({
    required this.price,
    required this.residual,
    required this.mode,
    required this.depreciation,
    required this.purchaseDate,
    this.tcoExtra = 0,
    this.aprPercent,
    this.installmentMonths,
    this.endDate,
    this.usageDays,
    this.totalUses,
    this.usesPerDay,
    this.totalHours,
    this.hoursPerDay,
    this.cycleUnit,
    this.cycleLength,
  });

  /// 购买价格（元，>= 0）
  final double price;

  /// 残值（元）
  final double residual;

  /// TCO 附加成本合计（维护/能耗/保险/配件，元）
  final double tcoExtra;

  /// 分期年利率（%），与 [installmentMonths] 同时生效
  final double? aprPercent;

  /// 分期期数（月）；> 0 时日均按「含利息总还款额」计算
  final int? installmentMonths;

  /// 计价模式
  final CalcMode mode;

  /// 折旧方式
  final DepreciationMethod depreciation;

  /// 购买日期（仅日期部分）
  final DateTime purchaseDate;

  /// 到期日（endDate 模式）
  final DateTime? endDate;

  /// 使用天数（fixedDays 模式）
  final int? usageDays;

  /// 预估总次数（perUse 模式）
  final int? totalUses;

  /// 每日次数（perUse 模式）
  final double? usesPerDay;

  /// 预估总小时（perHour 模式）
  final int? totalHours;

  /// 每日小时（perHour 模式）
  final double? hoursPerDay;

  /// 订阅周期单位（subscription 模式）
  final CycleUnit? cycleUnit;

  /// 订阅周期数，如「每 2 月」为 2（subscription 模式）
  final int? cycleLength;
}
