/// 顶栏 UI
///
/// 显示游戏名称、金币、体力，半透明背景，高度 28px。
library;

import 'package:flutter/material.dart';

/// 顶栏组件。
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.gameName,
    required this.gold,
    required this.stamina,
    required this.maxStamina,
    this.level = 1,
    this.expProgress = 0,
    this.seasonLabel = '',
    this.dayLabel = '',
    this.timeLabel = '',
    this.locationLabel = '',
    this.onTapName,
  });

  /// 顶栏高度（像素）。
  static const double barHeight = 28;

  /// 半透明背景色。
  static const Color barBackground = Color(0x66000000);

  /// 游戏名称。
  final String gameName;

  /// 金币。
  final int gold;

  /// 当前体力。
  final int stamina;

  /// 体力上限。
  final int maxStamina;

  /// 等级。
  final int level;

  /// 经验进度 0~1。
  final double expProgress;

  /// 季节文案。
  final String seasonLabel;

  /// 日期文案。
  final String dayLabel;

  /// 时间文案。
  final String timeLabel;

  /// 当前地点文案。
  final String locationLabel;

  /// 点击游戏名称的回调（可用于打开菜单）。
  final VoidCallback? onTapName;

  /// 体力条颜色：充足为绿色，低于三成为红色。
  Color get _staminaColor {
    if (maxStamina <= 0) return Colors.white;
    final double ratio = stamina / maxStamina;
    if (ratio <= 0.3) return const Color(0xFFFF6B6B);
    if (ratio <= 0.6) return const Color(0xFFFFD166);
    return const Color(0xFF7BE495);
  }

  /// 体力比例 0~1。
  double get _staminaRatio =>
      maxStamina <= 0 ? 0 : _clamp01(stamina / maxStamina);

  static double _clamp01(double v) => v <= 0 ? 0 : (v >= 1 ? 1 : v);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      color: barBackground,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          // 游戏名称
          GestureDetector(
            onTap: onTapName,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.eco, size: 14, color: Color(0xFF9BE36B)),
                const SizedBox(width: 4),
                Text(
                  gameName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 等级与经验
          if (level > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Lv.$level',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 36,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _clamp01(expProgress),
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF9BE36B)),
                ),
              ),
            ),
          ],

          // 日期与时间
          if (seasonLabel.isNotEmpty || dayLabel.isNotEmpty || timeLabel.isNotEmpty) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              <String>[seasonLabel, dayLabel, timeLabel]
                  .where((String s) => s.isNotEmpty)
                  .join(' '),
              style: const TextStyle(color: Color(0xFFE8F4FF), fontSize: 10),
            ),
          ],

          const Spacer(),

          // 当前地点
          if (locationLabel.isNotEmpty) ...<Widget>[
            Text(
              locationLabel,
              style: const TextStyle(color: Color(0xFFD8E8FF), fontSize: 10),
            ),
            const SizedBox(width: 10),
          ],

          // 金币
          const Icon(Icons.monetization_on, size: 13, color: Color(0xFFFFE066)),
          const SizedBox(width: 3),
          Text(
            '$gold',
            style: const TextStyle(
              color: Color(0xFFFFE066),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 10),

          // 体力
          const Icon(Icons.bolt, size: 13, color: Color(0xFF7BE495)),
          const SizedBox(width: 3),
          Text(
            '$stamina/$maxStamina',
            style: TextStyle(
              color: _staminaColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _staminaRatio,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(_staminaColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
