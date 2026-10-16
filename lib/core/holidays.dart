import 'package:lunar/lunar.dart' as lunar_pkg;
import 'package:meta/meta.dart';

import 'lunar_converter.dart';

/// 一个法定节假日（或它的放假区间）。
@immutable
class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    required this.emoji,
    required this.start,
    required this.end,
    required this.days,
    this.workdays = const <DateTime>[],
    this.isOfficial = true,
    this.source,
  });

  final String id;
  final String name;
  final String emoji;

  /// 放假第一天 / 最后一天（含）。
  final DateTime start;
  final DateTime end;

  /// 放假天数。
  final int days;

  /// 调休上班的日期。
  final List<DateTime> workdays;

  /// 是否已由国务院办公厅公布（未公布的年份只有节日当天，没有调休信息）。
  final bool isOfficial;

  /// 数据来源说明。
  final String? source;

  bool containsDate(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// 「10月1日 – 10月7日」。
  String get rangeLabel {
    if (start == end) return _md(start);
    if (start.month == end.month) {
      return '${start.month}月${start.day}日 – ${end.day}日';
    }
    return '${_md(start)} – ${_md(end)}';
  }

  static String _md(DateTime d) => '${d.month}月${d.day}日';

  @override
  String toString() => 'Holiday($name, $rangeLabel)';
}

/// 某个假期离现在还有多久。
@immutable
class HolidayCountdown {
  const HolidayCountdown({
    required this.holiday,
    required this.daysUntilStart,
    required this.daysUntilEnd,
  });

  final Holiday holiday;
  final int daysUntilStart;
  final int daysUntilEnd;

  /// 今天就在假期里。
  bool get isOngoing => daysUntilStart <= 0 && daysUntilEnd >= 0;

  /// 假期第几天（从 1 开始，仅在 [isOngoing] 时有意义）。
  int get dayIndex => daysUntilStart <= 0 ? -daysUntilStart + 1 : 0;

  String get countdownLabel {
    if (isOngoing) return '假期第 $dayIndex 天';
    if (daysUntilStart == 1) return '明天开始';
    return '还有 $daysUntilStart 天';
  }

  @override
  String toString() => 'HolidayCountdown(${holiday.name}, $countdownLabel)';
}

/// 已公布的放假安排。
///
/// 数据来源：**国务院办公厅关于 2026 年部分节假日安排的通知**
/// （国办发明电〔2025〕7 号，2025-11-04 发布）。
/// <https://www.gov.cn/zhengce/content/202511/content_7047090.htm>
///
/// 每年 11 月左右会公布下一年的安排；未公布的年份由 [holidaysForYear] 按
/// 节日当天 + 周末推算，并标注「以国务院通知为准」。
final List<Holiday> kOfficialHolidays = <Holiday>[
  Holiday(
    id: '2026_new_year',
    name: '元旦',
    emoji: '🎊',
    start: DateTime(2026, 1, 1),
    end: DateTime(2026, 1, 3),
    days: 3,
    workdays: <DateTime>[DateTime(2026, 1, 4)],
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_spring_festival',
    name: '春节',
    emoji: '🧧',
    start: DateTime(2026, 2, 15),
    end: DateTime(2026, 2, 23),
    days: 9,
    workdays: <DateTime>[DateTime(2026, 2, 14), DateTime(2026, 2, 28)],
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_qingming',
    name: '清明节',
    emoji: '🌿',
    start: DateTime(2026, 4, 4),
    end: DateTime(2026, 4, 6),
    days: 3,
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_labour_day',
    name: '劳动节',
    emoji: '🛠️',
    start: DateTime(2026, 5, 1),
    end: DateTime(2026, 5, 5),
    days: 5,
    workdays: <DateTime>[DateTime(2026, 5, 9)],
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_dragon_boat',
    name: '端午节',
    emoji: '🐲',
    start: DateTime(2026, 6, 19),
    end: DateTime(2026, 6, 21),
    days: 3,
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_mid_autumn',
    name: '中秋节',
    emoji: '🥮',
    start: DateTime(2026, 9, 25),
    end: DateTime(2026, 9, 27),
    days: 3,
    source: '国办发明电〔2025〕7号',
  ),
  Holiday(
    id: '2026_national_day',
    name: '国庆节',
    emoji: '🇨🇳',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 7),
    days: 7,
    workdays: <DateTime>[DateTime(2026, 9, 20), DateTime(2026, 10, 10)],
    source: '国办发明电〔2025〕7号',
  ),
];

/// 清明节的公历日期（按节气算，4 月 4 / 5 / 6 日浮动）。
DateTime qingmingOf(int year) {
  for (int y = year; y <= year + 1; y++) {
    try {
      final Map<String, lunar_pkg.Solar> table = lunar_pkg.Lunar.fromYmd(
        y,
        1,
        1,
      ).getJieQiTable();
      final lunar_pkg.Solar? qingming = table['清明'];
      if (qingming != null && qingming.getYear() == year) {
        return DateTime(year, qingming.getMonth(), qingming.getDay());
      }
    } catch (_) {
      // 落到下面的兜底
    }
  }
  return DateTime(year, 4, 4);
}

