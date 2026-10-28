import 'package:birthday_keeper/core/birthday_calculator.dart';
import 'package:birthday_keeper/core/contact_text_parser.dart';
import 'package:birthday_keeper/core/reminder_planner.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用户的真实数据：全部按**农历**导入。
///
/// 这里钉死一件事：农历生日必须按**换算后的公历日期**提醒，
/// 绝不能拿农历的「月/日」当成新历的「月/日」（用户报过的 bug）。
const String kRealData = '''
姓名: 秦文芳
生日: 1972-09-18

姓名: 陈光华
生日: 1969-09-25

姓名: 陈光兰
生日: 年份不详-10-29

姓名: 二姐
生日: 年份不详-农历02-20

姓名: 大姐
生日: 年份不详-农历03-17（新历04-28）

姓名: 陈光书
生日: 年份不详-农历04-03

姓名: 七靓鹅公
生日: 年份不详-农历12-22

姓名: 陈大荣
生日: 1949-06-29

姓名: 赵书研
生日: 年份不详-农历05-10

姓名: 胡连福
生日: 1949-04-09

姓名: 陈大容
生日: 1949-06-29
''';

void main() {
  List<Contact> parseAll() {
    const ContactTextParser parser = ContactTextParser();
    final List<Contact> contacts = <Contact>[];
    int i = 0;
    for (final ParsedContact parsed in parser.parse(kRealData)) {
      if (!parsed.isValid) continue;
      contacts.add(
        parsed.toContact(id: 'c${i++}', now: DateTime(2026, 10, 16)),
      );
    }
    return contacts;
  }

  PendingReminder reminderOf(
    List<PendingReminder> list,
    String name,
    ReminderKind kind,
  ) => list.firstWhere(
    (PendingReminder r) => r.contactName == name && r.kind == kind,
  );

  group('导入后必须是农历', () {
    test('11 位全部解析为农历', () {
      final List<Contact> contacts = parseAll();
      expect(contacts, hasLength(11));
      for (final Contact c in contacts) {
        expect(
          c.birthday!.isLunar,
          isTrue,
          reason: '${c.name} 应该是农历，实际 ${c.birthday!.displayLabel}',
        );
      }
    });

    test('文本里写明「新历」的行以文本为准（大姐那行是农历）', () {
      final List<Contact> contacts = parseAll();
      final Contact dajie = contacts.firstWhere((Contact c) => c.name == '大姐');
      expect(dajie.birthday!.isLunar, isTrue);
      expect(dajie.birthday!.month, 3);
      expect(dajie.birthday!.day, 17);
    });
  });

  group('提醒必须落在「农历换算后的公历日」，而不是农历月日当成新历', () {
    late List<PendingReminder> plan;

    setUp(() {
      const ReminderPlanner planner = ReminderPlanner();
      plan = planner.plan(
        contacts: parseAll(),
        now: DateTime(2026, 10, 16, 10),
      );
    });

    test('秦文芳 农历9月18日 -> 2026-10-27 提醒（不是 9月18日）', () {
      final PendingReminder onDay = reminderOf(plan, '秦文芳', ReminderKind.onDay);
      expect(onDay.scheduledAt, DateTime(2026, 10, 27, 9, 0));
      expect(
        onDay.scheduledAt,
        isNot(DateTime(2026, 9, 18, 9, 0)),
        reason: '这就是当初的 bug：把农历月日当新历提醒',
      );

      final PendingReminder advance = reminderOf(
        plan,
        '秦文芳',
        ReminderKind.advance,
      );
      expect(advance.scheduledAt, DateTime(2026, 10, 24, 9, 0)); // 提前 3 天
      expect(advance.body, contains('还有 3 天'));
    });

    test('陈光华 农历9月25日 -> 2026-11-03', () {
      expect(
        reminderOf(plan, '陈光华', ReminderKind.onDay).scheduledAt,
        DateTime(2026, 11, 3, 9, 0),
      );
    });

    test('陈光兰 农历10月29日 -> 2026-12-07', () {
      expect(
        reminderOf(plan, '陈光兰', ReminderKind.onDay).scheduledAt,
        DateTime(2026, 12, 7, 9, 0),
      );
    });

    test('七靓鹅公 农历12月22日 -> 2027-01-29（跨农历年）', () {
      expect(
        reminderOf(plan, '七靓鹅公', ReminderKind.onDay).scheduledAt,
        DateTime(2027, 1, 29, 9, 0),
      );
    });

    test('二姐 农历2月20日 -> 2027-03-27', () {
      expect(
        reminderOf(plan, '二姐', ReminderKind.onDay).scheduledAt,
        DateTime(2027, 3, 27, 9, 0),
      );
    });

    test('大姐 农历3月17日 -> 2027-04-23（不是新历 4/28）', () {
      final PendingReminder onDay = reminderOf(plan, '大姐', ReminderKind.onDay);
      expect(onDay.scheduledAt, DateTime(2027, 4, 23, 9, 0));
      expect(onDay.scheduledAt, isNot(DateTime(2027, 4, 28, 9, 0)));
    });

    test('每一条提醒都晚于「现在」，且日期都是 09:00', () {
      final DateTime now = DateTime(2026, 10, 16, 10);
      for (final PendingReminder r in plan) {
        expect(
          r.scheduledAt.isAfter(now),
          isTrue,
          reason: '${r.contactName} 排到了过去',
        );
        expect(r.scheduledAt.hour, 9);
        expect(r.scheduledAt.minute, 0);
      }
    });

    test('计划非空且 id 唯一', () {
      expect(plan, isNotEmpty);
      expect(
        plan.map((PendingReminder r) => r.id).toSet(),
        hasLength(plan.length),
      );
    });
  });

  group('换算细节', () {
    test('农历生日每年换算出来的公历日期都会变，但农历月日不变', () {
      const BirthdayCalculator calc = BirthdayCalculator();
      const Birthday lunar = Birthday(
        month: 9,
        day: 18,
        year: 1972,
        calendar: BirthdayCalendar.lunar,
      );
      final DateTime d2026 = calc.occurrenceInYear(lunar, 2026)!.date;
      final DateTime d2027 = calc.occurrenceInYear(lunar, 2027)!.date;
      expect(d2026, DateTime(2026, 10, 27));
      expect(d2027, DateTime(2027, 10, 17));
      expect(d2026, isNot(d2027));
    });

    test('同一份数据改成新历，日期就变成新历的月日（对照组）', () {
      const BirthdayCalculator calc = BirthdayCalculator();
      const Birthday solar = Birthday(month: 9, day: 18, year: 1972);
      expect(calc.occurrenceInYear(solar, 2026)!.date, DateTime(2026, 9, 18));
    });
  });
}
