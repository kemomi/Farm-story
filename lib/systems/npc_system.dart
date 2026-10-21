/// NPC 好感度系统
///
/// 管理 17 位 NPC 的好感度，支持增减好感度、求婚判断
/// （需 800 好感度且可攻略）。
library;

import 'dart:math' as math;

import '../data/crops_data.dart';
import '../models/npc.dart';

/// 好感度等级。
enum AffinityLevel {
  stranger('陌生人', 0),
  acquaintance('相识', 100),
  friend('朋友', 250),
  closeFriend('好友', 450),
  crush('心动', 650),
  inLove('恋人', 800);

  const AffinityLevel(this.label, this.threshold);

  /// 中文名称。
  final String label;

  /// 达到该等级所需好感度。
  final int threshold;

  /// 由好感度值反查等级。
  static AffinityLevel of(int value) {
    AffinityLevel r = AffinityLevel.stranger;
    for (final AffinityLevel lv in AffinityLevel.values) {
      if (value >= lv.threshold) r = lv;
    }
    return r;
  }
}

/// 单个 NPC 的关系数据。
class NpcRelation {
  NpcRelation(this.npc, {this.affinity = 0});

  /// NPC 静态配置。
  final Npc npc;

  /// 当前好感度。
  int affinity;

  /// 本日是否已对话（每日首次对话才加好感）。
  bool talkedToday = false;

  /// 本日已送礼次数。
  int giftsToday = 0;

  /// 累计送礼次数。
  int totalGifts = 0;

  /// 累计对话天数。
  int talkDays = 0;

  /// 是否已求婚成功。
  bool married = false;

  /// 是否已被拒绝。
  bool rejected = false;

  /// 当前好感度等级。
  AffinityLevel get level => AffinityLevel.of(affinity);

  /// 到下一等级还差多少好感度；已满级返回 0。
  int get toNextLevel {
    final int idx = AffinityLevel.values.indexOf(level);
    if (idx >= AffinityLevel.values.length - 1) return 0;
    final int next = AffinityLevel.values[idx + 1].threshold;
    return math.max(0, next - affinity);
  }

  /// 当前等级进度 0~1（用于 UI 进度条）。
  double get levelProgress {
    final int idx = AffinityLevel.values.indexOf(level);
    final int cur = level.threshold;
    final int next = idx >= AffinityLevel.values.length - 1
        ? cur + 1
        : AffinityLevel.values[idx + 1].threshold;
    final int span = next - cur;
    if (span <= 0) return 1;
    final double p = (affinity - cur) / span;
    return p <= 0 ? 0 : (p >= 1 ? 1 : p);
  }
}

/// 系统操作结果。
class NpcActionResult {
  const NpcActionResult({
    required this.success,
    required this.message,
    this.delta = 0,
  });

  /// 是否成功。
  final bool success;

  /// 提示文案。
  final String message;

  /// 好感度变化量。
  final int delta;
}

/// NPC 系统。
class NpcSystem {
  NpcSystem() {
    for (final Npc n in NpcData.all) {
      _relations[n.id] = NpcRelation(n);
    }
  }

  /// 好感度上限。
  static const int maxAffinity = 1000;

  /// 求婚所需好感度。
  static const int marriageThreshold = 800;

  /// 每日首次对话增加的好感度。
  static const int talkGain = 5;

  /// 每日最多送礼次数。
  static const int maxGiftsPerDay = 2;

  /// 送喜欢物品增加的好感度。
  static const int lovedGiftGain = 40;

  /// 送普通物品增加的好感度。
  static const int normalGiftGain = 15;

  /// 送厌恶物品扣除的好感度。
  static const int dislikedGiftLoss = 25;

  /// 生日当天送礼倍率。
  static const int birthdayMultiplier = 3;

  final Map<String, NpcRelation> _relations = <String, NpcRelation>{};

  /// 全部关系数据。
  List<NpcRelation> get relations => _relations.values.toList(growable: false);

  /// 全部 NPC 配置。
  List<Npc> get npcs => NpcData.all;

  /// 取关系数据，找不到返回 null。
  NpcRelation? relationOf(String npcId) => _relations[npcId];

  /// 取指定 NPC 当前好感度。
  int affinityOf(String npcId) => _relations[npcId]?.affinity ?? 0;

  // ------------------------------------------------------------------ 好感度增减

  /// 增加好感度（自动截断到 [maxAffinity]），返回实际增量。
  int increase(String npcId, int amount) {
    final NpcRelation? r = _relations[npcId];
    if (r == null || amount <= 0) return 0;
    final int before = r.affinity;
    r.affinity = math.min(maxAffinity, before + amount);
    return r.affinity - before;
  }

  /// 减少好感度（自动截断到 0），返回实际减量。
  int decrease(String npcId, int amount) {
    final NpcRelation? r = _relations[npcId];
    if (r == null || amount <= 0) return 0;
    final int before = r.affinity;
    r.affinity = math.max(0, before - amount);
    return before - r.affinity;
  }

