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

  /// 分类固定色序（CVD 校验通过的 8 色槽位，「其他」归中性灰）。
  /// 顺序即安全机制：换主题时不得重排或循环取色。
  static const Map<String, Color> _categoryLight = {
    '餐饮': Color(0xFF2A78D6),
    '交通': Color(0xFFEB6834),
    '居住': Color(0xFF1BAF7A),
    '数码': Color(0xFFEDA100),
    '订阅': Color(0xFFE87BA4),
    '娱乐': Color(0xFF008300),
    '健康': Color(0xFF4A3AA7),
    '学习': Color(0xFFE34948),
  };

  static const Map<String, Color> _categoryDark = {
    '餐饮': Color(0xFF3987E5),
    '交通': Color(0xFFD95926),
    '居住': Color(0xFF199E70),
    '数码': Color(0xFFC98500),
    '订阅': Color(0xFFD55181),
    '娱乐': Color(0xFF008300),
    '健康': Color(0xFF9085E9),
    '学习': Color(0xFFE66767),
  };

  /// 分类 → 图表颜色（未知/「其他」为中性灰）。
  static Color category(String name, Brightness b) {
    final map = b == Brightness.dark ? _categoryDark : _categoryLight;
    return map[name] ??
        (b == Brightness.dark ? const Color(0xFF8A8982) : const Color(0xFF9A9992));
  }

  /// 热力图顺序色阶（单色相 蓝，浅→深；浅色模式）。
  static const List<Color> heatLight = [
    Color(0xFFE8F1FD),
    Color(0xFFCDE2FB),
    Color(0xFF9EC5F4),
    Color(0xFF6DA7EC),
    Color(0xFF3987E5),
    Color(0xFF1C5CAB),
    Color(0xFF0D366B),
  ];

  /// 热力图顺序色阶（深色模式：深→浅翻转，贴近深色表面）。
  static const List<Color> heatDark = [
    Color(0xFF22303F),
    Color(0xFF184F95),
    Color(0xFF256ABF),
    Color(0xFF3987E5),
    Color(0xFF5598E7),
    Color(0xFF86B6EF),
    Color(0xFFB7D3F6),
  ];
}
