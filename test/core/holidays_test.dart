import 'package:birthday_keeper/core/holidays.dart';
import 'package:birthday_keeper/core/lunar_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LunarConverter lunar = LunarPackageConverter();

  group('2026 官方放假安排（国办发明电〔2025〕7号）', () {
    test('一共 7 个假期，全部为官方数据', () {
      final List<Holiday> list = holidaysForYear(2026, lunar);
      expect(list, hasLength(7));
      expect(list.every((Holiday h) => h.isOfficial), isTrue);
      expect(list.map((Holiday h) => h.name), <String>[
        '元旦',
        '春节',
        '清明节',
        '劳动节',
        '端午节',
        '中秋节',
        '国庆节',
      ]);
    });

    test('元旦：1 月 1–3 日，1 月 4 日上班', () {
      final Holiday h = holidaysForYear(2026, lunar).first;
      expect(h.start, DateTime(2026, 1, 1));
      expect(h.end, DateTime(2026, 1, 3));
      expect(h.days, 3);
      expect(h.workdays, <DateTime>[DateTime(2026, 1, 4)]);
    });

    test('春节：2 月 15–23 日共 9 天，2/14 与 2/28 上班', () {
      final Holiday h = holidaysForYear(
        2026,
        lunar,
      ).firstWhere((Holiday e) => e.name == '春节');
      expect(h.start, DateTime(2026, 2, 15));
      expect(h.end, DateTime(2026, 2, 23));
      expect(h.days, 9);
      expect(h.workdays, <DateTime>[
        DateTime(2026, 2, 14),
        DateTime(2026, 2, 28),
      ]);
      expect(h.rangeLabel, '2月15日 – 23日');
    });

    test('劳动节：5 月 1–5 日共 5 天，5/9 上班', () {
      final Holiday h = holidaysForYear(
        2026,
        lunar,
      ).firstWhere((Holiday e) => e.name == '劳动节');
      expect(h.days, 5);
      expect(h.workdays, <DateTime>[DateTime(2026, 5, 9)]);
    });

    test('国庆节：10 月 1–7 日共 7 天，9/20 与 10/10 上班', () {
      final Holiday h = holidaysForYear(
        2026,
        lunar,
      ).firstWhere((Holiday e) => e.name == '国庆节');
      expect(h.start, DateTime(2026, 10, 1));
      expect(h.end, DateTime(2026, 10, 7));
      expect(h.days, 7);
      expect(h.workdays, <DateTime>[
        DateTime(2026, 9, 20),
        DateTime(2026, 10, 10),
      ]);
    });

    test('清明节气是 4 月 5 日；官方放假区间从 4/4（周六）开始', () {
      // 注意区分：节气「清明」2026 年落在 4 月 5 日，
      // 官方通知里的清明节放假区间是 4 月 4 日（周六）– 4 月 6 日（周一）。
      expect(qingmingOf(2026), DateTime(2026, 4, 5));
      final Holiday h = holidaysForYear(
        2026,
        lunar,
      ).firstWhere((Holiday e) => e.name == '清明节');
      expect(h.start, DateTime(2026, 4, 4));
      expect(h.end, DateTime(2026, 4, 6));
    });
  });

  group('倒计时', () {
    test('今天 2026-10-10：国庆已结束，下一个是元旦还有 83 天', () {
      final List<HolidayCountdown> list = upcomingHolidays(
        DateTime(2026, 10, 10),
        lunar: lunar,
      );
      expect(list, isNotEmpty);
      final HolidayCountdown first = list.first;
      expect(first.holiday.name, '元旦');
      expect(first.holiday.start, DateTime(2027, 1, 1));
      expect(first.daysUntilStart, 83);
      expect(first.countdownLabel, '还有 83 天');
      expect(first.isOngoing, isFalse);
    });

    test('假期进行中会显示「假期第 N 天」', () {
      final List<HolidayCountdown> list = upcomingHolidays(
        DateTime(2026, 10, 3),
        lunar: lunar,
      );
      final HolidayCountdown ongoing = list.first;
      expect(ongoing.holiday.name, '国庆节');
      expect(ongoing.isOngoing, isTrue);
      expect(ongoing.dayIndex, 3);
      expect(ongoing.countdownLabel, '假期第 3 天');
    });

    test('假期前一天显示「明天开始」', () {
      final List<HolidayCountdown> list = upcomingHolidays(
        DateTime(2026, 9, 30),
        lunar: lunar,
      );
      expect(list.first.holiday.name, '国庆节');
      expect(list.first.countdownLabel, '明天开始');
    });

    test('已经过去的假期不再出现', () {
      final List<HolidayCountdown> list = upcomingHolidays(
        DateTime(2026, 10, 10),
        lunar: lunar,
      );
      expect(
        list.map((HolidayCountdown c) => c.holiday.name),
        isNot(contains('国庆节')),
      );
      expect(
        list.map((HolidayCountdown c) => c.holiday.name),
        isNot(contains('中秋节')),
      );
    });
  });

  group('调休上班日', () {
    test('2026-10-10（周六）是国庆的调休上班日', () {
      final Holiday? h = makeUpWorkdayOn(DateTime(2026, 10, 10), lunar);
      expect(h, isNotNull);
      expect(h!.name, '国庆节');
    });

    test('普通日子不是', () {
      expect(makeUpWorkdayOn(DateTime(2026, 10, 9), lunar), isNull);
      expect(makeUpWorkdayOn(DateTime(2026, 10, 12), lunar), isNull);
    });

    test('假期当天能查出来', () {
      expect(holidayOn(DateTime(2026, 10, 3), lunar)?.name, '国庆节');
      expect(holidayOn(DateTime(2026, 2, 20), lunar)?.name, '春节');
      expect(holidayOn(DateTime(2026, 3, 20), lunar), isNull);
    });
  });

  group('未公布年份的估算', () {
    test('2027 年按节日日期估算并标记为非官方', () {
      final List<Holiday> list = holidaysForYear(2027, lunar);
      expect(list, hasLength(7));
      expect(list.every((Holiday h) => !h.isOfficial), isTrue);
      expect(list.first.start, DateTime(2027, 1, 1));
      expect(list.last.name, '国庆节');
      // 春节按农历算，2027 年正月初一落在 2 月
      final Holiday spring = list.firstWhere((Holiday h) => h.name == '春节');
      expect(spring.start.year, 2027);
      expect(spring.start.month, 2);
      expect(spring.source, contains('国务院'));
    });

    test('2027 的估算也能给出倒计时', () {
      final List<HolidayCountdown> list = upcomingHolidays(
        DateTime(2027, 1, 2),
        lunar: lunar,
      );
      expect(list.first.holiday.start.year, 2027);
      expect(list.first.daysUntilStart, greaterThan(0));
    });
  });
}
