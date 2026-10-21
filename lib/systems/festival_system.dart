/// 祭典系统（7 个）
///
/// 按季节和日期触发，包含庆典、比赛、集市类型，支持参与条件和奖励。
library;

import '../data/crops_data.dart';

/// 祭典类型。
enum FestivalType {
  celebration('庆典'),
  contest('比赛'),
  market('集市');

  const FestivalType(this.label);

  /// 中文名称。
  final String label;
}

/// 祭典参与结果。
class FestivalResult {
  const FestivalResult({
    required this.allowed,
    required this.message,
    this.goldReward = 0,
    this.expReward = 0,
    this.staminaReward = 0,
    this.affinityReward = 0,
    this.itemReward = '',
  });

  /// 成功参与。
  const FestivalResult.ok(
    String message, {
    int goldReward = 0,
    int expReward = 0,
    int staminaReward = 0,
    int affinityReward = 0,
    String itemReward = '',
  }) : this(
          allowed: true,
          message: message,
          goldReward: goldReward,
          expReward: expReward,
          staminaReward: staminaReward,
          affinityReward: affinityReward,
          itemReward: itemReward,
        );

  /// 无法参与。
  const FestivalResult.deny(String message)
      : this(allowed: false, message: message);

  /// 是否允许参与。
  final bool allowed;

  /// 提示文案。
  final String message;

  /// 金币奖励。
  final int goldReward;

  /// 经验奖励。
  final int expReward;

  /// 体力奖励。
  final int staminaReward;

  /// 全员好感度奖励。
  final int affinityReward;

  /// 物品奖励 ID（空表示无）。
  final String itemReward;
}

/// 单个祭典的静态配置。
class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.season,
    required this.day,
    required this.type,
    required this.description,
    required this.minLevel,
    required this.staminaCost,
    required this.goldReward,
    required this.expReward,
    required this.staminaReward,
    required this.affinityReward,
    this.requiredItemId = '',
    this.itemReward = '',
    this.location = '村庄广场',
  });

  /// 唯一 ID。
  final String id;

  /// 祭典名称。
  final String name;

  /// 所属季节。
  final Season season;

  /// 触发日（1~28）。
  final int day;

  /// 祭典类型。
  final FestivalType type;

  /// 描述文案。
  final String description;

  /// 参与所需最低等级。
  final int minLevel;

  /// 参与消耗体力（0 表示不消耗）。
  final int staminaCost;

  /// 金币奖励。
  final int goldReward;

  /// 经验奖励。
  final int expReward;

  /// 体力奖励（庆典通常会恢复体力）。
  final int staminaReward;

  /// 参与后全员好感度增加量。
  final int affinityReward;

  /// 参与所需携带的物品 ID（空表示无要求）。
  final String requiredItemId;

  /// 物品奖励 ID（空表示无）。
  final String itemReward;

  /// 举办地点。
  final String location;

  /// 是否在今天举行。
  bool occursOn(Season s, int d) => season == s && day == d;

  @override
  String toString() => 'Festival($id, $name, ${season.label}$day日)';
}

/// 祭典系统。
class FestivalSystem {
  FestivalSystem();

  /// 每季天数。
  static const int daysPerSeason = 28;

  /// 7 个祭典配置。
  static const List<Festival> all = <Festival>[
    Festival(
      id: 'spring_flower', name: '花之祭', season: Season.spring, day: 8,
      type: FestivalType.celebration,
      description: '春暖花开，村民在广场举办花车游行，赠送花种与祝福。',
      minLevel: 1, staminaCost: 0,
      goldReward: 100, expReward: 30, staminaReward: 20, affinityReward: 15,
      itemReward: 'flower_seed',
    ),
    Festival(
      id: 'summer_fishing', name: '钓鱼大赛', season: Season.summer, day: 12,
      type: FestivalType.contest,
      description: '玛雅主持的夏季垂钓比赛，钓到大鱼可获得高额奖金。',
      minLevel: 3, staminaCost: 20,
      goldReward: 600, expReward: 80, staminaReward: 0, affinityReward: 10,
      requiredItemId: 'fish_big', itemReward: 'golden_rod',
    ),
    Festival(
      id: 'summer_market', name: '海滨夜市', season: Season.summer, day: 24,
      type: FestivalType.market,
      description: '夏季夜晚的露天集市，摊贩云集，可低价购入稀有种子。',
      minLevel: 2, staminaCost: 10,
      goldReward: 150, expReward: 40, staminaReward: 10, affinityReward: 8,
      itemReward: 'rare_seed_pack',
    ),
    Festival(
      id: 'autumn_harvest', name: '丰收祭', season: Season.autumn, day: 16,
      type: FestivalType.celebration,
      description: '一年中最重要的庆典，村民分享收成，评选最好的红薯。',
      minLevel: 1, staminaCost: 0,
      goldReward: 800, expReward: 120, staminaReward: 30, affinityReward: 25,
      requiredItemId: 'autumn_sweetpotato', itemReward: 'harvest_trophy',
    ),
    Festival(
      id: 'autumn_contest', name: '菊花品评会', season: Season.autumn, day: 26,
      type: FestivalType.contest,
      description: '比谁的菊花开得更盛，冠军可得到铁匠特制的锄头。',
      minLevel: 4, staminaCost: 15,
      goldReward: 500, expReward: 90, staminaReward: 0, affinityReward: 12,
      requiredItemId: 'autumn_chrysanthemum', itemReward: 'steel_hoe',
    ),
    Festival(
      id: 'winter_star', name: '星夜祭', season: Season.winter, day: 14,
      type: FestivalType.celebration,
      description: '冬夜点亮灯火，罗伯特主持祈福仪式，全村共享热汤。',
      minLevel: 1, staminaCost: 0,
      goldReward: 200, expReward: 60, staminaReward: 40, affinityReward: 20,
      itemReward: 'lantern',
    ),
    Festival(
      id: 'winter_market', name: '冬雪集市', season: Season.winter, day: 25,
      type: FestivalType.market,
      description: '年末最后的集市，可出售存货换取过冬物资。',
      minLevel: 2, staminaCost: 10,
      goldReward: 300, expReward: 50, staminaReward: 15, affinityReward: 10,
      itemReward: 'winter_supplies',
    ),
  ];

