import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import 'db/app_database.dart';
import 'repositories/budget_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/settings_repository.dart';

/// 数据库接缝：main() 与测试各自覆写。
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider 必须在 main() 或测试中覆写'),
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ItemRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(databaseProvider)),
);

/// 「今天」（仅日期）。回前台/跨零点时通过 ref.invalidate 重算。
final todayProvider = Provider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);
