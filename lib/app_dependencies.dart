import 'dart:async';

import 'services/reminder_scheduler.dart';
import 'state/contact_controller.dart';
import 'state/settings_controller.dart';

/// 组装应用的各个部件（仓储、调度器、控制器）。
class AppDependencies {
  AppDependencies({
    required this.settingsController,
    required this.contactController,
    this.scheduler,
  });

  final SettingsController settingsController;
  final ContactController contactController;
  final ReminderScheduler? scheduler;

  /// 启动时的初始化：通知通道 + 读取本地数据 + 排程提醒。
  Future<void> start() async {
    try {
      await scheduler?.initialize();
    } on Object {
      // 通知初始化失败不应该阻塞 App 启动。
    }
    await settingsController.load();
    await contactController.load();
    // 提醒是这个 App 的核心功能：总开关开着、但还没拿到通知权限时主动请求一次。
    // （Android 13+ 只会弹两次，被永久拒绝后这里会静默返回 false。）
    if (settingsController.settings.notificationsEnabled) {
      unawaited(contactController.requestNotificationPermission());
    }
  }
}
