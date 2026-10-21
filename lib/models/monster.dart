/// 怪物模型（7 种）
///
/// 7 种怪物分布在采矿 1-7 层，包含 HP、攻击、防御属性。
library;

import 'dart:math' as math;

/// 怪物静态配置。
class MonsterType {
  const MonsterType({
    required this.id,
    required this.name,
    required this.floor,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.expReward,
    required this.goldReward,
    required this.color,
    this.size = 26,
    this.dropItemId = '',
    this.dropRate = 0.0,
  });

  /// 唯一 ID。
  final String id;

  /// 名称。
  final String name;

  /// 主要出没的采矿层（1~7）。
  final int floor;

  /// 最大生命值。
  final int maxHp;

  /// 攻击力。
  final int attack;

  /// 防御力。
  final int defense;

  /// 击败后奖励经验。
  final int expReward;

  /// 击败后奖励金币。
  final int goldReward;

  /// 代表色（ARGB）。
  final int color;

  /// 绘制尺寸（像素）。
  final double size;

  /// 掉落物 ID（空字符串表示无掉落）。
  final String dropItemId;

  /// 掉落概率 0~1。
  final double dropRate;

  /// 按配置创建一个可战斗的怪物实例。
  Monster spawn({double? x, double? y}) => Monster(
        type: this,
        x: x ?? 0,
        y: y ?? 0,
      );

  @override
  String toString() => 'MonsterType($id, $name, F$floor)';
}

/// 怪物战斗实例（有当前 HP 与位置）。
class Monster {
  Monster({
    required this.type,
    this.x = 0,
    this.y = 0,
    int? hp,
  }) : hp = hp ?? type.maxHp;

  /// 静态配置。
  final MonsterType type;

  /// 世界坐标 X。
  final double x;

  /// 世界坐标 Y（脚底）。
  final double y;

  /// 当前生命值。
  int hp;

  /// 名称。
  String get name => type.name;

  /// 是否存活。
  bool get isAlive => hp > 0;

  /// 生命比例 0~1。
  double get hpRatio {
    if (type.maxHp <= 0) return 0;
    final double r = hp / type.maxHp;
    if (r <= 0) return 0;
    return r >= 1 ? 1 : r;
  }

  /// 受到伤害，返回实际扣除的血量。
  ///
  /// 伤害公式：`max(1, 玩家攻击 - 怪物防御)`，含 ±10% 浮动。
  int takeDamage(int playerAttack, [math.Random? rng]) {
    final math.Random r = rng ?? math.Random();
    final int base = math.max(1, playerAttack - type.defense);
    final double factor = 0.9 + r.nextDouble() * 0.2;
    final int dmg = math.max(1, (base * factor).round());
    hp = math.max(0, hp - dmg);
    return dmg;
  }

  /// 对玩家造成伤害，返回实际伤害值。
  ///
  /// 伤害公式：`max(1, 怪物攻击 - 玩家防御)`。
  int dealDamageTo(int playerDefense, [math.Random? rng]) {
    final math.Random r = rng ?? math.Random();
    final int base = math.max(1, type.attack - playerDefense);
    final double factor = 0.9 + r.nextDouble() * 0.2;
    return math.max(1, (base * factor).round());
  }

  /// 掷骰判断是否掉落物品。
  bool rollDrop([math.Random? rng]) {
    if (type.dropItemId.isEmpty || type.dropRate <= 0) return false;
    return (rng ?? math.Random()).nextDouble() < type.dropRate;
  }

  @override
  String toString() => 'Monster(${type.name}, hp=$hp/${type.maxHp})';
}

/// 战斗结算结果。
class BattleResult {
  const BattleResult({
    required this.playerWon,
    required this.damageDealt,
    required this.damageTaken,
    required this.expGain,
    required this.goldGain,
    required this.dropped,
  });

  /// 玩家是否获胜。
  final bool playerWon;

  /// 玩家造成的总伤害。
  final int damageDealt;

  /// 玩家承受的总伤害。
  final int damageTaken;

  /// 获得经验。
  final int expGain;

  /// 获得金币。
  final int goldGain;

  /// 掉落物 ID（空字符串表示无）。
  final String dropped;
}

/// 怪物配置总表（7 种，对应采矿 1-7 层）。
class MonsterData {
  MonsterData._();

