/// 本地通知（flutter_local_notifications）：全部离线，系统通知栏展示。
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 通知服务。仅使用系统本地通知，不涉及任何网络。
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'dailycost_reminders',
    '消费提醒',
    channelDescription: '到期 / 续费 / 周报 / 备份等本地提醒',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// 初始化（幂等）。请求 Android 13+ 通知运行时权限。
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// 安排一条提醒。[repeat] 按周期重复（如每周一/每月 1 日）。
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    DateTimeComponents? repeat,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: repeat,
    );
  }
}
