/// 作物配置数据（75 种）
///
/// 按季节分类：春季 15 种、夏季 15 种、秋季 15 种、冬季 15 种、温室 15 种。
/// 每种作物包含 ID、名称、季节、生长小时、阶段数、是否再生、售价、种子成本、颜色。
///
/// 本文件为纯数据层，不依赖 Flutter 渲染库；[Crop.color] 以 ARGB 整型存储，
/// 由 UI 层转换为 `Color` 使用。
library;

/// 季节枚举。
enum Season {
  spring('春季'),
  summer('夏季'),
  autumn('秋季'),
  winter('冬季'),
  greenhouse('温室');

  const Season(this.label);

  /// 中文名称。
  final String label;

  /// 下一个季节（温室不参与轮换，始终返回自身）。
  Season get next {
    switch (this) {
      case Season.spring:
        return Season.summer;
      case Season.summer:
        return Season.autumn;
      case Season.autumn:
        return Season.winter;
      case Season.winter:
        return Season.spring;
      case Season.greenhouse:
        return Season.greenhouse;
    }
  }
}

/// 单个作物的静态配置。
class Crop {
  const Crop({
    required this.id,
    required this.name,
    required this.season,
    required this.growHours,
    required this.stages,
    required this.regrow,
    required this.price,
    required this.seedCost,
    required this.color,
    this.regrowHours = 0,
  });

  /// 全局唯一 ID（同名作物跨季节时以季节前缀区分）。
  final String id;

  /// 作物名称。
  final String name;

  /// 所属季节。
  final Season season;

  /// 从播种到成熟所需的总小时数。
  final int growHours;

  /// 生长阶段数（含种子阶段与成熟阶段），最小为 2。
  final int stages;

  /// 收获后是否会再生。
  final bool regrow;

  /// 再生所需小时数，仅 [regrow] 为 true 时有效。
  final int regrowHours;

  /// 单次收获售价（金币）。
  final int price;

  /// 种子购买成本（金币）。
  final int seedCost;

  /// 成熟时果实颜色，ARGB 整型。
  final int color;

  /// 每个生长阶段平均耗时（小时）。
  double get hoursPerStage => growHours / (stages - 1).clamp(1, 99);

  /// 单季理论收益（售价 - 种子成本）。
  int get profit => price - seedCost;

  /// 每小时收益，用于排序推荐作物。
  double get profitPerHour => profit / (growHours <= 0 ? 1 : growHours);

  /// 根据累计生长小时数计算当前阶段索引（0 ~ stages-1）。
  int stageAt(double elapsedHours) {
    if (elapsedHours <= 0) return 0;
    if (elapsedHours >= growHours) return stages - 1;
    final int idx = (elapsedHours / hoursPerStage).floor();
    final int maxIdx = stages - 1;
    if (idx < 0) return 0;
    return idx > maxIdx ? maxIdx : idx;
  }

  /// 是否已成熟。
  bool isGrown(double elapsedHours) => elapsedHours >= growHours;

  @override
  String toString() => 'Crop($id, $name, ${season.label})';
}

/// 作物配置总表。
class CropsData {
  CropsData._();

