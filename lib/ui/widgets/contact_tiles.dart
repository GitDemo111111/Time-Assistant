import 'package:flutter/material.dart';

import '../../core/astrology.dart';
import '../../core/birthday_calculator.dart';
import '../../core/formatters.dart';
import '../../models/birthday.dart';
import '../../models/contact.dart';
import '../../theme/app_theme.dart';
import '../../theme/visuals.dart';
import 'common.dart';
import 'contact_avatar.dart';

/// 倒计时小标签，例如「3天后」。
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({
    super.key,
    required this.daysUntil,
    this.dense = false,
  });

  final int daysUntil;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = countdownColor(daysUntil, theme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppSizes.chipRadius),
      ),
      child: Text(
        relativeDayLabel(daysUntil),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: dense ? 11.5 : 12.5,
        ),
      ),
    );
  }
}

/// 「即将到来」列表里的卡片。
class UpcomingTile extends StatelessWidget {
  const UpcomingTile({super.key, required this.item, required this.onTap});

  final UpcomingBirthday item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Contact contact = item.contact;
    final bool isToday = item.isToday;

    return AppCard(
      onTap: onTap,
      color: isToday ? const Color(0xFFFFF1F5) : null,
      borderColor: isToday ? AppColors.celebrate.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          ContactAvatar(contact: contact, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (contact.favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFFFB020),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                // 日期一行、星座（和关系）另起一行：
                // 否则「农历9月25日 · 新历11月3日 · 天蝎座」会被折成「天蝎 / 座」。
                Text(
                  _dateLine(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_infoLine().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _infoLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CountdownBadge(daysUntil: item.daysUntil),
              if (item.turningAge != null) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  ageLabel(item.turningAge!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 第一行：日期。农历生日把「生日」和「今年落在新历哪天」都说清楚。
  String _dateLine() {
    final Birthday? birthday = item.contact.birthday;
    if (birthday?.isLunar == true) {
      return '农历${birthday!.month}月${birthday.day}日 · 新历${formatMonthDay(item.date)}';
    }
    return '新历${formatMonthDay(item.date)}';
  }

  /// 第二行：关系 + 星座（星座由生日自动算出来，不用用户填）。
  String _infoLine() {
    final List<String> parts = <String>[
      if (item.contact.relationshipLabel != null)
        item.contact.relationshipLabel!,
      constellationOf(item.date.month, item.date.day),
    ];
    return parts.where((String e) => e.isNotEmpty).join(' · ');
  }
}

/// 联系人列表里的行。
///
/// 和首页卡片用同一套文案规则：第一行日期（农历生日会同时标出新历哪天），
/// 第二行关系 · 星座。
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.daysUntil,
    this.turningAge,
    this.constellation,
    this.date,
  });

  final Contact contact;
  final VoidCallback onTap;
  final int? daysUntil;
  final int? turningAge;

  /// 由生日自动推导的星座（农历生日需要先换算成公历，由调用方传入）。
  final String? constellation;

  /// 下一次生日的公历日期（农历生日会换算出新历日期给用户看）。
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? relation = contact.relationshipLabel;
    final birthday = contact.birthday;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          ContactAvatar(contact: contact, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (contact.favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFFFB020),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _dateLine(birthday),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_infoLine(relation, birthday).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    _infoLine(relation, birthday),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (daysUntil != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CountdownBadge(daysUntil: daysUntil!, dense: true),
                if (turningAge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      ageLabel(turningAge!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }

  /// 第一行：日期。农历生日同时标出今年落在新历哪一天。
  String _dateLine(Birthday? birthday) {
    if (birthday == null) return '还没有填写生日';
    if (birthday.isLunar) {
      final String base = '农历${birthday.month}月${birthday.day}日';
      return date == null ? base : '$base · 新历${formatMonthDay(date!)}';
    }
    return '新历${birthday.month}月${birthday.day}日';
  }

  /// 第二行：关系 · 星座 · 爱好（有什么显示什么）。
  String _infoLine(String? relation, Birthday? birthday) {
    if (birthday == null) return '';
    return <String>[
      ?relation,
      ?constellation,
      if (contact.hobbies.isNotEmpty) contact.hobbies.take(2).join('/'),
    ].join(' · ');
  }
}
