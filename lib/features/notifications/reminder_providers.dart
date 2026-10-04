import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'reminder_scheduler.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(ref.watch(notificationServiceProvider)),
);
