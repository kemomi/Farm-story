/// 底栏 UI
///
/// 包含锄地、播种、浇水、工具、NPC、背包六个按钮，半透明背景，高度 44px。
library;

import 'package:flutter/material.dart';

/// 底栏工具类型。
enum ToolType {
  hoe('锄地', Icons.agriculture),
  seed('播种', Icons.grass),
  water('浇水', Icons.water),
  tool('工具', Icons.build),
  npc('NPC', Icons.people),
  bag('背包', Icons.backpack);

  const ToolType(this.label, this.icon);

  /// 中文名称。
  final String label;

  /// 图标。
  final IconData icon;
}

/// 底栏组件。
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.badges = const <ToolType, String>{},
    this.hint = '',
  });

  /// 底栏高度（像素）。
  static const double barHeight = 44;

  /// 半透明背景色。
  static const Color barBackground = Color(0x66000000);

  /// 选中态高亮色。
  static const Color selectedColor = Color(0xFF9BE36B);

  /// 当前选中的工具。
  final ToolType? selected;

  /// 按钮点击回调。
  final ValueChanged<ToolType> onSelected;

  /// 是否可交互。
  final bool enabled;

  /// 按钮角标文案（如背包物品数、可收获数）。
  final Map<ToolType, String> badges;

  /// 底部提示文案。
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      color: barBackground,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          for (final ToolType t in ToolType.values) ...<Widget>[
            Expanded(
              child: _BarButton(
                type: t,
                selected: selected == t,
                enabled: enabled,
                badge: badges[t],
                onTap: () => onSelected(t),
              ),
            ),
            if (t != ToolType.values.last) const SizedBox(width: 6),
          ],
          if (hint.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hint,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE8F4FF), fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个底栏按钮。
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final ToolType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final Color fg = !enabled
        ? const Color(0x66FFFFFF)
        : selected
            ? BottomBar.selectedColor
            : Colors.white;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0x33FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: BottomBar.selectedColor, width: 1)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(type.icon, size: 16, color: fg),
                const SizedBox(height: 2),
                Text(
                  type.label,
                  style: TextStyle(color: fg, fontSize: 10),
                ),
              ],
            ),
            if (badge != null && badge!.isNotEmpty)
              Positioned(
                right: 4,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  constraints: const BoxConstraints(minWidth: 14),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
