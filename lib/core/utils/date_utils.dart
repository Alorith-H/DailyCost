/// 日期小工具。
library;

/// 取日期部分（丢弃时分秒）。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