  /// 本年已参与的祭典 ID。
  final Set<String> _attended = <String>{};

  /// 祭典总数，应为 7。
  static int get count => all.length;

  /// 全部祭典（只读）。
  List<Festival> get festivals => List<Festival>.unmodifiable(all);

  /// 今日举行的祭典，没有则返回 null。
  Festival? todayFestival(Season season, int day) {
    for (final Festival f in all) {
      if (f.occursOn(season, day)) return f;
    }
    return null;
  }

  /// 今天是否有祭典。
  bool isFestivalDay(Season season, int day) =>
      todayFestival(season, day) != null;

  /// 指定季节的祭典列表。
  List<Festival> inSeason(Season season) =>
      all.where((Festival f) => f.season == season).toList(growable: false);

  /// 按类型筛选。
  List<Festival> ofType(FestivalType type) =>
      all.where((Festival f) => f.type == type).toList(growable: false);

  /// 按 ID 查找。
  Festival? byId(String id) {
    for (final Festival f in all) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 是否已参与过。
  bool hasAttended(String id) => _attended.contains(id);

  /// 今年已参与的祭典数量。
  int get attendedCount => _attended.length;

  /// 尚未参与的祭典。
  List<Festival> get unattended =>
      all.where((Festival f) => !_attended.contains(f.id)).toList(growable: false);

  /// 下一个即将举行的祭典（按季节顺序与日期推算）。
  ///
  /// 返回 `(祭典, 还需等待的天数)`；若本年度全部已参与则返回 null。
  (Festival, int)? nextFestival(Season season, int day) {
    // 日历只在春夏秋冬之间轮换，温室不参与季节更替。
    const List<Season> calendar = <Season>[
      Season.spring,
      Season.summer,
      Season.autumn,
      Season.winter,
    ];
    final int startIdx = calendar.indexOf(season);
    if (startIdx < 0) return null; // 温室内没有祭典日历

    final int totalDays = calendar.length * daysPerSeason;
    for (int offset = 0; offset < totalDays; offset++) {
      final int absolute = startIdx * daysPerSeason + (day - 1) + offset;
      final Season curSeason =
          calendar[(absolute ~/ daysPerSeason) % calendar.length];
      final int curDay = (absolute % daysPerSeason) + 1;
      final Festival? f = todayFestival(curSeason, curDay);
      if (f != null && !_attended.contains(f.id)) {
        return (f, offset);
      }
    }
    return null;
  }

  /// 参与祭典。
  ///
  /// 校验条件：当天确实在举办、等级达标、体力充足、携带所需物品、未重复参与。
  /// [hasItem] 用于检查背包是否含所需物品，[consume] 由调用方在成功后扣除体力。
  FestivalResult attend(
    Festival festival, {
    required Season season,
    required int day,
    required int playerLevel,
    required int playerStamina,
    bool Function(String itemId)? hasItem,
  }) {
    if (!festival.occursOn(season, day)) {
      return FestivalResult.deny(
          '${festival.name}在${festival.season.label}${festival.day}日举行，今天不是当天');
    }
    if (_attended.contains(festival.id)) {
      return FestivalResult.deny('今年已经参加过${festival.name}了');
    }
    if (playerLevel < festival.minLevel) {
      return FestivalResult.deny(
          '等级不足，参加${festival.name}需要 ${festival.minLevel} 级');
    }
    if (playerStamina < festival.staminaCost) {
      return FestivalResult.deny(
          '体力不足，参加${festival.name}需要 ${festival.staminaCost} 点体力');
    }
    if (festival.requiredItemId.isNotEmpty &&
        hasItem != null &&
        !hasItem(festival.requiredItemId)) {
      return FestivalResult.deny('参加${festival.name}需要携带指定物品');
    }

    _attended.add(festival.id);
    final StringBuffer sb = StringBuffer('参加了${festival.name}（${festival.type.label}）：');
    final List<String> gains = <String>[];
    if (festival.goldReward > 0) gains.add('+${festival.goldReward} 金币');
    if (festival.expReward > 0) gains.add('+${festival.expReward} 经验');
    if (festival.staminaReward > 0) gains.add('+${festival.staminaReward} 体力');
    if (festival.affinityReward > 0) gains.add('全村好感 +${festival.affinityReward}');
    sb.write(gains.isEmpty ? '度过了愉快的时光' : gains.join('，'));

    return FestivalResult.ok(
      sb.toString(),
      goldReward: festival.goldReward,
      expReward: festival.expReward,
      staminaReward: festival.staminaReward,
      affinityReward: festival.affinityReward,
      itemReward: festival.itemReward,
    );
  }

  /// 跨年重置参与记录。
  void onNewYear() => _attended.clear();

  /// 导出存档数据。
  List<String> save() => _attended.toList(growable: false);

  /// 载入存档数据。
  void load(List<String> attended) {
    _attended
      ..clear()
      ..addAll(attended);
  }
}