  // ---------------------------------------------------------------- 春季 15 种
  static const List<Crop> spring = <Crop>[
    Crop(id: 'spring_wheat', name: '小麦', season: Season.spring, growHours: 24, stages: 4, regrow: false, price: 25, seedCost: 10, color: 0xFFE3C567),
    Crop(id: 'spring_potato', name: '土豆', season: Season.spring, growHours: 36, stages: 4, regrow: false, price: 45, seedCost: 20, color: 0xFFC8A165),
    Crop(id: 'spring_strawberry', name: '草莓', season: Season.spring, growHours: 48, stages: 5, regrow: true, regrowHours: 18, price: 60, seedCost: 30, color: 0xFFE23B3B),
    Crop(id: 'spring_pea', name: '豌豆', season: Season.spring, growHours: 30, stages: 4, regrow: true, regrowHours: 12, price: 35, seedCost: 15, color: 0xFF6FBF4A),
    Crop(id: 'spring_carrot', name: '胡萝卜', season: Season.spring, growHours: 28, stages: 4, regrow: false, price: 38, seedCost: 16, color: 0xFFF08A24),
    Crop(id: 'spring_lettuce', name: '生菜', season: Season.spring, growHours: 20, stages: 3, regrow: false, price: 28, seedCost: 12, color: 0xFF8FD460),
    Crop(id: 'spring_spinach', name: '菠菜', season: Season.spring, growHours: 22, stages: 3, regrow: false, price: 30, seedCost: 13, color: 0xFF3E8E41),
    Crop(id: 'spring_onion', name: '洋葱', season: Season.spring, growHours: 40, stages: 4, regrow: false, price: 52, seedCost: 22, color: 0xFFB98CC4),
    Crop(id: 'spring_cabbage', name: '卷心菜', season: Season.spring, growHours: 44, stages: 4, regrow: false, price: 58, seedCost: 25, color: 0xFF9CCC65),
    Crop(id: 'spring_asparagus', name: '芦笋', season: Season.spring, growHours: 38, stages: 4, regrow: true, regrowHours: 16, price: 55, seedCost: 24, color: 0xFF7BAE4B),
    Crop(id: 'spring_rhubarb', name: '大黄', season: Season.spring, growHours: 52, stages: 5, regrow: false, price: 72, seedCost: 34, color: 0xFFD2557E),
    Crop(id: 'spring_beet', name: '甜菜', season: Season.spring, growHours: 34, stages: 4, regrow: false, price: 48, seedCost: 20, color: 0xFFA63A6B),
    Crop(id: 'spring_celery', name: '芹菜', season: Season.spring, growHours: 32, stages: 4, regrow: false, price: 44, seedCost: 18, color: 0xFF8FBC5A),
    Crop(id: 'spring_turnip', name: '芜菁', season: Season.spring, growHours: 26, stages: 3, regrow: false, price: 34, seedCost: 14, color: 0xFFEFE6D2),
    Crop(id: 'spring_arugula', name: '芝麻菜', season: Season.spring, growHours: 18, stages: 3, regrow: false, price: 26, seedCost: 11, color: 0xFF5FA845),
  ];

  // ---------------------------------------------------------------- 夏季 15 种
  static const List<Crop> summer = <Crop>[
    Crop(id: 'summer_tomato', name: '番茄', season: Season.summer, growHours: 42, stages: 5, regrow: true, regrowHours: 14, price: 62, seedCost: 28, color: 0xFFE0423B),
    Crop(id: 'summer_chili', name: '辣椒', season: Season.summer, growHours: 40, stages: 5, regrow: true, regrowHours: 14, price: 58, seedCost: 26, color: 0xFFD93A21),
    Crop(id: 'summer_corn', name: '玉米', season: Season.summer, growHours: 56, stages: 5, regrow: false, price: 85, seedCost: 38, color: 0xFFF2C744),
    Crop(id: 'summer_watermelon', name: '西瓜', season: Season.summer, growHours: 72, stages: 5, regrow: false, price: 130, seedCost: 55, color: 0xFF4E9A3E),
    Crop(id: 'summer_pineapple', name: '菠萝', season: Season.summer, growHours: 68, stages: 5, regrow: false, price: 120, seedCost: 50, color: 0xFFE8B33C),
    Crop(id: 'summer_eggplant', name: '茄子', season: Season.summer, growHours: 46, stages: 5, regrow: true, regrowHours: 16, price: 66, seedCost: 28, color: 0xFF6B3E8F),
    Crop(id: 'summer_cucumber', name: '黄瓜', season: Season.summer, growHours: 34, stages: 4, regrow: true, regrowHours: 12, price: 46, seedCost: 20, color: 0xFF4F9B3A),
    Crop(id: 'summer_pumpkin', name: '南瓜', season: Season.summer, growHours: 64, stages: 5, regrow: false, price: 110, seedCost: 46, color: 0xFFE08A1E),
    Crop(id: 'summer_zucchini', name: '西葫芦', season: Season.summer, growHours: 38, stages: 4, regrow: true, regrowHours: 14, price: 52, seedCost: 22, color: 0xFF7FA83C),
    Crop(id: 'summer_bellpepper', name: '甜椒', season: Season.summer, growHours: 44, stages: 5, regrow: true, regrowHours: 15, price: 64, seedCost: 27, color: 0xFFE2574C),
    Crop(id: 'summer_okra', name: '秋葵', season: Season.summer, growHours: 36, stages: 4, regrow: true, regrowHours: 13, price: 50, seedCost: 21, color: 0xFF6E9E3F),
    Crop(id: 'summer_mango', name: '芒果', season: Season.summer, growHours: 80, stages: 6, regrow: false, price: 150, seedCost: 65, color: 0xFFF2A03D),
    Crop(id: 'summer_papaya', name: '木瓜', season: Season.summer, growHours: 76, stages: 6, regrow: false, price: 140, seedCost: 60, color: 0xFFF58F3C),
    Crop(id: 'summer_coconut', name: '椰子', season: Season.summer, growHours: 88, stages: 6, regrow: false, price: 165, seedCost: 72, color: 0xFF8B5A2B),
    Crop(id: 'summer_melon', name: '香瓜', season: Season.summer, growHours: 58, stages: 5, regrow: false, price: 98, seedCost: 42, color: 0xFFD8C87A),
  ];

