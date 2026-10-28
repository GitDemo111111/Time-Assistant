import 'package:birthday_keeper/app.dart';
import 'package:birthday_keeper/core/festivals.dart';
import 'package:birthday_keeper/ui/pages/calendar_page.dart';
import 'package:birthday_keeper/ui/widgets/common.dart';
import 'package:birthday_keeper/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  /// 装上「日历」页（时间固定为 kNow = 2026-05-20）。
  Future<TestHarness> pumpCalendar(WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await tester.pumpWidget(
      harness.wrap(const CalendarPage(autoRotate: false)),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> tapNextMonth(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nextMonthButton')));
    await tester.pumpAndSettle();
  }

  Future<void> tapPrevMonth(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('prevMonthButton')));
    await tester.pumpAndSettle();
  }

  widgetTest('月历表头显示当前月份，星期表头从周一排到周日', (WidgetTester tester) async {
    await pumpCalendar(tester);

    expect(find.text('2026年5月'), findsOneWidget);
    for (final String label in <String>['一', '二', '三', '四', '五', '六', '日']) {
      expect(find.text(label), findsOneWidget);
    }
    // 5 月 20 日（kNow 的当天）在格子里
    expect(find.byKey(const Key('dayCell-2026-05-20')), findsOneWidget);
    expect(find.byKey(const Key('dayCell-2026-05-01')), findsOneWidget);
    expect(find.byKey(const Key('dayCell-2026-05-31')), findsOneWidget);
    // 6 月 1 日不属于 5 月
    expect(find.byKey(const Key('dayCell-2026-06-01')), findsNothing);
  });

  widgetTest('上/下个月按钮会切换月份，可以跨年', (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tapNextMonth(tester);
    expect(find.text('2026年6月'), findsOneWidget);
    expect(find.text('2026年5月'), findsNothing);

    await tapPrevMonth(tester);
    expect(find.text('2026年5月'), findsOneWidget);

    await tapPrevMonth(tester);
    expect(find.text('2026年4月'), findsOneWidget);

    // 再退 8 个月，跨到 2025 年
    for (int i = 0; i < 8; i++) {
      await tapPrevMonth(tester);
    }
    expect(find.text('2025年8月'), findsOneWidget);

    // 「回今天」回到 kNow 所在的月份
    await tester.tap(find.byKey(const Key('todayButton')));
    await tester.pumpAndSettle();
    expect(find.text('2026年5月'), findsOneWidget);
  });

  widgetTest('点击 2026-06-19 显示端午节和当天假期', (WidgetTester tester) async {
    await pumpCalendar(tester);
    await tapNextMonth(tester);

    await tester.tap(find.byKey(const Key('dayCell-2026-06-19')));
    await tester.pumpAndSettle();

    final Finder info = find.byKey(const Key('selectedDayInfo'));
    expect(info, findsOneWidget);
    expect(
      find.descendant(of: info, matching: find.text('2026年6月19日 周五')),
      findsOneWidget,
    );
    // 农历五月初五：既是节日，也在端午节的放假区间里
    expect(
      find.descendant(of: info, matching: find.text('端午节')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.text('端午节假期')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.textContaining('共 3 天')),
      findsOneWidget,
    );
  });

  widgetTest('没有节日安排的日期会说明「这一天没有节日或假期安排」', (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byKey(const Key('dayCell-2026-05-13')));
    await tester.pumpAndSettle();

    final Finder info = find.byKey(const Key('selectedDayInfo'));
    expect(
      find.descendant(of: info, matching: find.text('这一天没有节日或假期安排')),
      findsOneWidget,
    );
  });

  widgetTest('默认选中今天，并在信息行里标出「今天」', (WidgetTester tester) async {
    await pumpCalendar(tester);

    final Finder info = find.byKey(const Key('selectedDayInfo'));
    expect(
      find.descendant(of: info, matching: find.text('2026年5月20日 周三')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.text('今天')),
      findsOneWidget,
    );
  });

  widgetTest('假期倒计时第一条是端午节：还有 30 天、6月19日 – 21日、共 3 天', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester);

    expect(find.text('假期倒计时'), findsOneWidget);

    final Finder first = find.byKey(const Key('holidayCard-2026_dragon_boat'));
    expect(first, findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.text('端午节')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('还有 30 天')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('6月19日 – 21日')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('共 3 天')),
      findsOneWidget,
    );
    // 第一条高亮
    expect(tester.widget<AppCard>(first).color, AppColors.brandSoft);

    // 未公布年份的估算只在列表底部统一声明一次，不再每张卡片重复
    expect(find.text('注：未公布年份的放假天数为估算，实际以国务院办公厅通知为准。'), findsOneWidget);
    expect(find.byKey(const Key('holidayCard-2027_new_year')), findsOneWidget);
    expect(find.text('以国务院通知为准'), findsNothing);
    // 官方数据的卡片不加这句话
    expect(
      find.descendant(of: first, matching: find.text('以国务院通知为准')),
      findsNothing,
    );
  });

  widgetTest('即将到来的节日按日期排序，第一条是儿童节', (WidgetTester tester) async {
    await pumpCalendar(tester);

    expect(find.text('即将到来的节日'), findsOneWidget);
    final List<FestivalOccurrence> expected = upcomingFestivals(kNow, limit: 8);
    expect(expected.first.festival.name, '儿童节');
    for (final FestivalOccurrence occurrence in expected) {
      expect(
        find.byKey(Key('festivalRow-${occurrence.festival.id}')),
        findsOneWidget,
      );
    }
  });

  widgetTest('点节日会弹出它的说明', (WidgetTester tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byKey(const Key('festivalRow-dragon_boat')));
    await tester.pumpAndSettle();

    expect(find.text('农历五月初五，法定节假日。'), findsOneWidget);

    // 等 SnackBar 自己消失，避免测试结束时还挂着定时器
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  widgetTest('底部导航多了「日历」标签，点进去就是日历页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await tester.pumpWidget(
      BirthdayKeeperApp(
        contactController: harness.contactController,
        settingsController: harness.settingsController,
      ),
    );
    await tester.pumpAndSettle();

    final Finder tab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('日历'),
    );
    expect(tab, findsOneWidget);

    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.text('2026年5月'), findsOneWidget);
    expect(find.text('假期倒计时'), findsOneWidget);
  });
}
