import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_x.dart';
import '../../core/festivals.dart';
import '../../core/formatters.dart';
import '../../core/holidays.dart';
import '../../core/lunar_converter.dart';
import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// 「日历」页：月历 + 假期倒计时 + 即将到来的节日。
///
/// 「今天」一律取自 [ContactController.now]，页面里不直接调用 `DateTime.now`，
/// 这样测试可以固定住时间。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// 正在展示的月份（只用到年月）。null 表示「还没翻过月」，跟随今天。
  DateTime? _visibleMonth;

  /// 选中的日期。null 表示跟随今天。
  DateTime? _selectedDay;

  /// 把「当前展示的月份」前后挪 [delta] 个月。
  void _shiftMonth({
    required DateTime visible,
    required DateTime today,
    required int delta,
  }) {
    final DateTime next = DateTime(visible.year, visible.month + delta, 1);
    setState(() {
      _visibleMonth = next;
      final DateTime selected = _selectedDay ?? today;
      // 选中日不在新月份里时，把焦点挪到新月份的第一天，
      // 免得下面的信息行还在讲上个月的日期。
      if (selected.year != next.year || selected.month != next.month) {
        _selectedDay = next;
      }
    });
  }

  void _goToday() {
    setState(() {
      _visibleMonth = null;
      _selectedDay = null;
    });
  }

  void _select(DateTime day) => setState(() => _selectedDay = day);

  _DayInfo _infoFor(DateTime day, LunarConverter lunar) => _DayInfo(
    festivals: festivalsOnDate(day, lunar),
    holiday: holidayOn(day, lunar),
    makeUpWorkday: makeUpWorkdayOn(day, lunar),
  );

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final DateTime today = dateOnly(controller.now);
    final DateTime visible = _visibleMonth ?? DateTime(today.year, today.month);
    final DateTime selected = _selectedDay ?? today;
    final LunarConverter lunar = controller.calculator.lunarConverter;

    final List<HolidayCountdown> holidays = upcomingHolidays(
      controller.now,
      limit: 4,
      lunar: lunar,
    );
    final List<FestivalOccurrence> festivals = upcomingFestivals(
      controller.now,
      limit: 8,
      lunar: lunar,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _MonthHeader(
                      month: visible,
                      onPrev: () => _shiftMonth(
                        visible: visible,
                        today: today,
                        delta: -1,
                      ),
                      onNext: () =>
                          _shiftMonth(visible: visible, today: today, delta: 1),
                      onToday: _goToday,
                    ),
                    const SizedBox(height: 6),
                    const _WeekdayHeader(),
                    const SizedBox(height: 4),
                    _MonthGrid(
                      month: visible,
                      today: today,
                      selected: selected,
                      infoFor: (DateTime day) => _infoFor(day, lunar),
                      onSelect: _select,
                    ),
                    const SizedBox(height: 10),
                    const _Legend(),
                    const SizedBox(height: 12),
                    _SelectedDayInfo(
                      key: const Key('selectedDayInfo'),
                      day: selected,
                      isToday: selected == today,
                      info: _infoFor(selected, lunar),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SectionHeader(
                    title: '假期倒计时',
                    subtitle: holidays.isEmpty
                        ? null
                        : '接下来 ${holidays.length} 个假期',
                  ),
                  if (holidays.isEmpty)
                    const EmptyState(
                      icon: Icons.beach_access_outlined,
                      title: '暂时没有假期',
                      message: '等国务院办公厅公布下一年的放假安排。',
                    )
                  else
                    for (int i = 0; i < holidays.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HolidayCard(
                          item: holidays[i],
                          highlighted: i == 0,
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(title: '即将到来的节日', subtitle: '点一条看看有什么讲究'),
                  for (final FestivalOccurrence occurrence in festivals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FestivalRow(
                        occurrence: occurrence,
                        onTap: () => showAppSnackBar(
                          context,
                          occurrence.festival.hint ??
                              '${occurrence.festival.name} '
                                  '${formatMonthDay(occurrence.date)}。',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 某一天的节日 / 假期信息。
class _DayInfo {
  const _DayInfo({required this.festivals, this.holiday, this.makeUpWorkday});

  final List<Festival> festivals;

  /// 当天放假的假期。
  final Holiday? holiday;

  /// 当天是某个假期的调休上班日。
  final Holiday? makeUpWorkday;

  bool get isEmpty =>
      festivals.isEmpty && holiday == null && makeUpWorkday == null;
}

/// 月份标题 + 上/下个月 + 回到今天。
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          key: const Key('prevMonthButton'),
          tooltip: '上个月',
          visualDensity: VisualDensity.compact,
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${month.year}年${month.month}月',
              key: const Key('monthLabel'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        TextButton(
          key: const Key('todayButton'),
          onPressed: onToday,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
          child: const Text(
            '回今天',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          key: const Key('nextMonthButton'),
          tooltip: '下个月',
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// 星期表头：一周从周一开始。
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < _labels.length; i++)
          Expanded(
            child: Center(
              child: Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: i >= 5 ? AppColors.brand : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 一个月的日期格子。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.infoFor,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final _DayInfo Function(DateTime day) infoFor;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = daysInSolarMonth(month.year, month.month);
    // 周一是一周的第一天，所以 1 号前面要空出 `leading` 个格子。
    final int leading = DateTime(month.year, month.month, 1).weekday - 1;
    final int rowCount = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: <Widget>[
        for (int row = 0; row < rowCount; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(row * 7 + col, leading, daysInMonth),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int index, int leading, int daysInMonth) {
    final int dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: _DayCell.height);
    }
    final DateTime day = DateTime(month.year, month.month, dayNumber);
    return _DayCell(
      day: day,
      info: infoFor(day),
      isToday: day == today,
      isSelected: day == selected,
      onTap: () => onSelect(day),
    );
  }
}

/// 单个日期格子：数字 + 节日 / 假期小圆点。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.info,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  static const double height = 56;

  final DateTime day;
  final _DayInfo info;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool weekend = day.weekday >= DateTime.saturday;
    final Color numberColor = isToday
        ? Colors.white
        : (weekend ? AppColors.brand : AppColors.textPrimary);

    return SizedBox(
      height: height,
      child: InkWell(
        key: Key('dayCell-${formatIsoDate(day)}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.brand
                    : (isSelected ? AppColors.brandSoft : null),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.1,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: numberColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(height: 6, child: _dots()),
          ],
        ),
      ),
    );
  }

  /// 节日 / 假期 / 调休各一个小圆点，最多三个。
  Widget _dots() {
    final List<Color> colors = <Color>[
      if (info.holiday != null) AppColors.celebrate,
      for (final Festival _ in info.festivals) AppColors.accent,
      if (info.makeUpWorkday != null) AppColors.warning,
    ];
    if (colors.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < colors.length && i < 3; i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
          ),
      ],
    );
  }
}

/// 小圆点图例。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        _LegendItem(color: AppColors.celebrate, label: '放假'),
        _LegendItem(color: AppColors.accent, label: '节日'),
        _LegendItem(color: AppColors.warning, label: '调休上班'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 选中日期的信息行。
class _SelectedDayInfo extends StatelessWidget {
  const _SelectedDayInfo({
    super.key,
    required this.day,
    required this.isToday,
    required this.info,
  });

  final DateTime day;
  final bool isToday;
  final _DayInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                formatFullDateWithWeekday(day),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isToday) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppSizes.chipRadius),
                  ),
                  child: const Text(
                    '今天',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (info.isEmpty)
            const Text(
              '这一天没有节日或假期安排',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            )
          else ...<Widget>[
            for (final Festival festival in info.festivals)
              _InfoLine(
                emoji: festival.emoji,
                title: festival.name,
                detail: festival.hint,
              ),
            if (info.holiday != null)
              _InfoLine(
                emoji: info.holiday!.emoji,
                title: '${info.holiday!.name}假期',
                detail:
                    '${info.holiday!.rangeLabel} · 共 ${info.holiday!.days} 天',
                color: AppColors.celebrate,
              ),
            if (info.makeUpWorkday != null)
              _InfoLine(
                emoji: '💼',
                title: '${info.makeUpWorkday!.name}调休上班',
                detail: '这天要上班，记得定闹钟。',
                color: AppColors.warning,
              ),
          ],
        ],
      ),
    );
  }
}

