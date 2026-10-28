import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/ui/pages/calendar_page.dart';
import 'package:birthday_keeper/ui/pages/contact_detail_page.dart';
import 'package:birthday_keeper/ui/pages/upcoming_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// 用户被绕晕过的问题：界面上的「11月3日 · 农历」到底是农历还是新历？
///
/// 规则：**任何出现在界面上的日期都必须带历法标签**
/// - 生日本身：`农历9月25日` / `新历5月23日`
/// - 农历生日今年落在哪天：`新历11月3日`
///
/// 数据用用户真实的一条：陈光华，农历 9 月 25 日（2026 年落在新历 11 月 3 日）。
void main() {
  Contact lunarContact() => makeContact(
    id: 'chen',
    name: '陈光华',
    birthday: const Birthday(
      year: 1969,
      month: 9,
      day: 25,
      calendar: BirthdayCalendar.lunar,
    ),
  );

  Contact solarContact() => makeContact(
    id: 'zhang',
    name: '张三',
    birthday: const Birthday(year: 1996, month: 5, day: 23),
  );

  group('首页卡片（即将到来）', () {
    widgetTest('农历生日同时标出「农历生日」和「新历落在哪天」', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[lunarContact()],
      );
      await harness.load();
      await tester.pumpWidget(harness.wrap(const UpcomingPage()));
      await tester.pumpAndSettle();

      // 生日本身（农历）与换算出的新历日期都要在
      expect(find.textContaining('农历9月25日'), findsOneWidget);
      expect(find.textContaining('新历11月3日'), findsOneWidget);
      // 不能再出现「11月3日 · 农历」这种会被误读的写法
      expect(find.textContaining('11月3日 · 农历'), findsNothing);
    });

    widgetTest('新历生日也写明「新历」', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[solarContact()],
      );
      await harness.load();
      await tester.pumpWidget(harness.wrap(const UpcomingPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('新历5月23日'), findsOneWidget);
      expect(find.textContaining('农历'), findsNothing);
    });
  });

  group('详情页', () {
    widgetTest('农历生日：大日期标明是「新历」', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[lunarContact()],
      );
      await harness.load();
      await tester.pumpWidget(
        harness.wrap(const ContactDetailPage(contactId: 'chen')),
      );
      await tester.pumpAndSettle();

      // 换算出来的日期必须带「新历」前缀
      expect(find.textContaining('新历2026年11月3日'), findsOneWidget);
      // 生日本身仍然是农历
      expect(find.text('农历9月25日'), findsWidgets);
    });

    widgetTest('新历生日：大日期不加多余前缀', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[solarContact()],
      );
      await harness.load();
      await tester.pumpWidget(
        harness.wrap(const ContactDetailPage(contactId: 'zhang')),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026年5月23日 周六'), findsOneWidget);
      expect(find.textContaining('新历2026年'), findsNothing);
    });
  });

  group('首页卡片：星座单独一行', () {
    widgetTest('日期一行、星座另起一行，不会把「天蝎座」折成两行', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[lunarContact()],
      );
      await harness.load();
      await tester.pumpWidget(harness.wrap(const UpcomingPage()));
      await tester.pumpAndSettle();

      // 日期是单独一个 Text
      expect(find.text('农历9月25日 · 新历11月3日'), findsOneWidget);
      // 星座是另一个 Text（同一行里不再混着）
      expect(find.text('天蝎座'), findsWidgets);
      expect(find.text('农历9月25日 · 新历11月3日 · 天蝎座'), findsNothing);
    });
  });

  group('日历格子：直接把节日和假期写在格子里', () {
    widgetTest('节日名 / 休 / 班 都显示出来', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await tester.pumpWidget(
        harness.wrap(const CalendarPage(autoRotate: false)),
      );
      await tester.pumpAndSettle();

      // kNow = 2026-05-20，所以显示 2026 年 5 月
      String? label(String iso) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key('dayLabel-$iso')),
              matching: find.byType(Text),
            ),
          )
          .data;

      // 5/1 劳动节（也是假期第一天 -> 显示节日名，不是「休」）
      expect(label('2026-05-01'), '劳动节');
      // 5/2 仍在劳动节假期里 -> 休
      expect(label('2026-05-02'), '休');
      // 5/9 是劳动节的调休上班日 -> 班
      expect(label('2026-05-09'), '班');
      // 5/10 母亲节 -> 节日名
      expect(label('2026-05-10'), '母亲节');
      // 普通日子没有标签
      expect(find.byKey(const Key('dayLabel-2026-05-13')), findsNothing);
    });

    widgetTest('翻到下个月也能看到端午节的节日名', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await tester.pumpWidget(
        harness.wrap(const CalendarPage(autoRotate: false)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nextMonthButton')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('dayLabel-2026-06-19')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '端午节',
      );
      // 端午假期三天：中间那天是「休」；
      // 6/21 同时是父亲节，节日名优先于「休」（点开那天的详情能看全）
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('dayLabel-2026-06-20')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '休',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('dayLabel-2026-06-21')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '父亲节',
      );
    });
  });

  group('联系人生日也画到日历上', () {
    Contact mayThirteen() => makeContact(
      id: 'zhang',
      name: '张三',
      birthday: const Birthday(year: 1996, month: 5, day: 13),
    );

    widgetTest('生日那天显示联系人姓名，点开能看「张三 生日」', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[mayThirteen()],
      );
      await harness.load();
      await tester.pumpWidget(
        harness.wrap(const CalendarPage(autoRotate: false)),
      );
      await tester.pumpAndSettle();

      // 5/13 没有节日也没有假期，格子上的小字就是这个人的名字
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('dayLabel-2026-05-13')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '张三',
      );

      // 点开那天，详情里能看到生日
      await tester.tap(find.byKey(const Key('dayCell-2026-05-13')));
      await tester.pumpAndSettle();
      expect(find.text('张三 生日'), findsOneWidget);
    });

    widgetTest('节日和生日同一天时，每秒轮播（1 秒换一条）', (WidgetTester tester) async {
      // 5/10 既是母亲节，也是张三的生日
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'zhang',
            name: '张三',
            birthday: const Birthday(year: 1996, month: 5, day: 10),
          ),
        ],
      );
      await harness.load();
      await tester.pumpWidget(harness.wrap(const CalendarPage()));
      // 轮播是常驻 Timer，不能用 pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      String? label() => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('dayLabel-2026-05-10')),
              matching: find.byType(Text),
            ),
          )
          .data;

      final String first = label()!;
      expect(first, '母亲节');

      // 1 秒后轮到生日
      await tester.pump(const Duration(seconds: 1));
      final String second = label()!;
      expect(second, '张三');

      // 再过 1 秒又转回节日
      await tester.pump(const Duration(seconds: 1));
      expect(label(), first);

      // 收尾：把页面拆掉，避免 Timer 残留
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
