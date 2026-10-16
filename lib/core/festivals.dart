import 'package:meta/meta.dart';

import 'lunar_converter.dart';

/// 节日的日期规则。
enum FestivalRule {
  /// 固定新历月日（元旦 1/1、国庆 10/1 …）。
  solar,

  /// 农历月日（春节正月初一、端午五月初五 …）。
  lunar,

  /// 「某月第 n 个星期几」（母亲节 = 5 月第 2 个周日）。
  nthWeekday,

  /// 除夕 = 春节（正月初一）前一天。
  lunarEve,
}

/// 一个节日。
@immutable
class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rule,
    this.month,
    this.day,
    this.weekday,
    this.nth,
    this.lunarMonth,
    this.lunarDay,
    this.hint,
  });

  final String id;
  final String name;
  final String emoji;
  final FestivalRule rule;

  /// [FestivalRule.solar]：新历月 / 日。
  final int? month;
  final int? day;

  /// [FestivalRule.nthWeekday]：星期几（1 = 周一 … 7 = 周日）与第几个。
  final int? weekday;
  final int? nth;

  /// [FestivalRule.lunar]：农历月 / 日。
  final int? lunarMonth;
  final int? lunarDay;

  /// 一句话说明。
  final String? hint;

  @override
  String toString() => 'Festival($id, $name)';
}

