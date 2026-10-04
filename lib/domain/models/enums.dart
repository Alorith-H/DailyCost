/// 领域枚举。纯 Dart，不依赖 Flutter。
library;

/// 计价模式（六种）。
enum CalcMode {
  /// 固定天数：用户输入使用天数 N，日均 = (价格-残值)/N
  fixedDays,

  /// 到期日：N = 到期日-购买日+1（含首尾），日均 = (价格-残值)/N
  endDate,

  /// 订阅周期：按周期摊薄，日均 = 价格/周期天数（忽略残值与折旧）
  subscription,

  /// 实际天数：按已使用天数每天重算，开放式
  actualDays,

  /// 按次：单次成本 × 每日次数
  perUse,

  /// 按小时：单小时成本 × 每日小时
  perHour,
}

/// 折旧方式（只影响剩余价值曲线，不影响日均公式）。
enum DepreciationMethod {
  /// 直线折旧：剩余(t) = P - (P-R)×t/N
  straightLine,

  /// 余额递减：剩余(t) = P × (R/P)^(t/N)，几何递减且 t=N 时等于 R
  decliningBalance,
}

/// 订阅周期单位。
enum CycleUnit {
  /// 每周（7 天）
  weekly,

  /// 每月（30 天）
  monthly,

  /// 每年（365 天）
  yearly,
}

/// 物品状态。
enum ItemStatus {
  /// 未开始（购买日在未来）
  notStarted,

  /// 使用中
  inUse,

  /// 已到期（有限跨度已走完）
  expired,
}

/// 主题偏好（存库字符串，与 Flutter 的 ThemeMode 解耦）。
enum ThemePref {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePref(this.settingsValue);

  /// settings 表中存储的值。
  final String settingsValue;

  static ThemePref fromSettingsValue(String? value) =>
      ThemePref.values.firstWhere(
        (e) => e.settingsValue == value,
        orElse: () => ThemePref.system,
      );
}
