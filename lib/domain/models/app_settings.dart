import 'enums.dart';

/// 应用设置（存于 settings 表）。
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.coffeePriceFen,
    required this.autoUpdateCheck,
    required this.fxRates,
    this.notifyExpiry = true,
    this.notifyRenewal = true,
    this.notifyWeekly = true,
    this.notifyBackup = true,
  });

  static const defaults = AppSettings(
    themeMode: ThemePref.system,
    coffeePriceFen: 1500, // ¥15.00
    autoUpdateCheck: true,
    fxRates: {'CNY': 1.0},
  );

  final ThemePref themeMode;

  /// 咖啡单价（分），用于试算器趣味对比
  final int coffeePriceFen;

  /// 启动时自动检查更新（唯一的联网行为，仅访问 GitHub）
  final bool autoUpdateCheck;

  /// 离线汇率表：1 单位外币 → 人民币（读取时已与默认表合并）
  final Map<String, double> fxRates;

  /// 提醒开关
  final bool notifyExpiry;
  final bool notifyRenewal;
  final bool notifyWeekly;
  final bool notifyBackup;

  /// 咖啡单价（元）
  double get coffeePriceYuan => coffeePriceFen / 100.0;

  /// 取汇率；未知币种按 1.0。
  double fxToCny(String currency) => fxRates[currency] ?? 1.0;

  AppSettings copyWith({
    ThemePref? themeMode,
    int? coffeePriceFen,
    bool? autoUpdateCheck,
    Map<String, double>? fxRates,
    bool? notifyExpiry,
    bool? notifyRenewal,
    bool? notifyWeekly,
    bool? notifyBackup,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    coffeePriceFen: coffeePriceFen ?? this.coffeePriceFen,
    autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
    fxRates: fxRates ?? this.fxRates,
    notifyExpiry: notifyExpiry ?? this.notifyExpiry,
    notifyRenewal: notifyRenewal ?? this.notifyRenewal,
    notifyWeekly: notifyWeekly ?? this.notifyWeekly,
    notifyBackup: notifyBackup ?? this.notifyBackup,
  );
}
