import 'enums.dart';

/// 计价引擎的输出。所有金额单位为元。
class CalcResult {
  const CalcResult({
    required this.dailyCost,
    required this.totalDays,
    required this.elapsedDays,
    required this.progress,
    required this.remainingValue,
    required this.costPerUse,
    required this.costPerHour,
    required this.status,
    required this.totalCost,
    this.monthlyPayment,
    this.totalInterest,
  });

  /// 日均成本（元/天，>= 0，已规范化）
  final double dailyCost;

  /// 摊薄总天数；null = 开放式（actualDays，或按次但每日次数为 0）
  final double? totalDays;

  /// 已使用天数（>= 0；订阅模式为「本周期第几天」）
  final double elapsedDays;

  /// 进度 0..1；开放式为 null。订阅模式为当前周期内位置
  final double? progress;

  /// 当前剩余价值（元）；开放式为 null
  final double? remainingValue;

  /// 单次成本（仅 perUse）
  final double? costPerUse;

  /// 单小时成本（仅 perHour）
  final double? costPerHour;

  /// 状态
  final ItemStatus status;

  /// 计入 TCO 与分期利息后的总成本（元）
  final double totalCost;

  /// 分期月供（仅分期时有值）
  final double? monthlyPayment;

  /// 分期利息总额（仅分期时有值）
  final double? totalInterest;
}
