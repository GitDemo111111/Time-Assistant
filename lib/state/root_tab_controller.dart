import 'package:flutter/foundation.dart';

/// 底部导航当前选中的页面。
///
/// 单独抽出来是为了让别处也能主动切标签 —— 例如「保存联系人」之后
/// 自动回到「联系人」页。
///
/// 顺序（用户要求）：**日历**在最左边；「即将到来」和「联系人」已经合并成
/// 同一页，所以只剩三个标签。
class RootTabController extends ChangeNotifier {
  static const int calendarTab = 0;

  /// 合并后的「联系人」页（含即将到来的倒计时列表）。
  static const int contactsTab = 1;

  /// 兼容旧名字：合并后「即将到来」就是「联系人」页。
  static const int upcomingTab = contactsTab;

  static const int settingsTab = 2;

  int _index = calendarTab;

  int get index => _index;

  void goTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  /// 切到「联系人」页（保存 / 导入之后统一回到这里）。
  void goToContacts() => goTo(contactsTab);

  /// 切到「日历」页。
  void goToCalendar() => goTo(calendarTab);
}
