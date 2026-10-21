/// 任务系统（15 个）
///
/// 包含主线 7 个、支线 8 个。
/// 任务类型：击杀、种植、钓鱼、收集、对话、探索。
/// 支持任务状态管理（未开始/进行中/已完成）。
library;

import 'dart:math' as math;

/// 任务状态。
enum QuestStatus {
  notStarted('未开始'),
  inProgress('进行中'),
  completed('已完成');

  const QuestStatus(this.label);

  /// 中文名称。
  final String label;
}

/// 任务类型。
enum QuestType {
  kill('击杀'),
  plant('种植'),
  fish('钓鱼'),
  collect('收集'),
  talk('对话'),
  explore('探索');

  const QuestType(this.label);

  /// 中文名称。
  final String label;
}

/// 任务分类。
enum QuestCategory {
  main('主线'),
  side('支线');

  const QuestCategory(this.label);

  /// 中文名称。
  final String label;
}

/// 任务的静态配置。
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.targetId,
    required this.targetCount,
    required this.goldReward,
    required this.expReward,
    this.itemReward = '',
    this.itemRewardCount = 0,
    this.prerequisiteId = '',
    this.order = 0,
  });

  /// 唯一 ID。
  final String id;

  /// 任务标题。
  final String title;

  /// 任务描述。
  final String description;

  /// 任务类型。
  final QuestType type;

  /// 主线/支线。
  final QuestCategory category;

  /// 目标 ID：击杀为怪物 ID、种植/收集为作物或物品 ID、
  /// 对话为 NPC ID、钓鱼与探索为地点/鱼种 ID。
  final String targetId;

  /// 目标数量。
  final int targetCount;

  /// 金币奖励。
  final int goldReward;

  /// 经验奖励。
  final int expReward;

  /// 物品奖励 ID（空表示无）。
  final String itemReward;

  /// 物品奖励数量。
  final int itemRewardCount;

  /// 前置任务 ID（空表示无前置）。
  final String prerequisiteId;

  /// 同类任务的排序序号。
  final int order;

  @override
  String toString() => 'Quest($id, $title)';
}

/// 任务的运行时进度。
class QuestProgress {
  QuestProgress(this.quest, {this.status = QuestStatus.notStarted});

  /// 静态配置。
  final Quest quest;

  /// 当前状态。
  QuestStatus status;

  /// 当前进度计数。
  int progress = 0;

  /// 是否已领取奖励。
  bool rewardClaimed = false;

  /// 是否已完成（进度达标）。
  bool get isComplete => progress >= quest.targetCount;

  /// 进度比例 0~1。
  double get ratio {
    if (quest.targetCount <= 0) return 1;
    final double r = progress / quest.targetCount;
    return r <= 0 ? 0 : (r >= 1 ? 1 : r);
  }

  /// 进度文案，如 `3/10`。
  String get progressText => '${math.min(progress, quest.targetCount)}/${quest.targetCount}';

  /// 剩余数量。
  int get remaining => math.max(0, quest.targetCount - progress);

  /// 推进进度，返回本次实际增量。
  int advance([int amount = 1]) {
    if (status == QuestStatus.completed || amount <= 0) return 0;
    final int before = progress;
    progress = math.min(quest.targetCount, progress + amount);
    if (isComplete) status = QuestStatus.completed;
    return progress - before;
  }
}

/// 任务事件结果。
class QuestEventResult {
  const QuestEventResult({this.advanced = const <String>[], this.completed = const <String>[]});

  /// 本次推进进度的任务 ID。
  final List<String> advanced;

  /// 本次新完成的任务 ID。
  final List<String> completed;

  /// 是否有任何变化。
  bool get hasChange => advanced.isNotEmpty;
}

/// 任务系统。
class QuestSystem {
  QuestSystem() {
    for (final Quest q in all) {
      _progress[q.id] = QuestProgress(q);
    }
    // 无前置的首个主线任务默认开启。
    for (final Quest q in main) {
      if (q.prerequisiteId.isEmpty) {
        _progress[q.id]!.status = QuestStatus.inProgress;
        break;
      }
    }
    // 无前置的支线任务默认开启。
    for (final Quest q in side) {
      if (q.prerequisiteId.isEmpty) {
        _progress[q.id]!.status = QuestStatus.inProgress;
      }
    }
  }