  // ---------------------------------------------------------------- 秋季 15 种
  static const List<Crop> autumn = <Crop>[
    Crop(id: 'autumn_grape', name: '葡萄', season: Season.autumn, growHours: 54, stages: 5, regrow: true, regrowHours: 20, price: 90, seedCost: 40, color: 0xFF7B4B9E),
    Crop(id: 'autumn_apple', name: '苹果', season: Season.autumn, growHours: 70, stages: 5, regrow: false, price: 118, seedCost: 50, color: 0xFFD6453D),
    Crop(id: 'autumn_mushroom', name: '蘑菇', season: Season.autumn, growHours: 28, stages: 4, regrow: true, regrowHours: 10, price: 54, seedCost: 22, color: 0xFFB99B7A),
    Crop(id: 'autumn_sweetpotato', name: '红薯', season: Season.autumn, growHours: 48, stages: 4, regrow: false, price: 72, seedCost: 30, color: 0xFFC8663C),
    Crop(id: 'autumn_chestnut', name: '栗子', season: Season.autumn, growHours: 74, stages: 5, regrow: false, price: 126, seedCost: 54, color: 0xFF8B4A2B),
    Crop(id: 'autumn_walnut', name: '核桃', season: Season.autumn, growHours: 82, stages: 5, regrow: false, price: 142, seedCost: 60, color: 0xFF9C7043),
    Crop(id: 'autumn_pear', name: '梨', season: Season.autumn, growHours: 66, stages: 5, regrow: false, price: 108, seedCost: 45, color: 0xFFD6D27A),
    Crop(id: 'autumn_persimmon', name: '柿子', season: Season.autumn, growHours: 62, stages: 5, regrow: false, price: 100, seedCost: 42, color: 0xFFE8762C),
    Crop(id: 'autumn_pomegranate', name: '石榴', season: Season.autumn, growHours: 68, stages: 5, regrow: false, price: 116, seedCost: 48, color: 0xFFC0392B),
    Crop(id: 'autumn_fig', name: '无花果', season: Season.autumn, growHours: 60, stages: 5, regrow: true, regrowHours: 22, price: 98, seedCost: 41, color: 0xFF8A5A78),
    Crop(id: 'autumn_jujube', name: '枣', season: Season.autumn, growHours: 58, stages: 5, regrow: false, price: 94, seedCost: 39, color: 0xFFA34A2E),
    Crop(id: 'autumn_hawthorn', name: '山楂', season: Season.autumn, growHours: 56, stages: 5, regrow: false, price: 88, seedCost: 36, color: 0xFFCE4034),
    Crop(id: 'autumn_ginkgo', name: '银杏', season: Season.autumn, growHours: 86, stages: 6, regrow: false, price: 152, seedCost: 64, color: 0xFFE5C547),
    Crop(id: 'autumn_sugarcane', name: '甘蔗', season: Season.autumn, growHours: 78, stages: 6, regrow: true, regrowHours: 26, price: 134, seedCost: 56, color: 0xFF9DBF6A),
    Crop(id: 'autumn_chrysanthemum', name: '菊花', season: Season.autumn, growHours: 42, stages: 4, regrow: false, price: 68, seedCost: 28, color: 0xFFF0D24A),
  ];

