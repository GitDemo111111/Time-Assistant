import '../core/reminder_planner.dart';

/// 提醒调度能力的抽象。
///
/// 真实实现走系统本地通知；测试里注入 [NoopReminderScheduler]，
/// 这样 Widget 测试和集成测试都不会碰到平台通道。
abstract class ReminderScheduler {
  /// 初始化底层能力（时区、通知通道等）。
  Future<void> initialize();

  /// 请求通知权限，返回是否已获得。
  Future<bool> requestPermission();

  /// 用一批提醒覆盖当前的调度结果（内部会先全部取消再重新排）。
  Future<void> apply(List<PendingReminder> reminders);

  /// 取消所有已排程的提醒。
  Future<void> cancelAll();

  /// 当前系统里已排程的通知 id。
  Future<List<int>> pendingIds();

  /// 最近一次排程失败的原因；成功时为 `null`。
  ///
  /// 实现里**不要**把异常抛给调用方（数据保存优先），
  /// 但一定要把失败原因记在这里 —— 否则界面会「谎报已排好提醒」。
  String? get lastError => null;
}

/// 不做任何真实调度，只在内存里记录。
///
/// 用于测试，也可以作为「通知总开关关闭」时的降级实现。
class NoopReminderScheduler implements ReminderScheduler {
  NoopReminderScheduler({
    this.permissionGranted = true,
    this.failOnApply = false,
  });

  /// [requestPermission] 的返回值。
  bool permissionGranted;

  /// 让 [apply] 抛异常，用来验证「通知排程失败不能影响联系人数据」。
  bool failOnApply;

  /// 最近一次 [apply] 收到的提醒。
  List<PendingReminder> applied = <PendingReminder>[];

  int applyCount = 0;
  int cancelCount = 0;

  /// 最近一次失败原因（[failOnApply] 或 [failOnApplyWith] 时会有值）。
  String? _lastError;

  @override
  String? get lastError => _lastError;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> apply(List<PendingReminder> reminders) async {
    applyCount++;
    if (failOnApply) {
      _lastError = '排程失败（测试用）';
      throw StateError(_lastError!);
    }
    _lastError = null;
    applied = List<PendingReminder>.of(reminders);
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    applied = <PendingReminder>[];
  }

  @override
  Future<List<int>> pendingIds() async =>
      applied.map((PendingReminder e) => e.id).toList();
}