/// 信息行里的一行：表情 + 名称 + 说明。
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.emoji,
    required this.title,
    this.detail,
    this.color,
  });

  final String emoji;
  final String title;
  final String? detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.textPrimary,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 假期倒计时卡片。
class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.item, required this.highlighted});

  final HolidayCountdown item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Holiday holiday = item.holiday;
    return AppCard(
      key: Key('holidayCard-${holiday.id}'),
      color: highlighted ? AppColors.brandSoft : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _EmojiBadge(emoji: holiday.emoji),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      holiday.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSizes.chipRadius,
                        ),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Text(
                        item.countdownLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      holiday.rangeLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${holiday.days} 天',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!holiday.isOfficial) ...<Widget>[
                  const SizedBox(height: 6),
                  const Text(
                    '以国务院通知为准',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「即将到来的节日」里的一行。
class _FestivalRow extends StatelessWidget {
  const _FestivalRow({required this.occurrence, required this.onTap});

  final FestivalOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Festival festival = occurrence.festival;
    return AppCard(
      key: Key('festivalRow-${festival.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          _EmojiBadge(emoji: festival.emoji, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  festival.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMonthDay(occurrence.date)} · '
                  '${weekdayLabel(occurrence.date)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            occurrence.countdownLabel,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片左侧的表情小方块。
class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.emoji, this.size = 44});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
    );
  }
}
