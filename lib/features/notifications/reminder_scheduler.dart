/// 提醒调度：按当前物品与设置全量重排（幂等）。
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import 'notification_service.dart';

/// 各类提醒的开关与数据来源。
class ReminderRequest {
  const ReminderRequest({
    required this.items,
    required this.today,
    required this.notifyExpiry,
    required this.notifyRenewal,
    required this.notifyWeekly,
    required this.notifyBackup,
  });

  final List<Item> items;
  final DateTime today;
  final bool notifyExpiry;
  final bool notifyRenewal;
  final bool notifyWeekly;
  final bool notifyBackup;
}

class ReminderScheduler {
  ReminderScheduler(this._service);

  final NotificationService _service;

  /// 取消全部后按当前状态重建提醒。
  Future<void> rescheduleAll(ReminderRequest request) async {
    await _service.init();
    await _service.cancelAll();
    var id = 1;

    if (request.notifyExpiry) {
      for (final item in request.items) {
        if (item.calcMode != CalcMode.endDate || item.endDate == null) continue;
        final end = dateOnly(item.endDate!);
        // 到期前 3 天提示
        final warning = end.subtract(const Duration(days: 3));
        if (warning.isAfter(request.today)) {
          await _service.schedule(
            id: id++,
            title: '「${item.name}」快到期了',
            body: '将于 ${end.month}月${end.day}日到期，看看值不值得续',
            at: const TimeOfDayAt(9).on(warning),
          );
        }
      }
    }

    if (request.notifyRenewal) {
      for (final item in request.items) {
        if (item.calcMode != CalcMode.subscription) continue;
        final cycleDays = (item.cycleLength ?? 1) *
            switch (item.cycleUnit ?? CycleUnit.monthly) {
              CycleUnit.weekly => 7,
              CycleUnit.monthly => 30,
              CycleUnit.yearly => 365,
            };
        // 下一个续费日：购买日起每 cycleDays 一次，提前 2 天提醒
        var next = dateOnly(item.purchaseDate);
        final today = request.today;
        while (!next.isAfter(today)) {
          next = next.add(Duration(days: cycleDays));
        }
        final remind = next.subtract(const Duration(days: 2));
        if (remind.isAfter(today)) {
          await _service.schedule(
            id: id++,
            title: '「${item.name}」即将续费',
            body: '${next.month}月${next.day}日续费，记得确认还要不要续',
            at: const TimeOfDayAt(9).on(remind),
          );
        }
      }
    }

    if (request.notifyWeekly) {
      await _service.schedule(
        id: id++,
        title: '本周花费小结',
        body: '打开「DailyCost」看看这周的钱都花到哪了',
        at: _nextWeekday9(DateTime.now()),
        repeat: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    if (request.notifyBackup) {
      await _service.schedule(
        id: id++,
        title: '数据备份提醒',
        body: '定期导出备份，防止换机或误删时数据丢失',
        at: _nextMonthFirst10(DateTime.now()),
        repeat: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// 下一个周一 9:00（今天是周一且已过 9 点则下周）。
  static DateTime _nextWeekday9(DateTime now) {
    var d = dateOnly(now);
    while (d.weekday != DateTime.monday ||
        !d.add(const Duration(hours: 9)).isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 9));
  }

  /// 下个月 1 日 10:00。
  static DateTime _nextMonthFirst10(DateTime now) {
    var d = DateTime(now.year, now.month + 1, 1, 10);
    if (!d.isAfter(now)) d = DateTime(now.year, now.month + 2, 1, 10);
    return d;
  }
}

/// 「某天 HH:MM」小工具（当前固定 9:00）。
class TimeOfDayAt {
  const TimeOfDayAt(this.hour);

  final int hour;

  DateTime on(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour);
}
