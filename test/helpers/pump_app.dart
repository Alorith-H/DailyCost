import 'package:daily_cost/app.dart';
import 'package:daily_cost/features/home/application/home_providers.dart';
import 'package:daily_cost/features/settings/application/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_items.dart';

/// 挂载整个 App（内存假数据，不碰 sqlite3）。
///
/// sqlite3 的 native assets 加载依赖真实事件循环，在 testWidgets 的
/// FakeAsync 下会挂死；真实 DB 接线由 test/data/items_provider_test.dart
/// 与 settings_providers_test.dart 用普通 test() 覆盖。
Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(FakeItemsNotifier.new),
        settingsProvider.overrideWith(() => SettingsNotifier()),
      ],
      child: const DailyCostApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(DailyCostApp)));
}
