import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/ui/pages/contact_detail_page.dart';
import 'package:birthday_keeper/ui/pages/upcoming_page.dart';
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
}
