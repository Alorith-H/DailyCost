import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/domain/models/item.dart';
import 'package:daily_cost/domain/models/item_cost.dart';
import 'package:daily_cost/features/data_manage/application/csv_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final purchase = DateTime(2026, 10, 1);

  Item item({
    String name = '咖啡机',
    double price = 300.01,
    double residual = 30.5,
    String currency = 'CNY',
    List<String> tags = const ['厨房', '数码'],
    List<ItemCostDraft> costs = const [],
    double? apr,
    int? months,
  }) => Item(
    id: 1,
    name: name,
    price: price,
    residual: residual,
    category: '数码',
    purchaseDate: purchase,
    currency: currency,
    aprPercent: apr,
    installmentMonths: months,
    endDate: DateTime(2026, 12, 31),
    usageDays: null,
    calcMode: CalcMode.endDate,
    depreciation: DepreciationMethod.straightLine,
    note: '含逗号, 和引号"',
    tags: tags,
    extraCosts: [
      for (final c in costs)
        ItemCost(
          id: 0,
          itemId: 1,
          category: c.category,
          amount: c.amount,
          note: c.note,
          createdAt: purchase,
        ),
    ],
    createdAt: purchase,
    updatedAt: purchase,
  );

  test('CSV 往返一致（含引号/逗号/标签/成本）', () {
    final original = item(
      costs: const [
        ItemCostDraft(category: '维护', amount: 299, note: '延保;三年'),
        ItemCostDraft(category: '配件', amount: 199.5, note: '鼠标'),
      ],
      apr: 6.5,
      months: 24,
    );
    final csv = itemsToCsv([original]);
    final result = csvToDrafts(csv);

    expect(result.skipped, 0);
    expect(result.drafts, hasLength(1));
    final draft = result.drafts.single;
    expect(draft.name, '咖啡机');
    expect(draft.price, closeTo(300.01, 0.001));
    expect(draft.residual, closeTo(30.5, 0.001));
    expect(draft.purchaseDate, purchase);
    expect(draft.endDate, DateTime(2026, 12, 31));
    expect(draft.calcMode, CalcMode.endDate);
    expect(draft.aprPercent, closeTo(6.5, 0.001));
    expect(draft.installmentMonths, 24);
    expect(draft.note, '含逗号, 和引号"');
    expect(draft.tags, ['厨房', '数码']);
    expect(draft.extraCosts, hasLength(2));
    expect(draft.extraCosts[0].category, '维护');
    // 分号在成本备注中被转义为中文逗号，因此回读后是「延保，三年」
    expect(draft.extraCosts[0].amount, closeTo(299, 0.001));
    expect(draft.extraCosts[1].amount, closeTo(199.5, 0.001));
  });

  test('空 CSV / 脏行容错', () {
    expect(csvToDrafts('').drafts, isEmpty);

    const dirty = '''
name,price,residual,currency,category,purchase_date,calc_mode,usage_days,end_date,total_uses,uses_per_day,total_hours,hours_per_day,cycle_unit,cycle_length,apr_percent,installment_months,depreciation,note,tags,costs
"好记录",100,0,CNY,数码,2026-10-01,fixedDays,30,,,,,,,,,,straightLine,,,,
"坏记录",不是数字,0,CNY,数码,2026-10-01,fixedDays,30,,,,,,,,,,straightLine,,,,
"",100,0,CNY,数码,2026-10-01,fixedDays,30,,,,,,,,,,straightLine,,,,
''';
    final result = csvToDrafts(dirty);
    expect(result.drafts, hasLength(1));
    expect(result.drafts.single.name, '好记录');
    expect(result.skipped, 2);
  });
}