  // ---------------------------------------------------------------- 冬季 15 种
  static const List<Crop> winter = <Crop>[
    Crop(id: 'winter_cabbage', name: '白菜', season: Season.winter, growHours: 46, stages: 4, regrow: false, price: 64, seedCost: 26, color: 0xFFDCE8C0),
    Crop(id: 'winter_onion', name: '洋葱', season: Season.winter, growHours: 50, stages: 4, regrow: false, price: 70, seedCost: 28, color: 0xFFC39BD3),
    Crop(id: 'winter_garlic', name: '大蒜', season: Season.winter, growHours: 44, stages: 4, regrow: false, price: 62, seedCost: 25, color: 0xFFF2EDE0),
    Crop(id: 'winter_radish', name: '萝卜', season: Season.winter, growHours: 36, stages: 4, regrow: false, price: 52, seedCost: 21, color: 0xFFF4F1E8),
    Crop(id: 'winter_pumpkin', name: '冬南瓜', season: Season.winter, growHours: 76, stages: 5, regrow: false, price: 128, seedCost: 52, color: 0xFFD98324),
    Crop(id: 'winter_kale', name: '羽衣甘蓝', season: Season.winter, growHours: 42, stages: 4, regrow: true, regrowHours: 18, price: 60, seedCost: 24, color: 0xFF4C7A4C),
    Crop(id: 'winter_brussels', name: '抱子甘蓝', season: Season.winter, growHours: 52, stages: 5, regrow: false, price: 78, seedCost: 32, color: 0xFF7EA356),
    Crop(id: 'winter_chive', name: '韭菜', season: Season.winter, growHours: 30, stages: 3, regrow: true, regrowHours: 12, price: 44, seedCost: 18, color: 0xFF4F8F3C),
    Crop(id: 'winter_celery', name: '芹菜', season: Season.winter, growHours: 40, stages: 4, regrow: false, price: 58, seedCost: 23, color: 0xFF87B35A),
    Crop(id: 'winter_spinach', name: '菠菜', season: Season.winter, growHours: 32, stages: 3, regrow: false, price: 46, seedCost: 19, color: 0xFF357A38),
    Crop(id: 'winter_mustard', name: '芥菜', season: Season.winter, growHours: 38, stages: 4, regrow: false, price: 54, seedCost: 22, color: 0xFF6E9B3A),
    Crop(id: 'winter_coriander', name: '香菜', season: Season.winter, growHours: 26, stages: 3, regrow: false, price: 40, seedCost: 16, color: 0xFF5C9C46),
    Crop(id: 'winter_ginger', name: '姜', season: Season.winter, growHours: 64, stages: 5, regrow: false, price: 104, seedCost: 42, color: 0xFFD9A55F),
    Crop(id: 'winter_aloe', name: '芦荟', season: Season.winter, growHours: 58, stages: 5, regrow: true, regrowHours: 24, price: 92, seedCost: 37, color: 0xFF6FA96A),
    Crop(id: 'winter_matsutake', name: '松茸', season: Season.winter, growHours: 70, stages: 5, regrow: false, price: 168, seedCost: 70, color: 0xFFA98259),
  ];