/// 内置节日数据。
///
/// 农历节日由农历库换算，不写死日期；母亲节 / 父亲节 / 感恩节按「第 n 个星期几」算。
const List<Festival> kFestivals = <Festival>[
  // ---------------- 新历 ----------------
  Festival(
    id: 'new_year',
    name: '元旦',
    emoji: '🎊',
    rule: FestivalRule.solar,
    month: 1,
    day: 1,
    hint: '新历新年第一天，法定节假日。',
  ),
  Festival(
    id: 'valentine',
    name: '情人节',
    emoji: '💐',
    rule: FestivalRule.solar,
    month: 2,
    day: 14,
    hint: '记得给对象准备点什么。',
  ),
  Festival(
    id: 'womens_day',
    name: '妇女节',
    emoji: '🌷',
    rule: FestivalRule.solar,
    month: 3,
    day: 8,
    hint: '给妈妈、姐姐妹妹、女同事说句节日快乐。',
  ),
  Festival(
    id: 'tree_planting',
    name: '植树节',
    emoji: '🌳',
    rule: FestivalRule.solar,
    month: 3,
    day: 12,
  ),
  Festival(
    id: 'april_fools',
    name: '愚人节',
    emoji: '🤡',
    rule: FestivalRule.solar,
    month: 4,
    day: 1,
  ),
  Festival(
    id: 'labour_day',
    name: '劳动节',
    emoji: '🛠️',
    rule: FestivalRule.solar,
    month: 5,
    day: 1,
    hint: '法定节假日。',
  ),
  Festival(
    id: 'youth_day',
    name: '青年节',
    emoji: '🌱',
    rule: FestivalRule.solar,
    month: 5,
    day: 4,
  ),
  Festival(
    id: 'childrens_day',
    name: '儿童节',
    emoji: '🎈',
    rule: FestivalRule.solar,
    month: 6,
    day: 1,
    hint: '给孩子（或者自己）过个节。',
  ),
  Festival(
    id: 'party_day',
    name: '建党节',
    emoji: '🚩',
    rule: FestivalRule.solar,
    month: 7,
    day: 1,
  ),
  Festival(
    id: 'army_day',
    name: '建军节',
    emoji: '🎖️',
    rule: FestivalRule.solar,
    month: 8,
    day: 1,
  ),
  Festival(
    id: 'teachers_day',
    name: '教师节',
    emoji: '📚',
    rule: FestivalRule.solar,
    month: 9,
    day: 10,
    hint: '给老师发条消息。',
  ),
  Festival(
    id: 'national_day',
    name: '国庆节',
    emoji: '🇨🇳',
    rule: FestivalRule.solar,
    month: 10,
    day: 1,
    hint: '法定节假日，一年里最长的假期之一。',
  ),
  Festival(
    id: 'halloween',
    name: '万圣夜',
    emoji: '🎃',
    rule: FestivalRule.solar,
    month: 10,
    day: 31,
  ),
  Festival(
    id: 'christmas_eve',
    name: '平安夜',
    emoji: '🍎',
    rule: FestivalRule.solar,
    month: 12,
    day: 24,
  ),
  Festival(
    id: 'christmas',
    name: '圣诞节',
    emoji: '🎄',
    rule: FestivalRule.solar,
    month: 12,
    day: 25,
  ),

  // ---------------- 第 n 个星期几 ----------------
  Festival(
    id: 'mothers_day',
    name: '母亲节',
    emoji: '💝',
    rule: FestivalRule.nthWeekday,
    month: 5,
    weekday: 7,
    nth: 2,
    hint: '5 月第 2 个周日，别忘了妈妈。',
  ),
  Festival(
    id: 'fathers_day',
    name: '父亲节',
    emoji: '👔',
    rule: FestivalRule.nthWeekday,
    month: 6,
    weekday: 7,
    nth: 3,
    hint: '6 月第 3 个周日，别忘了爸爸。',
  ),
  Festival(
    id: 'thanksgiving',
    name: '感恩节',
    emoji: '🦃',
    rule: FestivalRule.nthWeekday,
    month: 11,
    weekday: 4,
    nth: 4,
    hint: '11 月第 4 个周四。',
  ),

  // ---------------- 农历 ----------------
  Festival(
    id: 'spring_festival',
    name: '春节',
    emoji: '🧧',
    rule: FestivalRule.lunar,
    lunarMonth: 1,
    lunarDay: 1,
    hint: '农历正月初一，法定节假日。',
  ),
  Festival(
    id: 'lantern',
    name: '元宵节',
    emoji: '🏮',
    rule: FestivalRule.lunar,
    lunarMonth: 1,
    lunarDay: 15,
    hint: '正月十五，吃元宵、看花灯。',
  ),
  Festival(
    id: 'dragon_head',
    name: '龙抬头',
    emoji: '🐉',
    rule: FestivalRule.lunar,
    lunarMonth: 2,
    lunarDay: 2,
    hint: '二月二，民间有理发的习俗。',
  ),
  Festival(
    id: 'dragon_boat',
    name: '端午节',
    emoji: '🐲',
    rule: FestivalRule.lunar,
    lunarMonth: 5,
    lunarDay: 5,
    hint: '农历五月初五，法定节假日。',
  ),
  Festival(
    id: 'qixi',
    name: '七夕',
    emoji: '💞',
    rule: FestivalRule.lunar,
    lunarMonth: 7,
    lunarDay: 7,
    hint: '农历七月初七。',
  ),
  Festival(
    id: 'ghost',
    name: '中元节',
    emoji: '🕯️',
    rule: FestivalRule.lunar,
    lunarMonth: 7,
    lunarDay: 15,
    hint: '农历七月十五。',
  ),
  Festival(
    id: 'mid_autumn',
    name: '中秋节',
    emoji: '🥮',
    rule: FestivalRule.lunar,
    lunarMonth: 8,
    lunarDay: 15,
    hint: '农历八月十五，法定节假日。',
  ),
  Festival(
    id: 'double_ninth',
    name: '重阳节',
    emoji: '⛰️',
    rule: FestivalRule.lunar,
    lunarMonth: 9,
    lunarDay: 9,
    hint: '农历九月初九，敬老的日子。',
  ),
  Festival(
    id: 'laba',
    name: '腊八节',
    emoji: '🥣',
    rule: FestivalRule.lunar,
    lunarMonth: 12,
    lunarDay: 8,
    hint: '农历腊月初八，喝腊八粥。',
  ),
  Festival(
    id: 'minor_new_year',
    name: '小年',
    emoji: '🧹',
    rule: FestivalRule.lunar,
    lunarMonth: 12,
    lunarDay: 23,
    hint: '农历腊月廿三（北方小年）。',
  ),
  Festival(
    id: 'lunar_new_year_eve',
    name: '除夕',
    emoji: '🎆',
    rule: FestivalRule.lunarEve,
    hint: '春节前一天，法定节假日。',
  ),
];

/// 第 [nth] 个星期 [weekday]（1 = 周一 … 7 = 周日）。
DateTime nthWeekdayOf(int year, int month, int weekday, int nth) {
  final DateTime first = DateTime(year, month, 1);
  final int delta = (weekday - first.weekday) % 7;
  final int day = 1 + (delta < 0 ? delta + 7 : delta) + (nth - 1) * 7;
  return DateTime(year, month, day);
}

/// 一个节日 + 它下一次的日期。
@immutable
class FestivalOccurrence {
  const FestivalOccurrence({
    required this.festival,
    required this.date,
    required this.daysUntil,
  });

  final Festival festival;
  final DateTime date;
  final int daysUntil;

  /// 「今天」「明天」「还有 N 天」。
  String get countdownLabel {
    if (daysUntil <= 0) return '今天';
    if (daysUntil == 1) return '明天';
    return '还有 $daysUntil 天';
  }

  @override
  String toString() => 'FestivalOccurrence(${festival.name}, $date)';
}

