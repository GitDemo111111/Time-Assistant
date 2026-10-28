import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../pages/contact_import_page.dart';
import 'forms.dart';

/// 搜索 + 从文本导入 + 爱好筛选按钮。
///
/// 「即将到来」和「联系人」合并成一个页面后，这一条被放在页面顶部。
class ContactFilterBar extends StatelessWidget {
  const ContactFilterBar({super.key, required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            key: const Key('searchField'),
            onChanged: controller.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索姓名、关系、爱好、备注…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => controller.setQuery(''),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const Key('importFromTextButton'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const ContactImportPage(),
            ),
          ),
          icon: const Icon(Icons.content_paste_go_rounded),
          tooltip: '从文本导入',
        ),
        const SizedBox(width: 8),
        _FilterButton(controller: controller),
      ],
    );
  }
}

/// 关系 / 星标筛选横向 chip 条。
class ContactFilterChips extends StatelessWidget {
  const ContactFilterChips({super.key, required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final List<FilterOption> relations = controller.relationshipFacets;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          SelectableChip(
            key: const Key('favoriteFilterChip'),
            label: '星标',
            icon: Icons.star_rounded,
            dense: true,
            selected: controller.favoritesOnly,
            onTap: () => controller.setFavoritesOnly(!controller.favoritesOnly),
          ),
          const SizedBox(width: 8),
          for (final FilterOption option in relations) ...<Widget>[
            SelectableChip(
              key: Key('relationFilter-${option.relationshipGroup?.name}'),
              label: '${option.label} ${option.count}',
              dense: true,
              selected:
                  controller.relationshipFilter == option.relationshipGroup,
              onTap: () {
                // 再点一次同样的关系就取消筛选
                controller.setRelationshipFilter(
                  controller.relationshipFilter == option.relationshipGroup
                      ? null
                      : option.relationshipGroup,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          if (controller.hasActiveFilters)
            SelectableChip(
              label: '清除',
              icon: Icons.close_rounded,
              dense: true,
              selected: false,
              onTap: controller.clearFilters,
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final int active = controller.hobbyFilters.length;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton.filledTonal(
          key: const Key('hobbyFilterButton'),
          onPressed: () => _openSheet(context),
          icon: const Icon(Icons.tune_rounded),
          tooltip: '按爱好筛选',
        ),
        if (active > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.celebrate,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$active',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) =>
          ChangeNotifierProvider<ContactController>.value(
            value: controller,
            child: const _HobbyFilterSheet(),
          ),
    );
  }
}

class _HobbyFilterSheet extends StatelessWidget {
  const _HobbyFilterSheet();

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();
    final List<FilterOption> hobbies = controller.hobbyFacets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '按爱好筛选',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '可以多选，只会显示同时包含这些爱好的联系人',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (hobbies.isEmpty)
            const Text(
              '还没有人填写爱好',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final FilterOption option in hobbies)
                  SelectableChip(
                    key: Key('hobbyFilter-${option.label}'),
                    label: '${option.label} ${option.count}',
                    dense: true,
                    selected: controller.hobbyFilters.contains(option.label),
                    onTap: () => controller.toggleHobbyFilter(option.label),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.hobbyFilters.isEmpty
                      ? null
                      : () => controller.clearFilters(),
                  child: const Text('清除全部筛选'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