  /// 直接设置好感度（用于读档/调试）。
  void setAffinity(String npcId, int value) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return;
    r.affinity = math.max(0, math.min(maxAffinity, value));
  }

  /// 批量增加好感度（祭典全员加成等）。
  void increaseAll(int amount) {
    for (final NpcRelation r in _relations.values) {
      r.affinity = math.min(maxAffinity, r.affinity + math.max(0, amount));
    }
  }

  // ------------------------------------------------------------------ 交互

  /// 与 NPC 对话。每日首次有效。
  NpcActionResult talk(String npcId) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return const NpcActionResult(success: false, message: '找不到这位村民');
    if (r.talkedToday) {
      return NpcActionResult(
          success: true, message: '${r.npc.name}：${r.npc.greeting}（今天已经聊过了）');
    }
    r.talkedToday = true;
    r.talkDays++;
    final int gain = increase(npcId, talkGain);
    return NpcActionResult(
      success: true,
      message: '${r.npc.name}：${r.npc.greeting}（好感 +$gain）',
      delta: gain,
    );
  }

  /// 送礼。[crop] 为赠送的作物。
  NpcActionResult giveGift(String npcId, Crop crop, {bool isBirthday = false}) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return const NpcActionResult(success: false, message: '找不到这位村民');
    if (r.giftsToday >= maxGiftsPerDay) {
      return NpcActionResult(
          success: false, message: '${r.npc.name}今天已经收过礼物了');
    }

    int delta;
    String mood;
    if (r.npc.dislikesCrop(crop.id)) {
      delta = -dislikedGiftLoss;
      mood = '皱眉收下了';
    } else if (r.npc.likesCrop(crop.id)) {
      delta = lovedGiftGain;
      mood = '非常开心';
    } else {
      delta = normalGiftGain;
      mood = '微笑着收下了';
    }
    if (isBirthday && delta > 0) {
      delta *= birthdayMultiplier;
      mood = '惊喜地收下了生日礼物';
    }

    final int applied = delta >= 0 ? increase(npcId, delta) : -decrease(npcId, -delta);
    r.giftsToday++;
    r.totalGifts++;

    return NpcActionResult(
      success: true,
      message: '${r.npc.name}$mood（好感 ${applied >= 0 ? '+' : ''}$applied）',
      delta: applied,
    );
  }

  // ------------------------------------------------------------------ 求婚

  /// 是否满足求婚条件：可攻略 + 好感度 ≥ 800 + 未结婚。
  bool canPropose(String npcId) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return false;
    return r.npc.marriageable &&
        r.affinity >= marriageThreshold &&
        !r.married;
  }

  /// 求婚失败的原因说明；满足条件时返回 null。
  String? proposeBlocker(String npcId) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return '找不到这位村民';
    if (!r.npc.marriageable) return '${r.npc.name}并不是可攻略的对象';
    if (r.married) return '你已经和${r.npc.name}结婚了';
    if (r.affinity < marriageThreshold) {
      return '好感度不足，还需要 ${marriageThreshold - r.affinity} 点';
    }
    return null;
  }

  /// 求婚。成功返回 true 并标记已婚。
  NpcActionResult propose(String npcId) {
    final NpcRelation? r = _relations[npcId];
    if (r == null) return const NpcActionResult(success: false, message: '找不到这位村民');

    final String? blocker = proposeBlocker(npcId);
    if (blocker != null) {
      // 好感度足够但被拒绝的情况较少见；此处按条件不足统一处理。
      if (r.npc.marriageable &&
          !r.married &&
          r.affinity >= marriageThreshold - 100) {
        r.rejected = true;
        final int loss = decrease(npcId, 50);
        return NpcActionResult(
          success: false,
          message: '${r.npc.name}婉拒了你的求婚（好感 -$loss）',
          delta: -loss,
        );
      }
      return NpcActionResult(success: false, message: blocker);
    }

    r.married = true;
    r.rejected = false;
    return NpcActionResult(
      success: true,
      message: '${r.npc.name}接受了你的求婚！你们结婚了 🎉',
    );
  }

  /// 可求婚的 NPC 列表。
  List<NpcRelation> get proposable => _relations.values
      .where((NpcRelation r) => canPropose(r.npc.id))
      .toList(growable: false);

  /// 已结婚对象，未婚返回 null。
  NpcRelation? get spouse {
    for (final NpcRelation r in _relations.values) {
      if (r.married) return r;
    }
    return null;
  }

  // ------------------------------------------------------------------ 日期与统计

  /// 每日刷新：重置当日对话与送礼计数。
  void onNewDay() {
    for (final NpcRelation r in _relations.values) {
      r.talkedToday = false;
      r.giftsToday = 0;
    }
  }

  /// 按好感度降序排列的关系列表。
  List<NpcRelation> get rankedByAffinity {
    // relations 返回的是定长列表，直接排序会抛 UnsupportedError，需先复制。
    final List<NpcRelation> list = List<NpcRelation>.of(relations)
      ..sort((NpcRelation a, NpcRelation b) => b.affinity.compareTo(a.affinity));
    return list;
  }

  /// 好感度达到指定等级的 NPC 数量。
  int countAtLeast(int affinity) => _relations.values
      .where((NpcRelation r) => r.affinity >= affinity)
      .length;

  /// 平均好感度。
  double get averageAffinity {
    if (_relations.isEmpty) return 0;
    final int sum = _relations.values
        .fold(0, (int a, NpcRelation r) => a + r.affinity);
    return sum / _relations.length;
  }

  /// 导出数据（存档用）。
  Map<String, dynamic> save() => <String, dynamic>{
        for (final NpcRelation r in _relations.values)
          r.npc.id: <String, dynamic>{
            'affinity': r.affinity,
            'totalGifts': r.totalGifts,
            'talkDays': r.talkDays,
            'married': r.married,
            'rejected': r.rejected,
          },
      };

  /// 载入数据（读档用）。
  void load(Map<String, dynamic> data) {
    data.forEach((String key, dynamic value) {
      final NpcRelation? r = _relations[key];
      if (r == null || value is! Map) return;
      r.affinity = (value['affinity'] as num?)?.toInt() ?? 0;
      r.totalGifts = (value['totalGifts'] as num?)?.toInt() ?? 0;
      r.talkDays = (value['talkDays'] as num?)?.toInt() ?? 0;
      r.married = value['married'] as bool? ?? false;
      r.rejected = value['rejected'] as bool? ?? false;
    });
  }
}
