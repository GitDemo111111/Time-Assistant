import 'package:meta/meta.dart';

import '../models/birthday.dart';
import '../models/contact.dart';
import 'birthday_calculator.dart';
import 'date_x.dart';
import 'festivals.dart';
import 'holidays.dart';
import 'lunar_converter.dart';

/// 提醒的种类。
enum ReminderKind {
  /// 生日前的提前提醒（默认提前 3 天）。
  advance('提前提醒'),

  /// 生日当天的提醒。
  onDay('当天提醒'),

  /// 节日当天的提醒。
  festival('节日提醒'),

  /// 假期开始 / 结束、调休上班的提醒。
  holiday('假期提醒');

  const ReminderKind(this.label);

  final String label;
}

/// 一条待调度的本地通知。
@immutable
class PendingReminder {
  const PendingReminder({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.kind,
    required this.scheduledAt,
    required this.occurrenceDate,
    required this.title,
    required this.body,
    this.payloadOverride,
  });

  /// 通知 id，必须是 32 位有符号整数。
  final int id;
  final String contactId;
  final String contactName;
  final ReminderKind kind;

  /// 实际触发时间。
  final DateTime scheduledAt;

  /// 对应的日期（生日 / 节日 / 假期）。
  final DateTime occurrenceDate;

  final String title;
  final String body;

  /// 点击通知后要打开的对象；不填就用 [contactId]。
  final String? payloadOverride;

  /// 点击通知后要打开的联系人 / 事件。
  String get payload => payloadOverride ?? contactId;

  /// 这条提醒是不是生日相关（用来区分是否需要跳转到联系人）。
  bool get isContactReminder =>
      kind == ReminderKind.advance || kind == ReminderKind.onDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PendingReminder && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PendingReminder($id, $contactName, ${kind.name}, $scheduledAt)';
}

/// 32 位 FNV-1a，取低 28 位；同一个 id 每次都得到同样的结果。
int _stableHash28(String key) {
  int hash = 2166136261;
  for (final int unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash & 0x0FFFFFFF;
}

/// 每个 key 预留 16 个槽位，所以参与相乘的哈希只取 24 位，
/// 结果最大约 2.68 亿，稳稳落在正的 32 位整数里。
const int _slotsPerKey = 16;

/// 每种提醒占用的槽位起始值（同一个 key 内互不重叠）。
int _slotBase(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.advance:
      return 0; // 0,1
    case ReminderKind.onDay:
      return 2; // 2,3
    case ReminderKind.festival:
      return 4; // 4,5
    case ReminderKind.holiday:
      return 6; // 6..15（放假前一天 / 最后一天 / 多个调休上班日）
  }
}

/// 通知 id 的生成规则：24 位基址 × 16 + 槽位，保证是正的 32 位整数。
///
/// 之所以要「稳定」，是因为新增/删除联系人后需要能精确取消旧通知。
///
/// 注意：槽位**不能**用 `occurrenceIndex * ReminderKind.values.length % 4` 来算 ——
/// [ReminderKind] 一旦有 4 个元素，第二年的生日提醒就会和第一年撞同一个 id
/// （互相覆盖）。所以这里改成固定的槽位表。
int notificationIdFor(
  String contactId,
  ReminderKind kind,
  int occurrenceIndex,
) {
  final int base = _stableHash28(contactId) & 0x00FFFFFF;
  final int index = occurrenceIndex < 0 ? 0 : occurrenceIndex;
  return base * _slotsPerKey + _slotBase(kind) + index;
}

/// 把「联系人 / 节日 / 假期 + 当前时间」换算成一组待调度的通知。
///
/// 这是一个纯函数：同样的输入永远得到同样的输出，方便单测。
class ReminderPlanner {
  const ReminderPlanner({
    this.calculator = const BirthdayCalculator(),
    this.occurrencesAhead = 2,
    this.immediateLead = const Duration(minutes: 1),
    this.festivalWindowDays = 120,
    this.lunar = const LunarPackageConverter(),
  });

  final BirthdayCalculator calculator;

  /// 为每位联系人预先排多少次生日（覆盖今年和明年，避免长期不打开 App 就漏提醒）。
  final int occurrencesAhead;

  /// 提前提醒的日期已经过去、但生日还没到时，延迟多久立刻提醒。
  final Duration immediateLead;

