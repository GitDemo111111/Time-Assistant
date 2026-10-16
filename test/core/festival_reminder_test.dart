import 'package:birthday_keeper/core/reminder_planner.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';

/// 节日 / 假期提醒的排期规则。
void main() {
  const ReminderPlanner planner = ReminderPlanner();

  Contact withBirthday(String id, String name, int month, int day) => Contact(
    id: id,
    name: name,
    birthday: Birthday(month: month, day: day),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('节日提醒', () {
    test('默认不开：不传开关时没有任何节日提醒', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 5, 20, 10),
      );
      expect(list, isEmpty);
    });

    test('开会后：端午节当天有提醒', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 5, 20, 10),
        festivalReminders: true,
      );
      final PendingReminder dragonBoat = list.firstWhere(
        (PendingReminder r) => r.contactName == '端午节',
      );
      expect(dragonBoat.kind, ReminderKind.festival);
      expect(dragonBoat.scheduledAt, DateTime(2026, 6, 19, 9, 0));
      expect(dragonBoat.title, contains('端午节'));
      expect(dragonBoat.payload, 'festival:dragon_boat');
      expect(dragonBoat.isContactReminder, isFalse);
    });

    test('提醒时间跟随默认提醒设置', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 5, 20, 10),
        festivalReminders: true,
        reminderHour: 20,
        reminderMinute: 30,
      );
      final PendingReminder dragonBoat = list.firstWhere(
        (PendingReminder r) => r.contactName == '端午节',
      );
      expect(dragonBoat.scheduledAt, DateTime(2026, 6, 19, 20, 30));
    });

    test('只排窗口内的（默认 120 天）', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 5, 20, 10),
        festivalReminders: true,
      );
      for (final PendingReminder r in list) {
        expect(
          r.scheduledAt.difference(DateTime(2026, 5, 20)).inDays,
          lessThanOrEqualTo(121),
          reason: '${r.contactName} 排得太远了',
        );
      }
    });
  });

  group('假期提醒', () {
    test('国庆：放假前一天、最后一天、调休上班日都有', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 9, 1, 10),
        holidayReminders: true,
      );
      final List<PendingReminder> holidays = list
          .where((PendingReminder r) => r.kind == ReminderKind.holiday)
          .toList();

      final PendingReminder eve = holidays.firstWhere(
        (PendingReminder r) =>
            r.title.contains('明天开始放假') && r.title.contains('国庆节'),
      );
      expect(eve.scheduledAt, DateTime(2026, 9, 30, 9, 0));
      expect(eve.body, contains('共 7 天'));
      expect(eve.payload, 'holiday:2026_national_day');

      final PendingReminder last = holidays.firstWhere(
        (PendingReminder r) =>
            r.title.contains('假期最后一天') && r.title.contains('国庆节'),
      );
      expect(last.scheduledAt, DateTime(2026, 10, 7, 9, 0));

      final PendingReminder work = holidays.firstWhere(
        (PendingReminder r) => r.title.contains('今天调休上班'),
      );
      expect(work.scheduledAt, DateTime(2026, 9, 20, 8, 0));
      expect(work.body, contains('国庆节'));
    });

    test('2026-10-10 这个调休上班日也在计划里（当天早上 8 点）', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 9, 1, 10),
        holidayReminders: true,
      );
      final PendingReminder work = list.firstWhere(
        (PendingReminder r) => r.scheduledAt == DateTime(2026, 10, 10, 8, 0),
      );
      expect(work.title, contains('调休上班'));
    });

    test('已经过去的假期不再排', () {
      final List<PendingReminder> list = planner.plan(
        contacts: const <Contact>[],
        now: DateTime(2026, 10, 10, 12),
        holidayReminders: true,
      );
      expect(
        list.any(
          (PendingReminder r) =>
              r.title.contains('国庆节') && r.title.contains('明天开始放假'),
        ),
        isFalse,
      );
    });
  });

  group('和生日提醒一起用时', () {
    test('通知 id 必须唯一（否则会互相覆盖）', () {
      final List<PendingReminder> list = planner.plan(
        contacts: <Contact>[
          withBirthday('a', '张三', 6, 1),
          withBirthday('b', '李四', 10, 3),
        ],
        now: DateTime(2026, 5, 20, 10),
        festivalReminders: true,
        holidayReminders: true,
      );
      expect(list, isNotEmpty);
      final Set<int> ids = list.map((PendingReminder r) => r.id).toSet();
      expect(ids, hasLength(list.length), reason: '有重复的通知 id');
      expect(list.every((PendingReminder r) => r.id > 0), isTrue);
    });

    test('整体按触发时间升序', () {
      final List<PendingReminder> list = planner.plan(
        contacts: <Contact>[withBirthday('a', '张三', 6, 1)],
        now: DateTime(2026, 5, 20, 10),
        festivalReminders: true,
        holidayReminders: true,
      );
      for (int i = 1; i < list.length; i++) {
        expect(
          list[i].scheduledAt.isBefore(list[i - 1].scheduledAt),
          isFalse,
          reason: '第 $i 条乱序了',
        );
      }
    });

    test('总开关关闭时由 controller 决定不排（planner 本身只看入参）', () {
      // planner 是纯函数：两个开关都为 false 时只有生日提醒
      final List<PendingReminder> list = planner.plan(
        contacts: <Contact>[withBirthday('a', '张三', 6, 1)],
        now: DateTime(2026, 5, 20, 10),
      );
      expect(list.every((PendingReminder r) => r.isContactReminder), isTrue);
    });
  });
}
