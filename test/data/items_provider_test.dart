import 'package:daily_cost/data/providers.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/domain/models/item.dart';
import 'package:daily_cost/features/home/application/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ProviderContainer container;

  final purchase = DateTime(2026, 10, 1);

  ItemDraft draft({String name = '咖啡机', double price = 300, double residual = 30}) =>
      ItemDraft(
        name: name,
        price: price,
        residual: residual,
        category: '数码',
        purchaseDate: purchase,
        usageDays: 30,
        calcMode: CalcMode.fixedDays,
        depreciation: DepreciationMethod.straightLine,
        note: '',
        tags: const ['厨房'],
      );

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
  });

  test('itemsProvider CRUD 走真实库，派生 provider 自动重建', () async {
    // 初始为空
    expect(await container.read(itemsProvider.future), isEmpty);
    expect(container.read(dailySummaryProvider).todayTotal, 0);

    // 新增两条（日均 9 与 10）
    await container
        .read(itemsProvider.notifier)
        .addItem(draft());
    await container.read(itemsProvider.notifier).addItem(
      draft(name: '耳机', price: 70, residual: 0),
    );

    var items = await container.read(itemsProvider.future);
    expect(items, hasLength(2));
    expect(
      items.firstWhere((e) => e.name == '咖啡机').tags,
      ['厨房'],
    );

    // 派生结果：今日日均 = 270/30 + 70/30 ≈ 11.33
    final summary = container.read(dailySummaryProvider);
    expect(summary.todayTotal, closeTo(270 / 30 + 70 / 30, 0.001));
    expect(summary.activeCount, 2);
    expect(
      container.read(calcResultsProvider)[items.first.id]!.dailyCost,
      isNotNull,
    );

    // 更新
    final target = items.firstWhere((e) => e.name == '咖啡机');
    await container.read(itemsProvider.notifier).updateItem(
      target.copyWith(name: '磨豆机', tags: ['厨房', '咖啡']),
    );
    items = await container.read(itemsProvider.future);
    final updated = items.firstWhere((e) => e.id == target.id);
    expect(updated.name, '磨豆机');
    expect(updated.tags, ['厨房', '咖啡']); // 按名称排序（厨 < 咖）

    // 软删除 + 撤销
    await container.read(itemsProvider.notifier).softDelete(target.id);
    expect(await container.read(itemsProvider.future), hasLength(1));
    expect(
      container.read(dailySummaryProvider).todayTotal,
      closeTo(70 / 30, 0.001),
    );

    await container.read(itemsProvider.notifier).restore(target.id);
    expect(await container.read(itemsProvider.future), hasLength(2));
    expect(
      container.read(dailySummaryProvider).todayTotal,
      closeTo(270 / 30 + 70 / 30, 0.001),
    );
  });
}
