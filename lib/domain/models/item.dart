import 'calc_inputs.dart';
import 'enums.dart';
import 'item_cost.dart';

/// 一条消费记录。金额单位为「记录自身货币」的元；日期仅含年月日（时间戳除外）。
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.price,
    required this.residual,
    required this.category,
    required this.purchaseDate,
    this.currency = 'CNY',
    this.aprPercent,
    this.installmentMonths,
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
    this.photos = const [],
    this.extraCosts = const [],
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

  /// 币种（ISO 代码）
  final String currency;

  /// 分期年利率（%）；与 [installmentMonths] 同时生效
  final double? aprPercent;

  /// 分期期数（月）
  final int? installmentMonths;

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

  /// 照片（应用私有目录下的文件路径）
  final List<String> photos;

  /// TCO 附加成本
  final List<ItemCost> extraCosts;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 软删除时间；null = 有效
  final DateTime? deletedAt;

  /// TCO 附加成本合计
  double get extraCostsTotal =>
      extraCosts.fold(0.0, (sum, c) => sum + c.amount);

  /// TCO 总拥有成本（未含分期利息）
  double get tcoTotal => price + extraCostsTotal;

  /// 传入该币种→人民币汇率 [fxRate] 后折算成人民币计算输入。
  CalcInputs toCalcInputs({double fxRate = 1.0}) => CalcInputs(
    price: price * fxRate,
    residual: residual * fxRate,
    tcoExtra: extraCostsTotal * fxRate,
    aprPercent: aprPercent,
    installmentMonths: installmentMonths,
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

  /// copyWith 可空字段哨兵：区分「未传」与「显式传 null」。
  static const Object _unset = Object();

  Item copyWith({
    int? id,
    String? name,
    double? price,
    double? residual,
    String? category,
    DateTime? purchaseDate,
    String? currency,
    Object? aprPercent = _unset,
    Object? installmentMonths = _unset,
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
    List<String>? photos,
    List<ItemCost>? extraCosts,
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
    currency: currency ?? this.currency,
    aprPercent: identical(aprPercent, _unset)
        ? this.aprPercent
        : aprPercent as double?,
    installmentMonths: identical(installmentMonths, _unset)
        ? this.installmentMonths
        : installmentMonths as int?,
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
    photos: photos ?? this.photos,
    extraCosts: extraCosts ?? this.extraCosts,
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
    this.currency = 'CNY',
    this.aprPercent,
    this.installmentMonths,
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
    this.photos = const [],
    this.extraCosts = const [],
  });

  final String name;
  final double price;
  final double residual;
  final String category;
  final DateTime purchaseDate;
  final String currency;
  final double? aprPercent;
  final int? installmentMonths;
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
  final List<String> photos;
  final List<ItemCostDraft> extraCosts;

  double get extraCostsTotal =>
      extraCosts.fold(0.0, (sum, c) => sum + c.amount);

  CalcInputs toCalcInputs({double fxRate = 1.0}) => CalcInputs(
    price: price * fxRate,
    residual: residual * fxRate,
    tcoExtra: extraCostsTotal * fxRate,
    aprPercent: aprPercent,
    installmentMonths: installmentMonths,
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
