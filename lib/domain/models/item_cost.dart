/// 物品的 TCO 附加成本（维护/能耗/保险/配件/其他）。金额单位为元。
class ItemCost {
  const ItemCost({
    required this.id,
    required this.itemId,
    required this.category,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int itemId;
  final String category;
  final double amount;
  final String note;
  final DateTime createdAt;
}

/// 新增附加成本的草稿。
class ItemCostDraft {
  const ItemCostDraft({
    required this.category,
    required this.amount,
    this.note = '',
  });

  final String category;
  final double amount;
  final String note;
}
