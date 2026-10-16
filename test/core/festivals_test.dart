import 'package:birthday_keeper/core/festivals.dart';
import 'package:birthday_keeper/core/lunar_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LunarConverter lunar = LunarPackageConverter();

  Festival byId(String id) => kFestivals.firstWhere((Festival f) => f.id == id);

  group('新历节日', () {
    test('固定日期算得准', () {
      expect(
        nextFestivalDate(byId('national_day'), DateTime(2026, 10, 10)),
        DateTime(2027, 10, 1), // 10/10 时今年国庆已过 -> 明年
      );
      expect(
        nextFestivalDate(byId('national_day'), DateTime(2026, 9, 30)),
        DateTime(2026, 10, 1),
      );
      expect(
        nextFestivalDate(byId('new_year'), DateTime(2026, 10, 10)),
        DateTime(2027, 1, 1),
      );
      expect(
        nextFestivalDate(byId('christmas'), DateTime(2026, 12, 1)),
        DateTime(2026, 12, 25),
      );
    });

    test('当天也算「下一个」', () {
      expect(
        nextFestivalDate(byId('new_year'), DateTime(2027, 1, 1)),
        DateTime(2027, 1, 1),
      );
    });
  });

  group('第 n 个星期几', () {
    test('母亲节 = 5 月第 2 个周日', () {
      // 2026-05-01 是周五 -> 第一个周日 5/3，第二个周日 5/10
      expect(
        nextFestivalDate(byId('mothers_day'), DateTime(2026, 1, 1)),
        DateTime(2026, 5, 10),
      );
    });

    test('父亲节 = 6 月第 3 个周日', () {
      expect(
        nextFestivalDate(byId('fathers_day'), DateTime(2026, 1, 1)),
        DateTime(2026, 6, 21),
      );
    });

    test('感恩节 = 11 月第 4 个周四', () {
      expect(
        nextFestivalDate(byId('thanksgiving'), DateTime(2026, 1, 1)),
        DateTime(2026, 11, 26),
      );
    });
  });

  group('农历节日（用 2026 官方放假安排反查）', () {
    test('春节 2026 = 2 月 17 日（官方通知：2/15 起放假，正月初七 2/23）', () {
      expect(
        nextFestivalDate(byId('spring_festival'), DateTime(2026, 1, 1)),
        DateTime(2026, 2, 17),
      );
    });

    test('除夕 2026 = 2 月 16 日（春节前一天）', () {
      expect(
        nextFestivalDate(byId('lunar_new_year_eve'), DateTime(2026, 1, 1)),
        DateTime(2026, 2, 16),
      );
    });

    test('端午节 2026 = 6 月 19 日（官方通知 6/19 起放假）', () {
      expect(
        nextFestivalDate(byId('dragon_boat'), DateTime(2026, 1, 1)),
        DateTime(2026, 6, 19),
      );
    });

    test('中秋节 2026 = 9 月 25 日（官方通知 9/25 起放假）', () {
      expect(
        nextFestivalDate(byId('mid_autumn'), DateTime(2026, 1, 1)),
        DateTime(2026, 9, 25),
      );
    });

    test('元宵节 = 正月十五', () {
      // 春节 2/17 -> 元宵 3/3
      expect(
        nextFestivalDate(byId('lantern'), DateTime(2026, 1, 1)),
        DateTime(2026, 3, 3),
      );
    });
  });

  group('某一天有哪些节日', () {
    test('春节当天 / 除夕当天', () {
      final List<Festival> eve = festivalsOnDate(DateTime(2026, 2, 16), lunar);
      expect(eve.map((Festival f) => f.name), contains('除夕'));
      final List<Festival> spring = festivalsOnDate(
        DateTime(2026, 2, 17),
        lunar,
      );
      expect(spring.map((Festival f) => f.name), contains('春节'));
    });

    test('中秋 / 国庆同月各自算对', () {
      expect(
        festivalsOnDate(
          DateTime(2026, 9, 25),
          lunar,
        ).map((Festival f) => f.name),
        contains('中秋节'),
      );
      expect(
        festivalsOnDate(
          DateTime(2026, 10, 1),
          lunar,
        ).map((Festival f) => f.name),
        contains('国庆节'),
      );
    });

    test('普通日子没有节日', () {
      expect(festivalsOnDate(DateTime(2026, 10, 20), lunar), isEmpty);
    });
  });

  group('接下来 N 个节日', () {
    test('按日期升序、都在今天之后、数量受控', () {
      final DateTime from = DateTime(2026, 10, 10);
      final List<FestivalOccurrence> list = upcomingFestivals(
        from,
        limit: 5,
        lunar: lunar,
      );
      expect(list, hasLength(5));
      for (final FestivalOccurrence item in list) {
        expect(
          item.date.isBefore(from),
          isFalse,
          reason: '${item.festival.name} 不应早于今天',
        );
        expect(item.daysUntil, greaterThanOrEqualTo(0));
      }
      for (int i = 1; i < list.length; i++) {
        expect(
          list[i].date.isBefore(list[i - 1].date),
          isFalse,
          reason: '必须按日期升序',
        );
      }
      // 2026-10-10 之后最近的是重阳节（农历九月初九 -> 10/18）
      expect(list.first.festival.name, '重阳节');
      expect(list.first.date, DateTime(2026, 10, 18));
      expect(list.first.countdownLabel, '还有 8 天');
    });

    test('倒计时文案', () {
      final List<FestivalOccurrence> list = upcomingFestivals(
        DateTime(2026, 10, 1),
        limit: 3,
        lunar: lunar,
      );
      expect(list.first.festival.name, '国庆节');
      expect(list.first.countdownLabel, '今天');
    });
  });
}
