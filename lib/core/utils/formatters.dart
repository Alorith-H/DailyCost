import 'package:intl/intl.dart';

/// 金额/日期/百分比格式化。
final NumberFormat _money = NumberFormat.currency(
  locale: 'zh_CN',
  symbol: '¥',
  decimalDigits: 2,
);

/// ¥1,234.56
String money(double yuan) => _money.format(yuan);

/// 2026年10月4日
String dateLong(DateTime d) => DateFormat('yyyy年M月d日', 'zh_CN').format(d);

/// 10月4日
String dateShort(DateTime d) => DateFormat('M月d日', 'zh_CN').format(d);

/// 10月4日 · 周六
String dateWithWeekday(DateTime d) =>
    DateFormat('M月d日 · E', 'zh_CN').format(d);

/// 带符号百分比，如 +4.3% / -12.0%；null 显示占位符。
String percentSigned(double? x, {String placeholder = '—'}) =>
    x == null
        ? placeholder
        : '${x >= 0 ? '+' : ''}${(x * 100).toStringAsFixed(1)}%';
