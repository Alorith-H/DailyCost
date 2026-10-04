import 'package:flutter/material.dart';

/// 语义颜色（中式习惯：涨红跌绿——支出涨=红/坏，跌=绿/好）。
abstract final class AppColors {
  /// 种子色：沉静的账本青绿。
  static const Color seed = Color(0xFF00796B);

  /// 支出上涨（浅色模式）
  static const Color expenseUpLight = Color(0xFFD32F2F);

  /// 支出下降（浅色模式）
  static const Color expenseDownLight = Color(0xFF2E7D32);

  /// 支出上涨（深色模式）
  static const Color expenseUpDark = Color(0xFFEF5350);

  /// 支出下降（深色模式）
  static const Color expenseDownDark = Color(0xFF66BB6A);

  /// 按亮度取语义色。
  static Color expenseUp(Brightness b) =>
      b == Brightness.dark ? expenseUpDark : expenseUpLight;

  static Color expenseDown(Brightness b) =>
      b == Brightness.dark ? expenseDownDark : expenseDownLight;
}
