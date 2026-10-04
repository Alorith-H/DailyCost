import 'package:daily_cost/app.dart';
import 'package:daily_cost/core/utils/app_version.dart';
import 'package:daily_cost/features/home/application/home_providers.dart';
import 'package:daily_cost/features/notifications/notification_service.dart';
import 'package:daily_cost/features/notifications/reminder_providers.dart';
import 'package:daily_cost/features/settings/application/settings_providers.dart';
import 'package:daily_cost/features/update/application/update_providers.dart';
import 'package:daily_cost/features/update/application/update_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_items.dart';

/// 假更新服务：无网络、无平台通道，恒为「已是最新」。
class FakeUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> checkForUpdate({
    required String currentVersion,
    required List<String> supportedAbis,
  }) async => null;

  @override
  Future<String> download(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> install(String apkPath) async =>
      throw UnimplementedError();
}

/// 假通知服务：不碰平台通道。
class FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    DateTimeComponents? repeat,
  }) async {}
}

/// 挂载整个 App（内存假数据，不碰 sqlite3 / 平台通道）。
///
/// 真实 DB 接线由 test/data/* 用普通 test() 覆盖；
/// 平台通道（device_info 等）在 testWidgets 的 FakeAsync 下会挂死。
Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemsProvider.overrideWith(FakeItemsNotifier.new),
        settingsProvider.overrideWith(() => SettingsNotifier()),
        updateServiceProvider.overrideWith((ref) => FakeUpdateService()),
        supportedAbisProvider.overrideWith((ref) async => const ['arm64-v8a']),
        appVersionProvider.overrideWith((ref) async => '0.2.0'),
        notificationServiceProvider.overrideWith(
          (ref) => FakeNotificationService(),
        ),
      ],
      child: const DailyCostApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(DailyCostApp)));
}
