import 'package:daily_cost/data/db/app_database.dart';
import 'package:daily_cost/data/repositories/item_repository.dart';
import 'package:daily_cost/domain/models/enums.dart';
import 'package:daily_cost/domain/models/item.dart';
import 'package:daily_cost/domain/models/item_cost.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late ItemRepository repo;

  final purchase = DateTime(2026, 10, 1);

  ItemDraft draft({
    String name = '咖啡机',
    double price = 300.01,
    double residual = 30.5,
    String category = '数码',
    DateTime? purchaseDate,
    int? usageDays = 30,
    CalcMode mode = CalcMode.fixedDays,
  }) => ItemDraft(
    name: name,
    price: price,
    residual: residual,
    category: category,
    purchaseDate: purchaseDate ?? purchase,
    usageDays: usageDays,
    calcMode: mode,
    depreciation: DepreciationMethod.straightLine,
    note: '',
    tags: const [],
  );

  setUp(() async {
    db = await openTestDatabase();
    repo = ItemRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('插入并读回：分↔元换算、字段完整', () async {
    final id = await repo.insert(draft(), const ['数码', '厨房']);
    final item = await repo.findById(id);

    expect(item, isNotNull);
    expect(item!.id, id);
    expect(item.name, '咖啡机');
    expect(item.price, closeTo(300.01, 0.001));
    expect(item.residual, closeTo(30.5, 0.001));
    expect(item.category, '数码');
    expect(item.purchaseDate, purchase);
    expect(item.usageDays, 30);
    expect(item.calcMode, CalcMode.fixedDays);
    expect(item.depreciation, DepreciationMethod.straightLine);
    expect(item.deletedAt, isNull);
    expect(item.tags, ['厨房', '数码']); // 按名称排序
  });

  test('更新字段与标签', () async {
    final id = await repo.insert(draft(), const ['a']);
    final item = (await repo.findById(id))!;
    await repo.update(
      item.copyWith(name: '手冲壶', price: 199.99, usageDays: 60),
      const ['b', 'c'],
    );
    final updated = (await repo.findById(id))!;

    expect(updated.name, '手冲壶');
    expect(updated.price, closeTo(199.99, 0.001));
    expect(updated.usageDays, 60);
    expect(updated.tags, ['b', 'c']);
  });

  test('软删除隐藏、includeDeleted 显示、restore 恢复', () async {
    final id = await repo.insert(draft(), const []);
    await repo.softDelete(id);

    expect(await repo.findAll(), isEmpty);
    expect(await repo.findAll(includeDeleted: true), hasLength(1));
    expect((await repo.findById(id))!.deletedAt, isNotNull);

    await repo.restore(id);
    expect(await repo.findAll(), hasLength(1));
    expect((await repo.findById(id))!.deletedAt, isNull);
  });

  test('标签空串忽略；重复标签去重', () async {
    final id = await repo.insert(draft(), const ['  ', '常用', '常用', '常用']);
    final item = (await repo.findById(id))!;
    expect(item.tags, ['常用']);
  });

  test('endDate / subscription 字段往返', () async {
    final endDate = DateTime(2026, 12, 31);
    final id2 = await repo.insert(
      ItemDraft(
        name: '会员',
        price: 120,
        residual: 0,
        category: '订阅',
        purchaseDate: purchase,
        cycleUnit: CycleUnit.monthly,
        cycleLength: 2,
        calcMode: CalcMode.subscription,
        depreciation: DepreciationMethod.straightLine,
        note: 'note',
        tags: const [],
      ),
      const [],
    );
    final id3 = await repo.insert(
      ItemDraft(
        name: '健身房',
        price: 600,
        residual: 100,
        category: '健康',
        purchaseDate: purchase,
        endDate: endDate,
        calcMode: CalcMode.endDate,
        depreciation: DepreciationMethod.decliningBalance,
        note: '',
        tags: const [],
      ),
      const [],
    );

    final item2 = (await repo.findById(id2))!;
    expect(item2.cycleUnit, CycleUnit.monthly);
    expect(item2.cycleLength, 2);
    expect(item2.calcMode, CalcMode.subscription);
    expect(item2.note, 'note');

    final item3 = (await repo.findById(id3))!;
    expect(item3.endDate, endDate);
    expect(item3.calcMode, CalcMode.endDate);
    expect(item3.depreciation, DepreciationMethod.decliningBalance);
  });

  test('模式专属字段可空往返（perUse）', () async {
    final id = await repo.insert(
      ItemDraft(
        name: '剧本杀',
        price: 100,
        residual: 0,
        category: '娱乐',
        purchaseDate: purchase,
        totalUses: 10,
        usesPerDay: 0.5,
        calcMode: CalcMode.perUse,
        depreciation: DepreciationMethod.straightLine,
        note: '',
        tags: const [],
      ),
      const [],
    );
    final item = (await repo.findById(id))!;
    expect(item.totalUses, 10);
    expect(item.usesPerDay, closeTo(0.5, 0.001));
    expect(item.usageDays, isNull);
    expect(item.endDate, isNull);
    expect(item.cycleUnit, isNull);
  });

  test('TCO 成本 / 分期 / 币种 / 照片 往返与更新', () async {
    final id = await repo.insert(
      ItemDraft(
        name: '游戏本',
        price: 8000,
        residual: 2000,
        category: '数码',
        purchaseDate: purchase,
        currency: 'USD',
        aprPercent: 6.5,
        installmentMonths: 24,
        usageDays: 365,
        calcMode: CalcMode.fixedDays,
        depreciation: DepreciationMethod.straightLine,
        note: '',
        tags: const [],
        photos: const ['/a/b.jpg', '/c/d.jpg'],
        extraCosts: const [
          ItemCostDraft(category: '维护', amount: 299, note: '延保'),
          ItemCostDraft(category: '配件', amount: 199.5, note: '鼠标'),
        ],
      ),
      const [],
    );

    var item = (await repo.findById(id))!;
    expect(item.currency, 'USD');
    expect(item.aprPercent, closeTo(6.5, 0.001));
    expect(item.installmentMonths, 24);
    expect(item.photos, ['/a/b.jpg', '/c/d.jpg']);
    expect(item.extraCosts, hasLength(2));
    expect(item.extraCostsTotal, closeTo(498.5, 0.001));
    expect(item.tcoTotal, closeTo(8498.5, 0.001));

    // 更新：成本替换（旧的删掉）、照片清空、分期取消
    await repo.update(
      item.copyWith(
        aprPercent: null,
        installmentMonths: null,
        photos: const [],
        extraCosts: [
          ItemCost(
            id: 0,
            itemId: id,
            category: '能耗',
            amount: 66,
            note: '电费',
            createdAt: DateTime.now(),
          ),
        ],
      ),
      const [],
    );
    item = (await repo.findById(id))!;
    expect(item.aprPercent, isNull);
    expect(item.installmentMonths, isNull);
    expect(item.photos, isEmpty);
    expect(item.extraCosts, hasLength(1));
    expect(item.extraCosts.first.category, '能耗');
    expect(item.extraCostsTotal, closeTo(66, 0.001));
  });

  test('purgeDeletedBefore 硬删除过期回收站记录', () async {
    final id = await repo.insert(draft(), const []);
    await repo.softDelete(id);
    expect(await repo.findAll(includeDeleted: true), hasLength(1));

    await repo.purgeDeletedBefore(DateTime.now().add(const Duration(days: 1)));
    expect(await repo.findAll(includeDeleted: true), isEmpty);
    expect(await repo.findById(id), isNull);
  });
}