/// 春节（正月初一）的公历日期。
DateTime springFestivalOf(
  int year, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  for (int lunarYear = year - 1; lunarYear <= year + 1; lunarYear++) {
    final LunarResolution? resolved = lunar.resolve(
      month: 1,
      day: 1,
      lunarYear: lunarYear,
    );
    if (resolved != null && resolved.solarDate.year == year) {
      return resolved.solarDate;
    }
  }
  return DateTime(year, 2, 1);
}

/// 某年的法定节假日列表。
///
/// 已公布年份直接返回官方安排；未公布年份退化成「节日当天 + 相邻周末」的估算，
/// 并标记 [Holiday.isOfficial] = false，界面上要说明「以国务院通知为准」。
List<Holiday> holidaysForYear(
  int year, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  final List<Holiday> official = kOfficialHolidays
      .where((Holiday h) => h.start.year == year)
      .toList(growable: false);
  if (official.isNotEmpty) return official;

  // ---- 未公布年份的估算 ----
  final DateTime spring = springFestivalOf(year, lunar);
  final DateTime qingming = qingmingOf(year);
  final List<Holiday> estimate = <Holiday>[];
  void add(String id, String name, String emoji, DateTime day, int days) {
    estimate.add(
      Holiday(
        id: '${year}_$id',
        name: name,
        emoji: emoji,
        start: day,
        end: day.add(Duration(days: days - 1)),
        days: days,
        isOfficial: false,
        source: '按节日日期推算，以国务院通知为准',
      ),
    );
  }

  add('new_year', '元旦', '🎊', DateTime(year, 1, 1), 1);
  add('spring_festival', '春节', '🧧', spring, 3);
  add('qingming', '清明节', '🌿', qingming, 1);
  add('labour_day', '劳动节', '🛠️', DateTime(year, 5, 1), 1);
  add('dragon_boat', '端午节', '🐲', _lunarDate(year, 5, 5, lunar), 1);
  add('mid_autumn', '中秋节', '🥮', _lunarDate(year, 8, 15, lunar), 1);
  add('national_day', '国庆节', '🇨🇳', DateTime(year, 10, 1), 3);
  return estimate;
}

DateTime _lunarDate(int year, int month, int day, LunarConverter lunar) {
  for (int lunarYear = year - 1; lunarYear <= year + 1; lunarYear++) {
    final LunarResolution? resolved = lunar.resolve(
      month: month,
      day: day,
      lunarYear: lunarYear,
    );
    if (resolved != null && resolved.solarDate.year == year) {
      return resolved.solarDate;
    }
  }
  return DateTime(year, month, day);
}

/// 从 [from]（含当天）起接下来 [limit] 个假期，含「正在进行中」的那个。
List<HolidayCountdown> upcomingHolidays(
  DateTime from, {
  int limit = 4,
  LunarConverter lunar = const LunarPackageConverter(),
}) {
  final DateTime day = DateTime(from.year, from.month, from.day);
  final List<Holiday> pool = <Holiday>[
    ...holidaysForYear(day.year, lunar),
    ...holidaysForYear(day.year + 1, lunar),
  ];
  final List<HolidayCountdown> list = <HolidayCountdown>[];
  for (final Holiday holiday in pool) {
    final int untilEnd = _daysBetween(day, holiday.end);
    if (untilEnd < 0) continue; // 已经结束了
    list.add(
      HolidayCountdown(
        holiday: holiday,
        daysUntilStart: _daysBetween(day, holiday.start),
        daysUntilEnd: untilEnd,
      ),
    );
  }
  list.sort(
    (HolidayCountdown a, HolidayCountdown b) =>
        a.daysUntilStart.compareTo(b.daysUntilStart),
  );
  return list.take(limit).toList(growable: false);
}

/// [date] 是不是调休上班日（例如 2026-10-10 是国庆的调休上班日）。
Holiday? makeUpWorkdayOn(
  DateTime date, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  for (final Holiday holiday in <Holiday>[
    ...holidaysForYear(day.year, lunar),
    ...holidaysForYear(day.year + 1, lunar),
  ]) {
    for (final DateTime workday in holiday.workdays) {
      if (workday.year == day.year &&
          workday.month == day.month &&
          workday.day == day.day) {
        return holiday;
      }
    }
  }
  return null;
}

/// [date] 当天所处的假期（含调休上班日不算假期）。
Holiday? holidayOn(
  DateTime date, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  for (final Holiday holiday in <Holiday>[
    ...holidaysForYear(day.year, lunar),
    ...holidaysForYear(day.year + 1, lunar),
  ]) {
    if (holiday.containsDate(day)) return holiday;
  }
  return null;
}

int _daysBetween(DateTime a, DateTime b) => DateTime(
  b.year,
  b.month,
  b.day,
).difference(DateTime(a.year, a.month, a.day)).inDays;
