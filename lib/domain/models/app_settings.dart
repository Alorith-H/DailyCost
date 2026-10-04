import 'enums.dart';

/// 应用设置（存于 settings 表）。
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.coffeePriceFen,
  });

  static const defaults = AppSettings(
    themeMode: ThemePref.system,
    coffeePriceFen: 1500, // ¥15.00
  );

  final ThemePref themeMode;

  /// 咖啡单价（分），用于试算器趣味对比
  final int coffeePriceFen;

  /// 咖啡单价（元）
  double get coffeePriceYuan => coffeePriceFen / 100.0;

  AppSettings copyWith({ThemePref? themeMode, int? coffeePriceFen}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        coffeePriceFen: coffeePriceFen ?? this.coffeePriceFen,
      );
}
