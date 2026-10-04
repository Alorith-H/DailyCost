/// 表单字段校验（纯函数，中文提示）。返回 null 表示通过。
library;

final RegExp _moneyPattern = RegExp(r'^\d+(\.\d{1,2})?$');

/// 名称：必填，1-40 字。
String? validateName(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return '请输入名称';
  if (s.length > 40) return '名称不能超过 40 字';
  return null;
}

/// 价格：必填、非负、最多两位小数。
String? validatePrice(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return '请输入价格';
  if (!_moneyPattern.hasMatch(s)) return '请输入正确的价格（最多两位小数）';
  return null;
}

/// 残值：可空（视作 0）、非负、最多两位小数。
String? validateResidual(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  if (!_moneyPattern.hasMatch(s)) return '请输入正确的价格（最多两位小数）';
  return null;
}

/// 正整数字段（使用天数/总次数/总小时/周期数）。
String? validatePositiveInt(String? v, {required String label}) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return '请输入$label';
  final n = int.tryParse(s);
  if (n == null || n <= 0) return '$label须大于 0';
  return null;
}

/// 正小数字段（每日次数/每日小时）。
String? validatePositiveDouble(String? v, {required String label}) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return '请输入$label';
  final n = double.tryParse(s);
  if (n == null || n <= 0) return '$label须大于 0';
  return null;
}
