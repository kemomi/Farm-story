/// 玩家模型
///
/// 包含位置、移动目标、金币、体力、等级。支持移动插值更新、金币增减。
/// 坐标为世界坐标（像素），由 [Camera] 转换为屏幕坐标。
library;

import 'dart:math' as math;

/// 玩家朝向。
enum Facing { left, right }

/// 玩家当前动作状态，用于渲染与输入判定。
enum PlayerAction { idle, walking, hoeing, planting, harvesting }

/// 升级所需经验的基础公式参数。
const int _expBase = 100;
const double _expGrowth = 1.35;

/// 玩家实体。
class Player {
  Player({
    this.x = 0,
    this.y = 0,
    this.gold = 500,
    this.stamina = 100,
    this.maxStamina = 100,
    this.level = 1,
    this.exp = 0,
    this.name = '玩家',
  });

  /// 世界坐标 X（脚底中心）。
  double x;

  /// 世界坐标 Y（脚底）。
  double y;

  /// 金币。
  int gold;

  /// 当前体力。
  int stamina;

  /// 体力上限。
  int maxStamina;

  /// 等级。
  int level;

  /// 当前等级已累计经验。
  int exp;

  /// 名称。
  String name;

  /// 移动目标 X，为 null 表示已到达/未指定。
  double? targetX;

  /// 移动目标 Y。
  double? targetY;

  /// 朝向。
  Facing facing = Facing.right;

  /// 当前动作。
  PlayerAction action = PlayerAction.idle;

  /// 动作剩余时间（秒），用于播放动画。
  double actionTimer = 0;

  /// 移动速度（像素/秒）。
  double speed = 180;

  /// 行走动画累计时间，用于驱动帧切换。
  double walkCycle = 0;

  /// 角色宽度（像素），用于碰撞与点击判定。
  static const double width = 28;

  /// 角色高度（像素）。
  static const double height = 44;

  /// 到达判定阈值（像素）。
  static const double arriveEpsilon = 2.0;

  // ------------------------------------------------------------------ 经验等级

  /// 升到下一级所需总经验。
  int get expToNext => (_expBase * math.pow(_expGrowth, level - 1)).round();

  /// 等级进度 0~1。
  double get expProgress =>
      expToNext <= 0 ? 0 : (exp / expToNext).clamp(0.0, 1.0).toDouble();

  /// 增加经验，返回本次提升的等级数。
  int gainExp(int amount) {
    if (amount <= 0) return 0;
    exp += amount;
    int levels = 0;
    while (exp >= expToNext) {
      exp -= expToNext;
      level++;
      levels++;
      maxStamina += 10;
      stamina = maxStamina;
    }
    return levels;
  }

  // ------------------------------------------------------------------ 金币体力

  /// 增加金币（金额需为正数），返回是否成功。
  bool addGold(int amount) {
    if (amount <= 0) return false;
    gold += amount;
    return true;
  }

  /// 消费金币，余额不足返回 false 且不扣款。
  bool spendGold(int amount) {
    if (amount < 0 || gold < amount) return false;
    gold -= amount;
    return true;
  }

  /// 是否买得起。
  bool canAfford(int amount) => amount >= 0 && gold >= amount;

  /// 恢复体力，自动截断到上限，返回实际恢复量。
  int restoreStamina(int amount) {
    if (amount <= 0) return 0;
    final int before = stamina;
    stamina = math.min(maxStamina, stamina + amount);
    return stamina - before;
  }

  /// 消耗体力，体力不足返回 false（不执行扣除）。
  bool useStamina(int amount) {
    if (amount < 0 || stamina < amount) return false;
    stamina -= amount;
    return true;
  }

  /// 体力是否耗尽。
  bool get isExhausted => stamina <= 0;

  /// 体力比例 0~1，用于 UI 进度条。
  double get staminaRatio => maxStamina <= 0
      ? 0
      : (stamina / maxStamina).clamp(0.0, 1.0).toDouble();

  // ------------------------------------------------------------------ 移动

  /// 是否正在移动。
  bool get isMoving => targetX != null;

  /// 设置移动目标。目标点会被限制在 [minX, maxX] 范围内。
  void moveTo(double tx, double ty, {double minX = -1e9, double maxX = 1e9}) {
    targetX = tx.clamp(minX, maxX).toDouble();
    targetY = ty;
    facing = tx >= x ? Facing.right : Facing.left;
    action = PlayerAction.walking;
  }

  /// 立即停止移动。
  void stopMoving() {
    targetX = null;
    targetY = null;
    if (action == PlayerAction.walking) action = PlayerAction.idle;
  }

  /// 与目标点的水平距离，未设置目标返回 0。
  double get distanceToTarget =>
      targetX == null ? 0 : (targetX! - x).abs();

  /// 帧更新：移动插值 + 动作计时。
  ///
  /// [dt] 为距上一帧的秒数，返回本帧是否发生了位移。
  bool update(double dt) {
    if (dt <= 0) return false;

    if (actionTimer > 0) {
      actionTimer -= dt;
      if (actionTimer <= 0) {
        actionTimer = 0;
        action = isMoving ? PlayerAction.walking : PlayerAction.idle;
      }
    }

    final double? tx = targetX;
    if (tx == null) {
      walkCycle = 0;
      return false;
    }

    final double dx = tx - x;
    final double dist = dx.abs();
    if (dist <= arriveEpsilon) {
      x = tx;
      y = targetY ?? y;
      stopMoving();
      walkCycle = 0;
      return true;
    }

    final double step = speed * dt;
    if (step >= dist) {
      x = tx;
      y = targetY ?? y;
      stopMoving();
      walkCycle = 0;
    } else {
      x += dx.isNegative ? -step : step;
      final double? ty = targetY;
      if (ty != null) {
        // 纵向按同比例插值，保证斜向移动平滑。
        final double ratio = step / dist;
        y += (ty - y) * ratio;
      }
      facing = dx.isNegative ? Facing.left : Facing.right;
      action = PlayerAction.walking;
      walkCycle += dt;
    }
    return true;
  }

  /// 播放一次动作动画（锄地/播种/收获）。
  void playAction(PlayerAction act, {double duration = 0.4}) {
    action = act;
    actionTimer = duration;
  }

  /// 玩家占据的矩形（世界坐标，左上角原点）。
  math.Rectangle<double> get bounds => math.Rectangle<double>(
        x - width / 2,
        y - height,
        width,
        height,
      );

  /// 与某个世界坐标点是否足够近（用于交互判定）。
  bool isNear(double px, double py, {double tolerance = 40}) =>
      (px - x).abs() <= tolerance && (py - y).abs() <= tolerance;

  @override
  String toString() =>
      'Player(lv$level, gold=$gold, stamina=$stamina/$maxStamina, '
      'pos=(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}))';
}