  /// 节日 / 假期提醒只排未来这么多天内的，避免一次性排上百条通知。
  final int festivalWindowDays;

  final LunarConverter lunar;

  /// 生成所有待调度提醒，按触发时间升序排序。
  List<PendingReminder> plan({
    required List<Contact> contacts,
    required DateTime now,
    bool festivalReminders = false,
    bool holidayReminders = false,
    int? reminderHour,
    int? reminderMinute,
  }) {
    final List<PendingReminder> result = <PendingReminder>[];
    final DateTime today = dateOnly(now);
    final int ahead = occurrencesAhead.clamp(1, 2).toInt();

    for (final Contact contact in contacts) {
      final Birthday? birthday = contact.birthday;
      if (birthday == null) continue;

      final ReminderSettings reminder = contact.reminder;
      if (!reminder.enabled) continue;
      if (reminder.daysBefore <= 0 && !reminder.notifyOnDay) continue;

      final List<BirthdayOccurrence> occurrences = calculator.nextOccurrences(
        birthday,
        today,
        ahead,
      );

      for (int index = 0; index < occurrences.length; index++) {
        final BirthdayOccurrence occurrence = occurrences[index];
        final int daysUntil = daysBetween(today, occurrence.date);
        final int? turningAge = calculator.ageAt(birthday, occurrence);

        // 提前 N 天的提醒
        if (reminder.daysBefore > 0 && daysUntil > 0) {
          final DateTime advanceDay = DateTime(
            occurrence.date.year,
            occurrence.date.month,
            occurrence.date.day - reminder.daysBefore,
          );
          final DateTime planned = DateTime(
            advanceDay.year,
            advanceDay.month,
            advanceDay.day,
            reminder.hour,
            reminder.minute,
          );
          // 提前提醒的时间点已经过去（例如刚添加联系人时生日只剩 1 天），
          // 就立刻提醒一次，而不是默默错过。
          final DateTime scheduledAt = planned.isAfter(now)
              ? planned
              : now.add(immediateLead);
          result.add(
            PendingReminder(
              id: notificationIdFor(contact.id, ReminderKind.advance, index),
              contactId: contact.id,
              contactName: contact.name,
              kind: ReminderKind.advance,
              scheduledAt: scheduledAt,
              occurrenceDate: occurrence.date,
              title: '🎂 ${contact.name}的生日快到了',
              body: _advanceBody(contact.name, daysUntil, turningAge),
            ),
          );
        }

        // 当天提醒
        if (reminder.notifyOnDay) {
          final DateTime onDay = DateTime(
            occurrence.date.year,
            occurrence.date.month,
            occurrence.date.day,
            reminder.hour,
            reminder.minute,
          );
          if (onDay.isAfter(now)) {
            result.add(
              PendingReminder(
                id: notificationIdFor(contact.id, ReminderKind.onDay, index),
                contactId: contact.id,
                contactName: contact.name,
                kind: ReminderKind.onDay,
                scheduledAt: onDay,
                occurrenceDate: occurrence.date,
                title: '🎉 今天是${contact.name}的生日',
                body: _onDayBody(contact.name, turningAge),
              ),
            );
          }
        }
      }
    }

    final int hour = reminderHour ?? 9;
    final int minute = reminderMinute ?? 0;

    if (festivalReminders) {
      result.addAll(_planFestivals(now, today, hour, minute));
    }
    if (holidayReminders) {
      result.addAll(_planHolidays(now, today, hour, minute));
    }

    result.sort((PendingReminder a, PendingReminder b) {
      final int byTime = a.scheduledAt.compareTo(b.scheduledAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return result;
  }

  // ------------------------------------------------------------ 节日

  List<PendingReminder> _planFestivals(
    DateTime now,
    DateTime today,
    int hour,
    int minute,
  ) {
    final List<FestivalOccurrence> occurrences = upcomingFestivals(
      today,
      limit: 40,
      lunar: lunar,
    );
    final List<PendingReminder> result = <PendingReminder>[];
    for (int index = 0; index < occurrences.length; index++) {
      final FestivalOccurrence festival = occurrences[index];
      if (festival.daysUntil > festivalWindowDays) break;
      final DateTime at = DateTime(
        festival.date.year,
        festival.date.month,
        festival.date.day,
        hour,
        minute,
      );
      if (!at.isAfter(now)) continue;
      result.add(
        PendingReminder(
          id: notificationIdFor(
            'festival:${festival.festival.id}',
            ReminderKind.festival,
            0,
          ),
          contactId: '',
          contactName: festival.festival.name,
          kind: ReminderKind.festival,
          scheduledAt: at,
          occurrenceDate: festival.date,
          title: '${festival.festival.emoji} 今天是${festival.festival.name}',
          body: festival.festival.hint ?? '别忘了这个日子～',
          payloadOverride: 'festival:${festival.festival.id}',
        ),
      );
    }
    return result;
  }

  // ------------------------------------------------------------ 假期

  List<PendingReminder> _planHolidays(
    DateTime now,
    DateTime today,
    int hour,
    int minute,
  ) {
    final List<PendingReminder> result = <PendingReminder>[];
    final List<HolidayCountdown> holidays = upcomingHolidays(
      today,
      limit: 12,
      lunar: lunar,
    );
    for (final HolidayCountdown item in holidays) {
      final Holiday holiday = item.holiday;
      if (item.daysUntilStart > festivalWindowDays) break;

      // 放假前一天：提醒「明天开始放假」
      final DateTime eve = holiday.start.subtract(const Duration(days: 1));
      final DateTime eveAt = DateTime(
        eve.year,
        eve.month,
        eve.day,
        hour,
        minute,
      );
      if (eveAt.isAfter(now)) {
        result.add(
          PendingReminder(
            id: notificationIdFor(
              'holiday-eve:${holiday.id}',
              ReminderKind.holiday,
              0,
            ),
            contactId: '',
            contactName: holiday.name,
            kind: ReminderKind.holiday,
            scheduledAt: eveAt,
            occurrenceDate: holiday.start,
            title: '${holiday.emoji} 明天开始放假：${holiday.name}',
            body: '${holiday.rangeLabel}，共 ${holiday.days} 天',
            payloadOverride: 'holiday:${holiday.id}',
          ),
        );
      }

      // 假期最后一天：提醒「明天上班」
      final DateTime lastAt = DateTime(
        holiday.end.year,
        holiday.end.month,
        holiday.end.day,
        hour,
        minute,
      );
      if (lastAt.isAfter(now)) {
        result.add(
          PendingReminder(
            id: notificationIdFor(
              'holiday-last:${holiday.id}',
              ReminderKind.holiday,
              1,
            ),
            contactId: '',
            contactName: holiday.name,
            kind: ReminderKind.holiday,
            scheduledAt: lastAt,
            occurrenceDate: holiday.end,
            title: '${holiday.emoji} ${holiday.name}假期最后一天',
            body: '明天就要上班了，收收心～',
            payloadOverride: 'holiday:${holiday.id}',
          ),
        );
      }

      // 调休上班日：当天早上提醒
      for (int i = 0; i < holiday.workdays.length; i++) {
        final DateTime workday = holiday.workdays[i];
        final DateTime workAt = DateTime(
          workday.year,
          workday.month,
          workday.day,
          8,
          0,
        );
        if (!workAt.isAfter(now)) continue;
        if (daysBetween(today, workday) > festivalWindowDays) continue;
        result.add(
          PendingReminder(
            id: notificationIdFor(
              'holiday-work:${holiday.id}:$i',
              ReminderKind.holiday,
              2 + i,
            ),
            contactId: '',
            contactName: holiday.name,
            kind: ReminderKind.holiday,
            scheduledAt: workAt,
            occurrenceDate: workday,
            title: '⏰ 今天调休上班',
            body: '为了${holiday.name}的假期，今天要上班',
            payloadOverride: 'holiday:${holiday.id}',
          ),
        );
      }
    }
    return result;
  }

  String _advanceBody(String name, int daysUntil, int? turningAge) {
    final StringBuffer buffer = StringBuffer('还有 $daysUntil 天是$name的生日');
    if (turningAge != null) buffer.write('（将满 $turningAge 岁）');
    buffer.write('，记得准备祝福或礼物～');
    return buffer.toString();
  }

  String _onDayBody(String name, int? turningAge) {
    final StringBuffer buffer = StringBuffer('别忘了送上生日祝福');
    if (turningAge != null) {
      buffer.write('，$name今天就满 $turningAge 岁啦');
    }
    buffer.write('！');
    return buffer.toString();
  }
}