  /// 全部怪物配置。
  static const List<MonsterType> all = <MonsterType>[
    MonsterType(
      id: 'slime', name: '绿史莱姆', floor: 1,
      maxHp: 30, attack: 6, defense: 1,
      expReward: 8, goldReward: 15, color: 0xFF6FBF5A, size: 24,
      dropItemId: 'slime_gel', dropRate: 0.4,
    ),
    MonsterType(
      id: 'bat', name: '洞穴蝙蝠', floor: 2,
      maxHp: 45, attack: 10, defense: 3,
      expReward: 14, goldReward: 26, color: 0xFF7A5C8A, size: 22,
      dropItemId: 'bat_wing', dropRate: 0.35,
    ),
    MonsterType(
      id: 'goblin', name: '矿石哥布林', floor: 3,
      maxHp: 70, attack: 16, defense: 6,
      expReward: 24, goldReward: 48, color: 0xFF6E9B4A, size: 28,
      dropItemId: 'copper_ore', dropRate: 0.5,
    ),
    MonsterType(
      id: 'skeleton', name: '骷髅兵', floor: 4,
      maxHp: 100, attack: 24, defense: 10,
      expReward: 38, goldReward: 75, color: 0xFFE8E4D8, size: 30,
      dropItemId: 'bone', dropRate: 0.45,
    ),
    MonsterType(
      id: 'spider', name: '岩洞巨蛛', floor: 5,
      maxHp: 140, attack: 32, defense: 14,
      expReward: 56, goldReward: 110, color: 0xFF4A3B52, size: 32,
      dropItemId: 'silk', dropRate: 0.5,
    ),
    MonsterType(
      id: 'golem', name: '岩石魔像', floor: 6,
      maxHp: 220, attack: 44, defense: 26,
      expReward: 88, goldReward: 180, color: 0xFF8A7C6A, size: 38,
      dropItemId: 'iron_ore', dropRate: 0.6,
    ),
    MonsterType(
      id: 'dragon', name: '幼龙', floor: 7,
      maxHp: 400, attack: 68, defense: 38,
      expReward: 200, goldReward: 420, color: 0xFFC0392B, size: 44,
      dropItemId: 'dragon_scale', dropRate: 0.75,
    ),
  ];

  static final Map<String, MonsterType> _byId = <String, MonsterType>{
    for (final MonsterType m in all) m.id: m,
  };

  /// 怪物种类数，应为 7。
  static int get count => all.length;

  /// 按 ID 查找，找不到返回 null。
  static MonsterType? byId(String id) => _byId[id];

  /// 指定楼层出现的怪物（每层为对应层的怪物 + 低层怪物的少量混入）。
  static List<MonsterType> onFloor(int floor) =>
      all.where((MonsterType m) => m.floor == floor).toList();

  /// 指定楼层可能遇到的全部怪物（含低层）。
  static List<MonsterType> encounterableOn(int floor) =>
      all.where((MonsterType m) => m.floor <= floor).toList();

  /// 全部怪物 ID 列表（供任务系统使用）。
  static List<String> get ids =>
      all.map((MonsterType m) => m.id).toList(growable: false);

  /// 回合制战斗结算。
  ///
  /// 玩家先手，双方轮流攻击直到一方倒下；[maxRounds] 用于防止无限循环，
  /// 超过回合数视为玩家失败（撤退）。
  static BattleResult resolveBattle(
    Monster monster, {
    required int playerAttack,
    required int playerHp,
    int playerDefense = 0,
    int maxRounds = 50,
    math.Random? rng,
  }) {
    final math.Random r = rng ?? math.Random();
    int hp = playerHp;
    int dealt = 0;
    int taken = 0;

    for (int round = 0; round < maxRounds; round++) {
      dealt += monster.takeDamage(playerAttack, r);
      if (!monster.isAlive) {
        return BattleResult(
          playerWon: true,
          damageDealt: dealt,
          damageTaken: taken,
          expGain: monster.type.expReward,
          goldGain: monster.type.goldReward,
          dropped: monster.rollDrop(r) ? monster.type.dropItemId : '',
        );
      }
      final int incoming = monster.dealDamageTo(playerDefense, r);
      taken += incoming;
      hp -= incoming;
      if (hp <= 0) break;
    }

    return BattleResult(
      playerWon: false,
      damageDealt: dealt,
      damageTaken: taken,
      expGain: 0,
      goldGain: 0,
      dropped: '',
    );
  }
}