  // ---------------------------------------------------------------- 温室 15 种
  static const List<Crop> greenhouse = <Crop>[
    Crop(id: 'gh_rice', name: '水稻', season: Season.greenhouse, growHours: 60, stages: 5, regrow: false, price: 96, seedCost: 40, color: 0xFFDCC97A),
    Crop(id: 'gh_rubber', name: '橡胶', season: Season.greenhouse, growHours: 96, stages: 6, regrow: true, regrowHours: 30, price: 180, seedCost: 76, color: 0xFFEDE6D6),
    Crop(id: 'gh_coffee', name: '咖啡', season: Season.greenhouse, growHours: 84, stages: 6, regrow: true, regrowHours: 28, price: 162, seedCost: 68, color: 0xFF6B3F2A),
    Crop(id: 'gh_cocoa', name: '可可', season: Season.greenhouse, growHours: 90, stages: 6, regrow: true, regrowHours: 30, price: 172, seedCost: 72, color: 0xFF8B5A3C),
    Crop(id: 'gh_orchid', name: '兰花', season: Season.greenhouse, growHours: 72, stages: 5, regrow: false, price: 190, seedCost: 80, color: 0xFFC98BD1),
    Crop(id: 'gh_banana', name: '香蕉', season: Season.greenhouse, growHours: 78, stages: 6, regrow: false, price: 148, seedCost: 62, color: 0xFFF3D24A),
    Crop(id: 'gh_mango', name: '芒果', season: Season.greenhouse, growHours: 82, stages: 6, regrow: false, price: 158, seedCost: 66, color: 0xFFF0A03C),
    Crop(id: 'gh_lychee', name: '荔枝', season: Season.greenhouse, growHours: 86, stages: 6, regrow: false, price: 176, seedCost: 74, color: 0xFFD8536B),
    Crop(id: 'gh_longan', name: '龙眼', season: Season.greenhouse, growHours: 88, stages: 6, regrow: false, price: 178, seedCost: 75, color: 0xFFC9A66B),
    Crop(id: 'gh_durian', name: '榴莲', season: Season.greenhouse, growHours: 120, stages: 7, regrow: false, price: 320, seedCost: 140, color: 0xFFB7A34F),
    Crop(id: 'gh_mangosteen', name: '山竹', season: Season.greenhouse, growHours: 100, stages: 6, regrow: false, price: 240, seedCost: 100, color: 0xFF7B3B6B),
    Crop(id: 'gh_guava', name: '番石榴', season: Season.greenhouse, growHours: 74, stages: 5, regrow: true, regrowHours: 26, price: 138, seedCost: 58, color: 0xFFB9D46A),
    Crop(id: 'gh_passionfruit', name: '百香果', season: Season.greenhouse, growHours: 68, stages: 5, regrow: true, regrowHours: 22, price: 128, seedCost: 54, color: 0xFF9B4A8A),
    Crop(id: 'gh_avocado', name: '牛油果', season: Season.greenhouse, growHours: 94, stages: 6, regrow: false, price: 205, seedCost: 86, color: 0xFF5C7A3A),
    Crop(id: 'gh_kiwifruit', name: '奇异果', season: Season.greenhouse, growHours: 80, stages: 6, regrow: true, regrowHours: 28, price: 168, seedCost: 70, color: 0xFF8AA84A),
  ];

  /// 全部 75 种作物（春 → 夏 → 秋 → 冬 → 温室）。
  static final List<Crop> all = <Crop>[
    ...spring,
    ...summer,
    ...autumn,
    ...winter,
    ...greenhouse,
  ];

  static final Map<String, Crop> _byId = <String, Crop>{
    for (final Crop c in all) c.id: c,
  };

  static final Map<String, Crop> _byName = _buildNameIndex();

  /// 构建名称索引；跨季节同名作物只保留首次出现的配置。
  static Map<String, Crop> _buildNameIndex() {
    final Map<String, Crop> index = <String, Crop>{};
    for (final Crop c in all) {
      index.putIfAbsent(c.name, () => c);
    }
    return index;
  }

  /// 作物总数，应为 75。
  static int get count => all.length;

  /// 按季节取作物列表。
  static List<Crop> bySeason(Season season) {
    switch (season) {
      case Season.spring:
        return spring;
      case Season.summer:
        return summer;
      case Season.autumn:
        return autumn;
      case Season.winter:
        return winter;
      case Season.greenhouse:
        return greenhouse;
    }
  }

  /// 按 ID 精确查找，找不到返回 null。
  static Crop? byId(String id) => _byId[id];

  /// 按名称查找（跨季节同名时返回首次出现的配置），找不到返回 null。
  static Crop? byName(String name) => _byName[name];

  /// 当前季节可种植的作物。
  static List<Crop> plantableIn(Season season) => bySeason(season);

  /// 玩家当前金币能买得起种子的作物。
  static List<Crop> affordable(int gold) =>
      all.where((Crop c) => c.seedCost <= gold).toList();

  /// 按每小时收益降序排列的推荐作物。
  static List<Crop> byProfitPerHour(Season? season) {
    final List<Crop> src = season == null ? all : bySeason(season);
    final List<Crop> list = List<Crop>.from(src)
      ..sort((Crop a, Crop b) => b.profitPerHour.compareTo(a.profitPerHour));
    return list;
  }

  /// 生长最快的作物（用于新手引导）。
  static Crop get fastest {
    Crop r = all.first;
    for (final Crop c in all) {
      if (c.growHours < r.growHours) r = c;
    }
    return r;
  }

  /// 售价最高的作物。
  static Crop get mostValuable {
    Crop r = all.first;
    for (final Crop c in all) {
      if (c.price > r.price) r = c;
    }
    return r;
  }
}
