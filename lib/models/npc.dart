/// NPC 模型（17 个）
///
/// 包含姓名、职业、坐标、是否可攻略、喜好厌恶。
/// 好感度管理见 `lib/systems/npc_system.dart`。
library;

import 'dart:math' as math;

/// NPC 性别，用于立绘与婚配判定。
enum Gender { male('男'), female('女');

  const Gender(this.label);

  /// 中文名称。
  final String label;
}

/// NPC 日常行程的单个时段。
class ScheduleEntry {
  const ScheduleEntry({
    required this.hourStart,
    required this.hourEnd,
    required this.x,
    required this.location,
  });

  /// 起始小时（0~23）。
  final int hourStart;

  /// 结束小时（0~23）。
  final int hourEnd;

  /// 该时段所在世界坐标 X。
  final double x;

  /// 地点名称。
  final String location;

  /// 判断某小时是否落在本时段内。
  bool contains(int hour) => hour >= hourStart && hour < hourEnd;
}

/// 单个 NPC 的静态配置。
class Npc {
  const Npc({
    required this.id,
    required this.name,
    required this.job,
    required this.x,
    required this.y,
    required this.marriageable,
    required this.gender,
    required this.likes,
    required this.dislikes,
    this.color = 0xFF8D6E63,
    this.greeting = '你好呀。',
    this.birthday = '',
    this.schedule = const <ScheduleEntry>[],
  });

  /// 唯一 ID。
  final String id;

  /// 姓名。
  final String name;

  /// 职业。
  final String job;

  /// 默认站立的世界坐标 X。
  final double x;

  /// 默认站立的世界坐标 Y（脚底）。
  final double y;

  /// 是否可攻略（可结婚）。
  final bool marriageable;

  /// 性别。
  final Gender gender;

  /// 喜好的作物 ID 列表（送礼加好感更多）。
  final List<String> likes;

  /// 厌恶的作物 ID 列表（送礼扣好感）。
  final List<String> dislikes;

  /// 代表色（ARGB）。
  final int color;

  /// 默认问候语。
  final String greeting;

  /// 生日（格式 MM-DD）。
  final String birthday;

  /// 日常行程。
  final List<ScheduleEntry> schedule;

  /// 角色宽度（像素）。
  static const double width = 26;

  /// 角色高度（像素）。
  static const double height = 42;

  /// 是否喜欢该作物。
  bool likesCrop(String cropId) => likes.contains(cropId);

  /// 是否厌恶该作物。
  bool dislikesCrop(String cropId) => dislikes.contains(cropId);

  /// 按当前小时返回所在坐标 X；无行程配置时返回默认 [x]。
  double xAtHour(int hour) {
    for (final ScheduleEntry e in schedule) {
      if (e.contains(hour)) return e.x;
    }
    return x;
  }

  /// 按当前小时返回地点名称。
  String locationAtHour(int hour) {
    for (final ScheduleEntry e in schedule) {
      if (e.contains(hour)) return e.location;
    }
    return '村庄';
  }

  /// 占据的矩形（世界坐标）。
  math.Rectangle<double> get bounds => math.Rectangle<double>(
        x - width / 2,
        y - height,
        width,
        height,
      );

  @override
  String toString() => 'Npc($id, $name, $job)';
}

/// 17 位 NPC 的静态配置表。
class NpcData {
  NpcData._();

