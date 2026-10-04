import 'calc_inputs.dart';
import 'enums.dart';

/// 一条消费记录。金额单位为元；日期仅含年月日（时间戳除外）。
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.price,
    required this.residual,
    required this.category,
    required this.purchaseDate,
    this.endDate,
    this.usageDays,
    this.totalUses,
    this.usesPerDay,
    this.totalHours,
    this.hoursPerDay,
    this.cycleUnit,
    this.cycleLength,
    required this.calcMode,
    required this.depreciation,
    required this.note,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String name;
  final double price;
  final double residual;
  final String category;
  final DateTime purchaseDate;
  final DateTime? endDate;
  final int? usageDays;
  final int? totalUses;
  final double? usesPerDay;
  final int? totalHours;
  final double? hoursPerDay;
  final CycleUnit? cycleUnit;
  final int? cycleLength;
  final CalcMode calcMode;
  final DepreciationMethod depreciation;
  final String note;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 软删除时间；null = 有效
  final DateTime? deletedAt;

  /// copyWith 可空字段哨兵：区分「未传」与「显式传 null」。
  static const Object _unset = Object();

  CalcInputs toCalcInputs() => CalcInputs(
    price: price,
    residual: residual,
    mode: calcMode,
    depreciation: depreciation,
    purchaseDate: purchaseDate,
    endDate: endDate,
    usageDays: usageDays,
    totalUses: totalUses,
    usesPerDay: usesPerDay,
    totalHours: totalHours,
    hoursPerDay: hoursPerDay,
    cycleUnit: cycleUnit,
    cycleLength: cycleLength,
  );

  Item copyWith({
    int? id,
    String? name,
    double? price,
    double? residual,
    String? category,
    DateTime? purchaseDate,
    Object? endDate = _unset,
    int? usageDays,
    int? totalUses,
    double? usesPerDay,
    int? totalHours,
    double? hoursPerDay,
    Object? cycleUnit = _unset,
    int? cycleLength,
    CalcMode? calcMode,
    DepreciationMethod? depreciation,
    String? note,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) => Item(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    residual: residual ?? this.residual,
    category: category ?? this.category,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
    usageDays: usageDays ?? this.usageDays,
    totalUses: totalUses ?? this.totalUses,
    usesPerDay: usesPerDay ?? this.usesPerDay,
    totalHours: totalHours ?? this.totalHours,
    hoursPerDay: hoursPerDay ?? this.hoursPerDay,
    cycleUnit: identical(cycleUnit, _unset)
        ? this.cycleUnit
        : cycleUnit as CycleUnit?,
    cycleLength: cycleLength ?? this.cycleLength,
    calcMode: calcMode ?? this.calcMode,
    depreciation: depreciation ?? this.depreciation,
    note: note ?? this.note,
    tags: tags ?? this.tags,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
  );
}

/// 新建记录的草稿（尚无 id/时间戳/软删除标记）。
class ItemDraft {
  const ItemDraft({
    required this.name,
    required this.price,
    required this.residual,
    required this.category,
    required this.purchaseDate,
    this.endDate,
    this.usageDays,
    this.totalUses,
    this.usesPerDay,
    this.totalHours,
    this.hoursPerDay,
    this.cycleUnit,
    this.cycleLength,
    required this.calcMode,
    required this.depreciation,
    required this.note,
    required this.tags,
  });

  final String name;
  final double price;
  final double residual;
  final String category;
  final DateTime purchaseDate;
  final DateTime? endDate;
  final int? usageDays;
  final int? totalUses;
  final double? usesPerDay;
  final int? totalHours;
  final double? hoursPerDay;
  final CycleUnit? cycleUnit;
  final int? cycleLength;
  final CalcMode calcMode;
  final DepreciationMethod depreciation;
  final String note;
  final List<String> tags;

  CalcInputs toCalcInputs() => CalcInputs(
    price: price,
    residual: residual,
    mode: calcMode,
    depreciation: depreciation,
    purchaseDate: purchaseDate,
    endDate: endDate,
    usageDays: usageDays,
    totalUses: totalUses,
    usesPerDay: usesPerDay,
    totalHours: totalHours,
    hoursPerDay: hoursPerDay,
    cycleUnit: cycleUnit,
    cycleLength: cycleLength,
  );
}
