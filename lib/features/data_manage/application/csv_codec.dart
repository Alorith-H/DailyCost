/// 记录 CSV 编解码（纯 Dart，可单测）。导入导出共用同一格式保证往返一致。
library;

import '../../../domain/models/enums.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/item_cost.dart';

/// CSV 列（顺序固定）。
const List<String> csvColumns = [
  'name', 'price', 'residual', 'currency', 'category', 'purchase_date',
  'calc_mode', 'usage_days', 'end_date', 'total_uses', 'uses_per_day',
  'total_hours', 'hours_per_day', 'cycle_unit', 'cycle_length',
  'apr_percent', 'installment_months', 'depreciation', 'note', 'tags', 'costs',
];

String _esc(String v) => '"${v.replaceAll('"', '""')}"';

String _num(num? v) => v?.toString() ?? '';

/// 导出为 CSV 文本。tags 用 `;` 分隔；costs 为 `分类:金额:备注` 用 `;` 分隔。
String itemsToCsv(List<Item> items) {
  final buffer = StringBuffer(csvColumns.map(_esc).join(','));
  for (final it in items) {
    buffer.writeln();
    final costs = it.extraCosts
        .map((c) => '${c.category}:${c.amount}:${c.note.replaceAll(';', '，')}')
        .join(';');
    buffer.write([
      _esc(it.name),
      _num(it.price),
      _num(it.residual),
      _esc(it.currency),
      _esc(it.category),
      _esc(_date(it.purchaseDate)),
      _esc(it.calcMode.name),
      _num(it.usageDays),
      it.endDate == null ? '' : _esc(_date(it.endDate!)),
      _num(it.totalUses),
      _num(it.usesPerDay),
      _num(it.totalHours),
      _num(it.hoursPerDay),
      it.cycleUnit == null ? '' : _esc(it.cycleUnit!.name),
      _num(it.cycleLength),
      _num(it.aprPercent),
      _num(it.installmentMonths),
      _esc(it.depreciation.name),
      _esc(it.note),
      _esc(it.tags.join(';')),
      _esc(costs),
    ].join(','));
  }
  return buffer.toString();
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 解析 CSV 文本为草稿列表。首行为表头；列名缺失时按 [csvColumns] 顺序兜底。
/// 解析失败的行被跳过并计入 [ParseResult.skipped]。
ParseResult csvToDrafts(String content) {
  final rows = _splitCsv(content);
  if (rows.isEmpty) return const ParseResult(drafts: [], skipped: 0);
  final header = rows.first;
  final index = {for (var i = 0; i < header.length; i++) header[i]: i};

  String cell(List<String> row, String key) {
    final i = index[key] ?? (csvColumns.contains(key) ? csvColumns.indexOf(key) : -1);
    if (i < 0 || i >= row.length) return '';
    return row[i].trim();
  }

  final drafts = <ItemDraft>[];
  var skipped = 0;
  for (final row in rows.skip(1)) {
    if (row.every((c) => c.trim().isEmpty)) continue;
    try {
      final name = cell(row, 'name');
      final price = double.parse(cell(row, 'price'));
      final purchase = _parseDate(cell(row, 'purchase_date'));
      if (name.isEmpty || purchase == null) {
        skipped++;
        continue;
      }
      drafts.add(ItemDraft(
        name: name,
        price: price,
        residual: double.tryParse(cell(row, 'residual')) ?? 0,
        currency: cell(row, 'currency').isEmpty ? 'CNY' : cell(row, 'currency'),
        category: cell(row, 'category').isEmpty ? '其他' : cell(row, 'category'),
        purchaseDate: purchase,
        aprPercent: double.tryParse(cell(row, 'apr_percent')),
        installmentMonths: int.tryParse(cell(row, 'installment_months')),
        endDate: _parseDate(cell(row, 'end_date')),
        usageDays: int.tryParse(cell(row, 'usage_days')),
        totalUses: int.tryParse(cell(row, 'total_uses')),
        usesPerDay: double.tryParse(cell(row, 'uses_per_day')),
        totalHours: int.tryParse(cell(row, 'total_hours')),
        hoursPerDay: double.tryParse(cell(row, 'hours_per_day')),
        cycleUnit: CycleUnit.values.asNameMap()[cell(row, 'cycle_unit')],
        cycleLength: int.tryParse(cell(row, 'cycle_length')),
        calcMode: CalcMode.values.asNameMap()[cell(row, 'calc_mode')] ??
            CalcMode.fixedDays,
        depreciation:
            DepreciationMethod.values.asNameMap()[cell(row, 'depreciation')] ??
                DepreciationMethod.straightLine,
        note: cell(row, 'note'),
        tags: cell(row, 'tags')
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        extraCosts: _parseCosts(cell(row, 'costs')),
      ));
    } catch (_) {
      skipped++;
    }
  }
  return ParseResult(drafts: drafts, skipped: skipped);
}

class ParseResult {
  const ParseResult({required this.drafts, required this.skipped});

  final List<ItemDraft> drafts;
  final int skipped;
}

List<ItemCostDraft> _parseCosts(String raw) {
  if (raw.isEmpty) return const [];
  return [
    for (final part in raw.split(';'))
      if (part.trim().isNotEmpty) _parseCost(part.trim()),
  ];
}

ItemCostDraft _parseCost(String s) {
  final parts = s.split(':');
  return ItemCostDraft(
    category: parts.isNotEmpty ? parts[0] : '其他',
    amount: parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 0,
    note: parts.length > 2 ? parts.sublist(2).join(':') : '',
  );
}

DateTime? _parseDate(String s) {
  if (s.isEmpty) return null;
  final parts = s.split('-');
  if (parts.length != 3) return null;
  return DateTime.tryParse(s);
}

/// 简易 CSV 行切分（支持引号转义与行内逗号/换行）。
List<List<String>> _splitCsv(String content) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\r') {
      // 忽略
    } else if (ch == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
