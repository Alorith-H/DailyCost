import 'package:daily_cost/domain/models/item.dart';
import 'package:daily_cost/features/home/application/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 内存版 ItemsNotifier，供 widget 测试使用。
///
/// 不碰 sqlite3：其 native assets 加载依赖真实事件循环，
/// 在 testWidgets 的 FakeAsync 下会挂死（真实 DB 接线见
/// test/data/items_provider_test.dart，用普通 test() 覆盖）。
class FakeItemsNotifier extends ItemsNotifier {
  FakeItemsNotifier([List<Item>? seed]) : _items = [...?seed];

  final List<Item> _items;
  var _nextId = 1;

  @override
  Future<List<Item>> build() async => List.unmodifiable(_items);

  List<Item> get live =>
      _items.where((e) => e.deletedAt == null).toList(growable: false);

  @override
  Future<void> addItem(ItemDraft draft) async {
    final now = DateTime.now();
    _items.add(
      Item(
        id: _nextId++,
        name: draft.name,
        price: draft.price,
        residual: draft.residual,
        category: draft.category,
        purchaseDate: draft.purchaseDate,
        endDate: draft.endDate,
        usageDays: draft.usageDays,
        totalUses: draft.totalUses,
        usesPerDay: draft.usesPerDay,
        totalHours: draft.totalHours,
        hoursPerDay: draft.hoursPerDay,
        cycleUnit: draft.cycleUnit,
        cycleLength: draft.cycleLength,
        calcMode: draft.calcMode,
        depreciation: draft.depreciation,
        note: draft.note,
        tags: draft.tags,
        createdAt: now,
        updatedAt: now,
      ),
    );
    state = AsyncData(live);
  }

  @override
  Future<void> updateItem(Item item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) _items[i] = item;
    state = AsyncData(live);
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(deletedAt: DateTime.now());
    }
    state = AsyncData(live);
  }

  @override
  Future<void> restore(int id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(deletedAt: null);
    state = AsyncData(live);
  }
}