  /// 主线任务（7 个）。
  static const List<Quest> main = <Quest>[
    Quest(
      id: 'main_1', title: '新的开始', category: QuestCategory.main, order: 1,
      description: '接手这座荒废的牧场，先开垦 5 块土地重新开始。',
      type: QuestType.explore, targetId: 'hoe_tile', targetCount: 5,
      goldReward: 200, expReward: 50,
    ),
    Quest(
      id: 'main_2', title: '第一颗种子', category: QuestCategory.main, order: 2,
      description: '播种并收获 3 株小麦，换取第一笔收入。',
      type: QuestType.plant, targetId: 'spring_wheat', targetCount: 3,
      goldReward: 400, expReward: 90, prerequisiteId: 'main_1',
      itemReward: 'seed_pack_spring', itemRewardCount: 5,
    ),
    Quest(
      id: 'main_3', title: '拜访村民', category: QuestCategory.main, order: 3,
      description: '与 5 位村民交谈，认识这座小镇的居民。',
      type: QuestType.talk, targetId: 'any_npc', targetCount: 5,
      goldReward: 300, expReward: 100, prerequisiteId: 'main_2',
    ),
    Quest(
      id: 'main_4', title: '矿洞初探', category: QuestCategory.main, order: 4,
      description: '进入采矿场，击败 5 只怪物证明自己的实力。',
      type: QuestType.kill, targetId: 'any_monster', targetCount: 5,
      goldReward: 600, expReward: 150, prerequisiteId: 'main_3',
      itemReward: 'iron_sword', itemRewardCount: 1,
    ),
    Quest(
      id: 'main_5', title: '湖畔垂钓', category: QuestCategory.main, order: 5,
      description: '向玛雅学习钓鱼，成功钓起 8 条鱼。',
      type: QuestType.fish, targetId: 'any_fish', targetCount: 8,
      goldReward: 700, expReward: 180, prerequisiteId: 'main_4',
      itemReward: 'fishing_rod_pro', itemRewardCount: 1,
    ),
    Quest(
      id: 'main_6', title: '丰收的证明', category: QuestCategory.main, order: 6,
      description: '收获 15 株任意作物，为丰收祭做准备。',
      type: QuestType.collect, targetId: 'any_crop', targetCount: 15,
      goldReward: 1200, expReward: 300, prerequisiteId: 'main_5',
      itemReward: 'harvest_medal', itemRewardCount: 1,
    ),
    Quest(
      id: 'main_7', title: '矿洞深处的传说', category: QuestCategory.main, order: 7,
      description: '抵达采矿第 7 层并击败幼龙，成为真正的牧场传奇。',
      type: QuestType.kill, targetId: 'dragon', targetCount: 1,
      goldReward: 5000, expReward: 1000, prerequisiteId: 'main_6',
      itemReward: 'legendary_hoe', itemRewardCount: 1,
    ),
  ];

  /// 支线任务（8 个）。
  static const List<Quest> side = <Quest>[
    Quest(
      id: 'side_1', title: '玛丽的订单', category: QuestCategory.side, order: 1,
      description: '面包师玛丽需要 5 株小麦作为原料。',
      type: QuestType.collect, targetId: 'spring_wheat', targetCount: 5,
      goldReward: 250, expReward: 60,
    ),
    Quest(
      id: 'side_2', title: '甜心草莓', category: QuestCategory.side, order: 2,
      description: '种植并收获 4 株草莓，索菲亚想给孩子们做甜点。',
      type: QuestType.plant, targetId: 'spring_strawberry', targetCount: 4,
      goldReward: 300, expReward: 70,
    ),
    Quest(
      id: 'side_3', title: '哥布林的麻烦', category: QuestCategory.side, order: 3,
      description: '矿工卡尔说矿洞里有哥布林，击败 3 只矿石哥布林。',
      type: QuestType.kill, targetId: 'goblin', targetCount: 3,
      goldReward: 400, expReward: 90, itemReward: 'copper_ore', itemRewardCount: 5,
    ),
    Quest(
      id: 'side_4', title: '骷髅的骨头', category: QuestCategory.side, order: 4,
      description: '铁匠卢卡斯需要 4 块骨头作为锻造材料。',
      type: QuestType.kill, targetId: 'skeleton', targetCount: 4,
      goldReward: 520, expReward: 120,
    ),
    Quest(
      id: 'side_5', title: '渔获之约', category: QuestCategory.side, order: 5,
      description: '钓起 5 条鱼交给安娜，她想试做新菜。',
      type: QuestType.fish, targetId: 'any_fish', targetCount: 5,
      goldReward: 350, expReward: 80,
    ),
    Quest(
      id: 'side_6', title: '秋日的菊花', category: QuestCategory.side, order: 6,
      description: '收获 3 株菊花，为菊花品评会做准备。',
      type: QuestType.collect, targetId: 'autumn_chrysanthemum', targetCount: 3,
      goldReward: 450, expReward: 100, itemReward: 'steel_hoe', itemRewardCount: 1,
    ),
    Quest(
      id: 'side_7', title: '艾琳的写生', category: QuestCategory.side, order: 7,
      description: '画家艾琳想看看温室作物，收集 2 株兰花。',
      type: QuestType.collect, targetId: 'gh_orchid', targetCount: 2,
      goldReward: 600, expReward: 130,
    ),
    Quest(
      id: 'side_8', title: '村庄的每个角落', category: QuestCategory.side, order: 8,
      description: '与全部 17 位村民都交谈一次，成为大家熟悉的朋友。',
      type: QuestType.talk, targetId: 'all_npc', targetCount: 17,
      goldReward: 900, expReward: 250, itemReward: 'friendship_charm', itemRewardCount: 1,
    ),
  ];