  /// 全部 NPC（按文档顺序）。
  static const List<Npc> all = <Npc>[
    Npc(
      id: 'john', name: '老约翰', job: '村长', x: 320, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF7B6A4F,
      likes: <String>['autumn_chrysanthemum', 'spring_cabbage'],
      dislikes: <String>['summer_chili'],
      greeting: '年轻人，牧场就交给你了。', birthday: '03-12',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 8, hourEnd: 12, x: 320, location: '村长家'),
        ScheduleEntry(hourStart: 12, hourEnd: 18, x: 640, location: '广场'),
        ScheduleEntry(hourStart: 18, hourEnd: 24, x: 320, location: '村长家'),
      ],
    ),
    Npc(
      id: 'mary', name: '玛丽', job: '面包师', x: 760, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFFD9A05B,
      likes: <String>['spring_wheat', 'summer_corn'],
      dislikes: <String>['autumn_mushroom'],
      greeting: '刚出炉的面包，来一个吗？', birthday: '05-04',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 5, hourEnd: 14, x: 760, location: '面包店'),
        ScheduleEntry(hourStart: 14, hourEnd: 20, x: 900, location: '广场'),
      ],
    ),
    Npc(
      id: 'tom', name: '汤姆', job: '杂货商', x: 1080, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF5B8CA8,
      likes: <String>['spring_potato', 'winter_garlic'],
      dislikes: <String>['gh_durian'],
      greeting: '种子、工具，应有尽有。', birthday: '07-19',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 9, hourEnd: 21, x: 1080, location: '杂货店'),
      ],
    ),
    Npc(
      id: 'eileen', name: '艾琳', job: '画家', x: 1420, y: 520,
      marriageable: true, gender: Gender.female, color: 0xFFC77D9A,
      likes: <String>['autumn_chrysanthemum', 'gh_orchid'],
      dislikes: <String>['winter_garlic'],
      greeting: '光线真好，适合写生。', birthday: '04-02',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 10, hourEnd: 17, x: 1900, location: '湖畔'),
        ScheduleEntry(hourStart: 17, hourEnd: 22, x: 1420, location: '画室'),
      ],
    ),
    Npc(
      id: 'lucas', name: '卢卡斯', job: '铁匠', x: 1740, y: 520,
      marriageable: true, gender: Gender.male, color: 0xFF6E5A4E,
      likes: <String>['summer_pumpkin', 'autumn_chestnut'],
      dislikes: <String>['spring_lettuce'],
      greeting: '要打造什么工具吗？', birthday: '09-23',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 7, hourEnd: 19, x: 1740, location: '铁匠铺'),
      ],
    ),
    Npc(
      id: 'maya', name: '玛雅', job: '渔夫', x: 2060, y: 520,
      marriageable: true, gender: Gender.female, color: 0xFF4E8FA8,
      likes: <String>['summer_watermelon', 'winter_aloe'],
      dislikes: <String>['autumn_ginkgo'],
      greeting: '今天的浪很平，适合出海。', birthday: '06-11',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 5, hourEnd: 15, x: 2500, location: '码头'),
        ScheduleEntry(hourStart: 15, hourEnd: 22, x: 2060, location: '渔屋'),
      ],
    ),
    Npc(
      id: 'sebastian', name: '塞巴斯蒂安', job: '程序员', x: 2380, y: 520,
      marriageable: true, gender: Gender.male, color: 0xFF555B6E,
      likes: <String>['gh_coffee', 'spring_spinach'],
      dislikes: <String>['winter_mustard'],
      greeting: '通宵改 bug……你起得真早。', birthday: '11-08',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 12, hourEnd: 23, x: 2380, location: '工作室'),
      ],
    ),
    Npc(
      id: 'sophia', name: '索菲亚', job: '教师', x: 2700, y: 520,
      marriageable: true, gender: Gender.female, color: 0xFF8E7CC3,
      likes: <String>['spring_strawberry', 'autumn_pear'],
      dislikes: <String>['summer_chili'],
      greeting: '孩子们今天很乖。', birthday: '02-14',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 8, hourEnd: 15, x: 2700, location: '学校'),
        ScheduleEntry(hourStart: 15, hourEnd: 20, x: 2860, location: '图书馆'),
      ],
    ),
    Npc(
      id: 'emily', name: '艾米丽', job: '花店', x: 3020, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFFE58FA5,
      likes: <String>['gh_orchid', 'autumn_chrysanthemum'],
      dislikes: <String>['autumn_mushroom'],
      greeting: '新到的花种，看看吗？', birthday: '03-30',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 9, hourEnd: 19, x: 3020, location: '花店'),
      ],
    ),
    Npc(
      id: 'jack', name: '杰克', job: '猎人', x: 3340, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF5C6B4A,
      likes: <String>['autumn_chestnut', 'winter_matsutake'],
      dislikes: <String>['spring_arugula'],
      greeting: '山里野兽多了，小心点。', birthday: '10-15',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 6, hourEnd: 18, x: 3800, location: '森林'),
        ScheduleEntry(hourStart: 18, hourEnd: 24, x: 3340, location: '猎人小屋'),
      ],
    ),
    Npc(
      id: 'lily', name: '莉莉', job: '护士', x: 3660, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFFF2F2F2,
      likes: <String>['winter_aloe', 'spring_spinach'],
      dislikes: <String>['summer_chili'],
      greeting: '别太累了，注意休息。', birthday: '08-07',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 8, hourEnd: 20, x: 3660, location: '诊所'),
      ],
    ),
    Npc(
      id: 'carl', name: '卡尔', job: '矿工', x: 3980, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF7A6A55,
      likes: <String>['winter_ginger', 'autumn_walnut'],
      dislikes: <String>['spring_lettuce'],
      greeting: '矿洞深处有好东西。', birthday: '12-01',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 6, hourEnd: 16, x: 4300, location: '矿洞入口'),
        ScheduleEntry(hourStart: 16, hourEnd: 23, x: 3980, location: '矿工宿舍'),
      ],
    ),
    Npc(
      id: 'anna', name: '安娜', job: '厨师', x: 4620, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFFD4763C,
      likes: <String>['summer_tomato', 'autumn_persimmon'],
      dislikes: <String>['gh_rubber'],
      greeting: '今天想吃什么？', birthday: '01-25',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 10, hourEnd: 22, x: 4620, location: '餐馆'),
      ],
    ),
    Npc(
      id: 'ben', name: '本', job: '邮差', x: 4940, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF4A6FA5,
      likes: <String>['spring_carrot', 'summer_cucumber'],
      dislikes: <String>['gh_durian'],
      greeting: '有你的信件。', birthday: '05-28',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 8, hourEnd: 17, x: 4940, location: '邮局'),
      ],
    ),
    Npc(
      id: 'lucy', name: '露西', job: '牧羊女', x: 5260, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFF9BC47A,
      likes: <String>['winter_kale', 'spring_pea'],
      dislikes: <String>['autumn_pomegranate'],
      greeting: '羊儿们今天很精神。', birthday: '04-18',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 6, hourEnd: 18, x: 5600, location: '牧场草坡'),
        ScheduleEntry(hourStart: 18, hourEnd: 24, x: 5260, location: '牧羊屋'),
      ],
    ),
    Npc(
      id: 'robert', name: '罗伯特', job: '牧师', x: 5920, y: 520,
      marriageable: false, gender: Gender.male, color: 0xFF3F3F46,
      likes: <String>['autumn_grape', 'spring_rhubarb'],
      dislikes: <String>['summer_chili'],
      greeting: '愿平安与你同在。', birthday: '12-24',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 7, hourEnd: 20, x: 5920, location: '教堂'),
      ],
    ),
    Npc(
      id: 'ava', name: '艾娃', job: '魔术师', x: 6240, y: 520,
      marriageable: false, gender: Gender.female, color: 0xFF7B3FA0,
      likes: <String>['gh_passionfruit', 'autumn_ginkgo'],
      dislikes: <String>['winter_radish'],
      greeting: '想看点小把戏吗？', birthday: '10-31',
      schedule: <ScheduleEntry>[
        ScheduleEntry(hourStart: 14, hourEnd: 24, x: 6240, location: '马戏帐篷'),
      ],
    ),
  ];

  static final Map<String, Npc> _byId = <String, Npc>{
    for (final Npc n in all) n.id: n,
  };

  /// NPC 总数，应为 17。
  static int get count => all.length;

  /// 可攻略 NPC 列表。
  static List<Npc> get marriageable =>
      all.where((Npc n) => n.marriageable).toList();

  /// 按 ID 查找，找不到返回 null。
  static Npc? byId(String id) => _byId[id];

  /// 按姓名查找，找不到返回 null。
  static Npc? byName(String name) {
    for (final Npc n in all) {
      if (n.name == name) return n;
    }
    return null;
  }

  /// 按职业查找。
  static Npc? byJob(String job) {
    for (final Npc n in all) {
      if (n.job == job) return n;
    }
    return null;
  }

  /// 距离世界坐标 [wx] 最近的 NPC。
  static Npc nearest(double wx) {
    Npc best = all.first;
    double bestDist = (best.x - wx).abs();
    for (final Npc n in all) {
      final double d = (n.x - wx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = n;
      }
    }
    return best;
  }
}