int _daysBetween(DateTime a, DateTime b) => DateTime(
  b.year,
  b.month,
  b.day,
).difference(DateTime(a.year, a.month, a.day)).inDays;

/// 节日在 [from] 当天或之后最近的一次日期；算不出来返回 `null`。
DateTime? nextFestivalDate(
  Festival festival,
  DateTime from, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  final DateTime day = DateTime(from.year, from.month, from.day);
  switch (festival.rule) {
    case FestivalRule.solar:
      DateTime candidate = DateTime(day.year, festival.month!, festival.day!);
      if (candidate.isBefore(day)) {
        candidate = DateTime(day.year + 1, festival.month!, festival.day!);
      }
      return candidate;

    case FestivalRule.nthWeekday:
      DateTime candidate = nthWeekdayOf(
        day.year,
        festival.month!,
        festival.weekday!,
        festival.nth!,
      );
      if (candidate.isBefore(day)) {
        candidate = nthWeekdayOf(
          day.year + 1,
          festival.month!,
          festival.weekday!,
          festival.nth!,
        );
      }
      return candidate;

    case FestivalRule.lunar:
      final LunarDate? today = lunar.toLunar(day);
      final int base = today?.year ?? day.year;
      final List<DateTime> candidates = <DateTime>[];
      for (int y = base - 1; y <= base + 1; y++) {
        final LunarResolution? resolved = lunar.resolve(
          month: festival.lunarMonth!,
          day: festival.lunarDay!,
          lunarYear: y,
        );
        if (resolved != null) candidates.add(resolved.solarDate);
      }
      candidates.sort();
      for (final DateTime candidate in candidates) {
        if (!candidate.isBefore(day)) return candidate;
      }
      return null;

    case FestivalRule.lunarEve:
      final LunarDate? today = lunar.toLunar(day);
      final int base = today?.year ?? day.year;
      final List<DateTime> eves = <DateTime>[];
      for (int y = base; y <= base + 1; y++) {
        final LunarResolution? spring = lunar.resolve(
          month: 1,
          day: 1,
          lunarYear: y,
        );
        if (spring != null) {
          eves.add(spring.solarDate.subtract(const Duration(days: 1)));
        }
      }
      eves.sort();
      for (final DateTime eve in eves) {
        if (!eve.isBefore(day)) return eve;
      }
      return null;
  }
}

/// 从 [from]（含当天）起接下来 [limit] 个节日，按日期升序。
///
/// 同一天有多个节日（例如除夕和腊八不冲突，但元旦可能撞上农历节日）都会保留。
List<FestivalOccurrence> upcomingFestivals(
  DateTime from, {
  int limit = 8,
  LunarConverter lunar = const LunarPackageConverter(),
}) {
  final DateTime day = DateTime(from.year, from.month, from.day);
  final List<FestivalOccurrence> all = <FestivalOccurrence>[];
  for (final Festival festival in kFestivals) {
    final DateTime? date = nextFestivalDate(festival, day, lunar);
    if (date == null) continue;
    all.add(
      FestivalOccurrence(
        festival: festival,
        date: date,
        daysUntil: _daysBetween(day, date),
      ),
    );
  }
  all.sort((FestivalOccurrence a, FestivalOccurrence b) {
    final int byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return a.festival.name.compareTo(b.festival.name);
  });
  return all.take(limit).toList(growable: false);
}

/// [date] 这一天有哪些节日。
List<Festival> festivalsOnDate(
  DateTime date, [
  LunarConverter lunar = const LunarPackageConverter(),
]) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  final LunarDate? lunarDay = lunar.toLunar(day);
  final LunarDate? lunarTomorrow = lunar.toLunar(
    day.add(const Duration(days: 1)),
  );
  final List<Festival> result = <Festival>[];
  for (final Festival festival in kFestivals) {
    switch (festival.rule) {
      case FestivalRule.solar:
        if (day.month == festival.month && day.day == festival.day) {
          result.add(festival);
        }
      case FestivalRule.nthWeekday:
        final DateTime nth = nthWeekdayOf(
          day.year,
          festival.month!,
          festival.weekday!,
          festival.nth!,
        );
        if (nth.year == day.year &&
            nth.month == day.month &&
            nth.day == day.day) {
          result.add(festival);
        }
      case FestivalRule.lunar:
        if (lunarDay != null &&
            !lunarDay.isLeapMonth &&
            lunarDay.month == festival.lunarMonth &&
            lunarDay.day == festival.lunarDay) {
          result.add(festival);
        }
      case FestivalRule.lunarEve:
        // 除夕 = 第二天是正月初一
        if (lunarTomorrow != null &&
            lunarTomorrow.month == 1 &&
            lunarTomorrow.day == 1) {
          result.add(festival);
        }
    }
  }
  return result;
}