  /// 全部 15 个任务（主线在前）。
  static final List<Quest> all = <Quest>[...main, ...side];

  final Map<String, QuestProgress> _progress = <String, QuestProgress>{};

  /// 已交谈过的 NPC ID（用于 all_npc 去重计数）。
  final Set<String> _talkedNpcs = <String>{};

  // ------------------------------------------------------------------ 查询

  /// 全部任务进度。
  List<QuestProgress> get progressList =>
      _progress.values.toList(growable: false);

  /// 按 ID 取进度。
  QuestProgress? progressOf(String questId) => _progress[questId];

  /// 主线任务进度（按 order 排序）。
  List<QuestProgress> get mainProgress => _sorted(main);

  /// 支线任务进度（按 order 排序）。
  List<QuestProgress> get sideProgress => _sorted(side);

  List<QuestProgress> _sorted(List<Quest> src) {
    final List<QuestProgress> list = src
        .map((Quest q) => _progress[q.id]!)
        .toList(growable: true)
      ..sort((QuestProgress a, QuestProgress b) =>
          a.quest.order.compareTo(b.quest.order));
    return list;
  }

  /// 进行中的任务。
  List<QuestProgress> get active => _progress.values
      .where((QuestProgress p) => p.status == QuestStatus.inProgress)
      .toList(growable: false);

  /// 已完成但未领奖的任务。
  List<QuestProgress> get claimable => _progress.values
      .where((QuestProgress p) => p.status == QuestStatus.completed && !p.rewardClaimed)
      .toList(growable: false);

  /// 未开始的任务。
  List<QuestProgress> get locked => _progress.values
      .where((QuestProgress p) => p.status == QuestStatus.notStarted)
      .toList(growable: false);

  /// 已完成任务数（含已领奖）。
  int get completedCount => _progress.values
      .where((QuestProgress p) => p.status == QuestStatus.completed)
      .length;

  /// 总任务数，应为 15。
  static int get count => all.length;

  /// 主线任务数，应为 7。
  static int get mainCount => main.length;

  /// 支线任务数，应为 8。
  static int get sideCount => side.length;

  /// 按类型统计任务数量。
  Map<QuestType, int> countByType() {
    final Map<QuestType, int> m = <QuestType, int>{
      for (final QuestType t in QuestType.values) t: 0,
    };
    for (final Quest q in all) {
      m[q.type] = (m[q.type] ?? 0) + 1;
    }
    return m;
  }

  /// 当前主线任务（第一个未完成的主线任务），全部完成返回 null。
  QuestProgress? get currentMain {
    for (final QuestProgress p in mainProgress) {
      if (p.status != QuestStatus.completed) return p;
    }
    return null;
  }

  // ------------------------------------------------------------------ 事件驱动

  /// 是否可以接受该任务：状态为未开始且前置任务已完成（无副作用）。
  bool canAccept(String questId) {
    final QuestProgress? p = _progress[questId];
    if (p == null || p.status != QuestStatus.notStarted) return false;
    if (p.quest.prerequisiteId.isEmpty) return true;
    final QuestProgress? pre = _progress[p.quest.prerequisiteId];
    return pre != null && pre.status == QuestStatus.completed;
  }

  /// 接受任务：未开始 → 进行中（需前置任务已完成）。
  bool accept(String questId) {
    if (!canAccept(questId)) return false;
    _progress[questId]!.status = QuestStatus.inProgress;
    _unlockDependents(questId);
    return true;
  }

  /// 前置任务完成后，自动解锁以其为前置的任务。
  void _unlockDependents(String completedId) {
    for (final QuestProgress p in _progress.values) {
      if (p.status == QuestStatus.notStarted &&
          p.quest.prerequisiteId == completedId) {
        p.status = QuestStatus.inProgress;
      }
    }
  }

  /// 通用事件分发：根据任务类型与目标 ID 推进所有进行中任务。
  ///
  /// [detailId] 为具体目标 ID（如怪物 ID、作物 ID、NPC ID）；
  /// `any_*` 目标会匹配同类型的任意 detail。
  QuestEventResult onEvent(QuestType type, String detailId, [int amount = 1]) {
    final List<String> advanced = <String>[];
    final List<String> completed = <String>[];

    for (final QuestProgress p in _progress.values) {
      if (p.status != QuestStatus.inProgress) continue;
      if (p.quest.type != type) continue;
      if (!_matches(p.quest, type, detailId)) continue;

      final int before = p.progress;
      p.advance(amount);
      if (p.progress > before) {
        advanced.add(p.quest.id);
        if (p.status == QuestStatus.completed) {
          completed.add(p.quest.id);
          _unlockDependents(p.quest.id);
        }
      }
    }
    return QuestEventResult(advanced: advanced, completed: completed);
  }

  bool _matches(Quest quest, QuestType type, String detailId) {
    final String target = quest.targetId;
    if (target == detailId) return true;
    switch (target) {
      case 'any_monster':
        return type == QuestType.kill;
      case 'any_crop':
        return type == QuestType.collect || type == QuestType.plant;
      case 'any_fish':
        return type == QuestType.fish;
      case 'any_npc':
        return type == QuestType.talk;
      case 'all_npc':
        // 去重由 onTalk 通过 _talkedNpcs 保证，这里只校验事件类型。
        return type == QuestType.talk;
      case 'hoe_tile':
        // 精确匹配已在上方 target == detailId 处理；
        // 其他探索事件（如进入矿洞）不应推进开垦任务。
        return false;
      default:
        return false;
    }
  }

  // ------------------------------------------------------------------ 便捷入口

  /// 记录一次锄地。
  QuestEventResult onHoe() => onEvent(QuestType.explore, 'hoe_tile');

  /// 记录一次种植。
  QuestEventResult onPlant(String cropId) =>
      onEvent(QuestType.plant, cropId);

  /// 记录一次收获。
  QuestEventResult onHarvest(String cropId) =>
      onEvent(QuestType.collect, cropId);

  /// 记录一次击杀。
  QuestEventResult onKill(String monsterId) =>
      onEvent(QuestType.kill, monsterId);

  /// 记录一次钓鱼。
  QuestEventResult onFish([String fishId = 'any_fish']) =>
      onEvent(QuestType.fish, fishId);

  /// 记录一次对话；同一 NPC 只在首次交谈时推进任务
  /// （`any_npc` / `all_npc` 均按去重后的 NPC 数计数）。
  QuestEventResult onTalk(String npcId) {
    if (_talkedNpcs.add(npcId)) {
      return onEvent(QuestType.talk, npcId);
    }
    return const QuestEventResult();
  }

  /// 记录一次探索（进入矿洞、抵达新楼层等）。
  QuestEventResult onExplore(String placeId) =>
      onEvent(QuestType.explore, placeId);

  // ------------------------------------------------------------------ 领奖

  /// 领取奖励，返回 `(金币, 经验, 物品ID, 物品数量)`；不可领取返回 null。
  (int, int, String, int)? claim(String questId) {
    final QuestProgress? p = _progress[questId];
    if (p == null) return null;
    if (p.status != QuestStatus.completed || p.rewardClaimed) return null;
    p.rewardClaimed = true;
    return (p.quest.goldReward, p.quest.expReward, p.quest.itemReward,
        p.quest.itemRewardCount);
  }

  /// 全部主线是否已完成。
  bool get allMainCompleted => main.every(
      (Quest q) => _progress[q.id]?.status == QuestStatus.completed);

  /// 全部任务是否已完成。
  bool get allCompleted =>
      all.every((Quest q) => _progress[q.id]?.status == QuestStatus.completed);

  // ------------------------------------------------------------------ 存档

  /// 导出存档数据。
  Map<String, dynamic> save() => <String, dynamic>{
        'quests': <String, dynamic>{
          for (final QuestProgress p in _progress.values)
            p.quest.id: <String, dynamic>{
              'status': p.status.name,
              'progress': p.progress,
              'rewardClaimed': p.rewardClaimed,
            },
        },
        'talkedNpcs': _talkedNpcs.toList(growable: false),
      };

  /// 载入存档数据。
  void load(Map<String, dynamic> data) {
    final Object? quests = data['quests'];
    if (quests is Map) {
      quests.forEach((Object? key, Object? value) {
        if (key is! String || value is! Map) return;
        final QuestProgress? p = _progress[key];
        if (p == null) return;
        final Object? s = value['status'];
        if (s is String) {
          for (final QuestStatus st in QuestStatus.values) {
            if (st.name == s) p.status = st;
          }
        }
        p.progress = (value['progress'] as num?)?.toInt() ?? 0;
        p.rewardClaimed = value['rewardClaimed'] as bool? ?? false;
      });
    }
    final Object? talked = data['talkedNpcs'];
    if (talked is List) {
      _talkedNpcs
        ..clear()
        ..addAll(talked.whereType<String>());
    }
  }
}
