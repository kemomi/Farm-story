/// 游戏世界（核心）
///
/// 包含点击移动、CustomPaint 绘制、相机跟随、田地管理。
/// 玩家点击地面后自动移动至目标位置，相机跟随玩家视角。
///
/// 核心玩法循环：
/// 点击地面移动 → 锄地 → 播种 → 作物生长（实时计算） → 收获 → 销售获得金币 → 购买更多种子/工具
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/crops_data.dart';
import '../models/field.dart';
import '../models/mine_floor.dart';
import '../models/monster.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../systems/festival_system.dart';
import '../systems/npc_system.dart';
import '../systems/quest_system.dart';
import '../ui/bottom_bar.dart';
import '../ui/top_bar.dart';
import 'camera.dart';
import '../systems/audio_system.dart';
import '../systems/effect_system.dart';

/// 游戏世界主组件。
class GameWorld extends StatefulWidget {
  const GameWorld({super.key});

  @override
  State<GameWorld> createState() => GameWorldState();
}

/// 待执行动作类型（玩家走到目标后再执行）。
enum _PendingKind { none, tileAction, npcInteract, mineMove }

/// 游戏世界状态：持有全部游戏对象与主循环。
class GameWorldState extends State<GameWorld> with SingleTickerProviderStateMixin {
  // ------------------------------------------------------------------ 世界常量

  /// 农场世界宽度。
  static const double kWorldWidth = 7200;

  /// 农场世界高度。
  static const double kWorldHeight = 1200;

  /// 地平线 Y（NPC 与建筑站立处）。
  static const double kHorizonY = 520;

  /// 玩家可行走区域上边界。
  static const double kWalkMinY = kHorizonY;

  /// 玩家可行走区域下边界。
  static const double kWalkMaxY = 1140;

  /// 田地网格左上角 X。
  static const double kFieldOriginX = 320;

  /// 田地网格左上角 Y。
  static const double kFieldOriginY = 540;

  /// 矿洞入口世界坐标 X。
  static const double kMineEntranceX = 4300;

  /// 可钓鱼的水域范围（湖畔与码头）。
  static const List<(double, double)> kWaterSpots = <(double, double)>[
    (1820, 2000),
    (2420, 2620),
  ];

  /// 时间流速：现实 1 秒推进的游戏分钟数（默认 6，即现实 4 分钟 = 游戏 1 天）。
  static const double kGameMinutesPerSecond = 6;

  /// 每天小时数。
  static const int kHoursPerDay = 24;

  /// 每季天数。
  static const int kDaysPerSeason = 28;

  /// 参与日历轮换的四季（温室不参与）。
  static const List<Season> kCalendarSeasons = <Season>[
    Season.spring,
    Season.summer,
    Season.autumn,
    Season.winter,
  ];

  /// 物品 ID → 中文名。
  static const Map<String, String> kItemNames = <String, String>{
    'flower_seed': '花种',
    'rare_seed_pack': '稀有种子包',
    'fish_big': '大鱼',
    'fish_normal': '普通的鱼',
    'golden_rod': '黄金钓竿',
    'fishing_rod_pro': '高级钓竿',
    'harvest_trophy': '丰收奖杯',
    'harvest_medal': '丰收勋章',
    'steel_hoe': '钢制锄头',
    'legendary_hoe': '传说锄头',
    'lantern': '星夜灯笼',
    'winter_supplies': '过冬物资',
    'seed_pack_spring': '春季种子包',
    'iron_sword': '铁剑',
    'friendship_charm': '友情护符',
    'slime_gel': '史莱姆凝胶',
    'bat_wing': '蝙蝠翅膀',
    'copper_ore': '铜矿石',
    'iron_ore': '铁矿石',
    'bone': '骨头',
    'silk': '蛛丝',
    'dragon_scale': '龙鳞',
  };

  // ------------------------------------------------------------------ 游戏对象

  /// 玩家。
  final Player player = Player(x: 620, y: kWalkMaxY - 120);

  /// 相机。
  final Camera camera = Camera(worldWidth: kWorldWidth, worldHeight: kWorldHeight);

  /// 田地管理器（20×15）。
  final FieldManager fields = FieldManager();

  /// NPC 系统。
  final NpcSystem npcSystem = NpcSystem();

  /// 祭典系统。
  final FestivalSystem festivalSystem = FestivalSystem();

  /// 任务系统。
  final QuestSystem questSystem = QuestSystem();

  /// 采矿管理器（7 层）。
  final MineManager mineManager = MineManager();

  /// 背包：作物 ID → 数量。
  final Map<String, int> bag = <String, int>{};

  /// 物品栏：物品 ID → 数量。
  final Map<String, int> items = <String, int>{};

  /// 随机数发生器。
  final math.Random rng = math.Random();

  /// 音频系统：BGM 与音效。
  final AudioSystem audio = AudioSystem();

  /// 粒子特效系统。
  final EffectSystem effects = EffectSystem();

  /// 动画计时器（累计真实秒数，驱动摇摆/涟漪/云朵等循环动画）。
  double animTime = 0;

  // ------------------------------------------------------------------ 运行时状态

  /// 游戏内累计分钟数（0 ~ 1440）。
  double gameMinutes = 6 * 60;

  /// 当前日（1~28）。
  int day = 1;

  /// 当前季节索引（对应 [kCalendarSeasons]）。
  int seasonIndex = 0;

  /// 当前年。
  int year = 1;

  /// 是否处于矿洞场景。
  bool inMine = false;

  /// 当前选中的底栏工具。
  ToolType selectedTool = ToolType.hoe;

  /// 当前选中的种子（播种用）。
  Crop? selectedCrop;

  /// 装备武器加成（攻击力）。
  int weaponBonus = 0;

  /// 顶部提示文案。
  String toast = '点击地面移动，选择工具后点击田地开始耕作';

  /// 提示剩余显示时间（秒）。
  double toastTimer = 6;

  /// 祭典邀请弹窗是否已显示（防止同一祭典重复叠加弹窗）。
  bool _festivalDialogShown = false;

  /// 主循环 Ticker。
  late final Ticker _ticker;

  /// 上一帧时间戳。
  Duration? _lastElapsed;

  /// 待执行动作。
  _PendingKind _pending = _PendingKind.none;

  /// 待操作的田块列。
  int _pendingCol = 0;

  /// 待操作的田块行。
  int _pendingRow = 0;

  /// 待交互的 NPC。
  Npc? _pendingNpc;

  /// 玩家攻击力。
  int get playerAttack => 8 + player.level * 2 + weaponBonus;

  /// 玩家防御力。
  int get playerDefense => 2 + player.level;

  /// 当前季节。
  Season get season => kCalendarSeasons[seasonIndex];

  /// 当前小时（0~23）。
  int get hourOfDay => (gameMinutes ~/ 60).toInt() % kHoursPerDay;

  /// 时间文案，如 `08:30`。
  String get timeLabel {
    final int h = hourOfDay;
    final int m = (gameMinutes % 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 日期文案。
  String get dayLabel => '第 $day 天';

  /// 地点文案。
  String get locationLabel {
    if (inMine) {
      return '矿洞 第 ${mineManager.currentFloor} 层';
    }
    if (player.x < 1300) return '我的牧场';
    if ((player.x - kMineEntranceX).abs() < 200) return '矿洞入口';
    final Npc n = NpcData.nearest(player.x);
    return '${n.locationAtHour(hourOfDay)}附近';
  }

  @override
  void initState() {
    super.initState();
    camera.snapTo(player.x, player.y);
    _ticker = createTicker(_onTick)..start();
    audio.init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    audio.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ 主循环

  void _onTick(Duration elapsed) {
    final Duration? last = _lastElapsed;
    _lastElapsed = elapsed;
    // 组件已销毁时立即退出：_update 链路可能弹出对话框，
    // 使用失效的 context 会抛异常。
    if (!mounted) return;
    final double raw = last == null
        ? 0
        : (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    // 限制单帧步长，避免切后台回来后一次推进过多。
    final double dt = math.max(0, math.min(0.1, raw));
    _update(dt);
    if (mounted) setState(() {});
  }

  void _update(double dt) {
    if (dt <= 0) return;

    // 0) 动画计时与粒子推进
    animTime += dt;
    effects.update(dt);

    // 1) 玩家移动插值
    player.update(dt);

    // 2) 到达目标后执行待处理动作
    if (!player.isMoving && _pending != _PendingKind.none) {
      final _PendingKind kind = _pending;
      _pending = _PendingKind.none;
      switch (kind) {
        case _PendingKind.tileAction:
          _performTileAction(_pendingCol, _pendingRow);
          break;
        case _PendingKind.npcInteract:
          final Npc? n = _pendingNpc;
          _pendingNpc = null;
          if (n != null) _openNpcDialog(n);
          break;
        case _PendingKind.mineMove:
          _performMineAction(_pendingCol, _pendingRow);
          break;
        case _PendingKind.none:
          break;
      }
    }

    // 3) 相机跟随
    camera.follow(player.x, player.y - Player.height / 2, dt: dt);

    // 4) 游戏时钟与作物实时生长
    if (!inMine) {
      final double minutes = dt * kGameMinutesPerSecond;
      gameMinutes += minutes;
      fields.updateHours(minutes / 60);
      while (gameMinutes >= kHoursPerDay * 60) {
        gameMinutes -= kHoursPerDay * 60;
        _onNewDay();
      }
    }

    // 5) 提示计时
    if (toastTimer > 0) {
      toastTimer -= dt;
      if (toastTimer <= 0) toast = '';
    }
  }

  /// 显示一条提示。
  void showToast(String message, {double duration = 3}) {
    toast = message;
    toastTimer = duration;
  }

  // ------------------------------------------------------------------ 日历推进

  void _onNewDay() {
    day++;
    if (day > kDaysPerSeason) {
      day = 1;
      seasonIndex++;
      if (seasonIndex >= kCalendarSeasons.length) {
        seasonIndex = 0;
        year++;
        festivalSystem.onNewYear();
        showToast('新的一年开始了！（第 $year 年）', duration: 4);
      }
      final int withered = fields.applySeasonChange(season);
      if (withered > 0) {
        showToast('${season.label}到了，有 $withered 块作物因季节不符而枯萎', duration: 4);
      } else {
        showToast('${season.label}到了！', duration: 3);
      }
    }

    npcSystem.onNewDay();
    player.restoreStamina(player.maxStamina);

    final Festival? f = festivalSystem.todayFestival(season, day);
    if (f != null && !festivalSystem.hasAttended(f.id)) {
      showToast('今天是「${f.name}」！前往广场参加吧', duration: 5);
      _offerFestival(f);
    }
  }

  /// 当前季节与时间文案（供顶栏）。
  String get seasonLabel => '${season.label} 第 $year 年';

  // ------------------------------------------------------------------ 点击处理

  /// 处理屏幕点击（坐标为视口内局部坐标）。
  void _handleTap(double sx, double sy) {
    final double wx = camera.toWorldX(sx);
    final double wy = camera.toWorldY(sy);
    if (inMine) {
      _handleMineTap(wx, wy);
      return;
    }

    // 1) 优先判定 NPC
    final Npc? npc = _npcAt(wx, wy);
    if (npc != null) {
      // NPC 按行程移动，需走向其当前时刻所在位置而非默认坐标。
      _walkTo(npc.xAtHour(hourOfDay), kHorizonY + 30);
      _pending = _PendingKind.npcInteract;
      _pendingNpc = npc;
      return;
    }

    // 2) 判定矿洞入口
    if ((wx - kMineEntranceX).abs() < 60 && wy < kHorizonY + 80) {
      _walkTo(kMineEntranceX, kHorizonY + 20);
      showToast('抵达矿洞入口，点击底栏「工具」→「进入矿洞」', duration: 3);
      return;
    }

    // 3) 判定田地
    final FieldTile? tile = fields.tileAtWorld(wx, wy,
        originX: kFieldOriginX, originY: kFieldOriginY);
    if (tile != null) {
      final double tx = kFieldOriginX + tile.col * fields.tileSize + fields.tileSize / 2;
      final double ty = (kFieldOriginY + tile.row * fields.tileSize + fields.tileSize / 2)
          .clamp(kWalkMinY, kWalkMaxY)
          .toDouble();
      _walkTo(tx, ty);
      _pending = _PendingKind.tileAction;
      _pendingCol = tile.col;
      _pendingRow = tile.row;
      return;
    }

    // 4) 普通移动
    _walkTo(wx, wy.clamp(kWalkMinY, kWalkMaxY).toDouble());
  }

  void _walkTo(double wx, double wy) {
    final double y = wy.clamp(kWalkMinY, kWalkMaxY).toDouble();
    player.moveTo(wx, y, minX: 40, maxX: kWorldWidth - 40);
  }

  Npc? _npcAt(double wx, double wy) {
    for (final Npc n in NpcData.all) {
      final double nx = n.xAtHour(hourOfDay);
      if ((wx - nx).abs() <= 34 && (wy - (n.y - 20)).abs() <= 40) return n;
    }
    return null;
  }

  // ------------------------------------------------------------------ 田地操作

  /// 计算田块世界坐标中心。
  (double, double) _tileWorldPos(int col, int row) => (
        kFieldOriginX + col * fields.tileSize + fields.tileSize / 2,
        kFieldOriginY + row * fields.tileSize + fields.tileSize / 2,
      );

  /// 执行田块操作（玩家已走到田块上）。
  void _performTileAction(int col, int row) {
    final FieldTile? tile = fields.tileAt(col, row);
    if (tile == null) return;

    // 上下文智能动作：成熟先收获，枯萎先清理。
    if (tile.state.canHarvest) {
      _doHarvest(col, row);
      return;
    }
    if (tile.state == TileState.withered) {
      final FieldResult r = fields.clearWithered(col, row);
      showToast(r.message, duration: 2);
      player.playAction(PlayerAction.hoeing);
      final (double wx, double wy) = _tileWorldPos(col, row);
      effects.hoe(wx, wy);
      audio.playSfx('hoe');
      return;
    }

    switch (selectedTool) {
      case ToolType.hoe:
        final FieldResult r = fields.hoe(col, row, hasStamina: _canUseStamina);
        _applyFieldResult(r, col, row);
        if (r.success) {
          player.playAction(PlayerAction.hoeing);
          questSystem.onHoe();
          final (double wx, double wy) = _tileWorldPos(col, row);
          effects.hoe(wx, wy);
          audio.playSfx('hoe');
        }
        break;
      case ToolType.seed:
        if (selectedCrop == null) {
          showToast('还没有选择种子，点击「工具」→「种子商店」', duration: 3);
          return;
        }
        final FieldResult r = fields.plant(
          col,
          row,
          selectedCrop,
          DateTime.now().millisecondsSinceEpoch,
          hasStamina: _canUseStamina,
          hasGold: player.canAfford,
        );
        _applyFieldResult(r, col, row);
        if (r.success) {
          player.playAction(PlayerAction.planting);
          questSystem.onPlant(selectedCrop!.id);
          final (double wx, double wy) = _tileWorldPos(col, row);
          effects.plant(wx, wy);
          audio.playSfx('plant');
        }
        break;
      case ToolType.tool:
        if (tile.state == TileState.empty) {
          showToast('先用「锄地」工具开垦这块地', duration: 2);
        } else {
          showToast('当前田块状态：${tile.state.label}', duration: 2);
        }
        break;
      case ToolType.npc:
      case ToolType.bag:
        showToast('点击田地请使用锄地或播种工具', duration: 2);
        break;
    }
  }

  bool _canUseStamina(int cost) => player.stamina >= cost;

  /// 结算田地操作结果：扣体力/金币、加金币、提示。
  void _applyFieldResult(FieldResult r, int col, int row) {
    showToast(r.message, duration: 2);
    if (!r.success) return;
    if (r.staminaCost > 0) player.useStamina(r.staminaCost);
    if (r.goldCost > 0) player.spendGold(r.goldCost);
    if (r.gain > 0) player.addGold(r.gain);
  }

  void _doHarvest(int col, int row) {
    final FieldTile? tile = fields.tileAt(col, row);
    final Crop? crop = tile?.crop;
    final FieldResult r = fields.harvest(col, row, hasStamina: _canUseStamina);
    if (r.success) {
      if (r.staminaCost > 0) player.useStamina(r.staminaCost);
      player.playAction(PlayerAction.harvesting);
      final (double wx, double wy) = _tileWorldPos(col, row);
      effects.harvest(wx, wy);
      effects.coin(wx, wy - 20);
      audio.playSfx('harvest');
      audio.playSfx('coin');
      // 收获进入背包，需在背包中出售换取金币。
      if (crop != null) {
        bag[crop.id] = (bag[crop.id] ?? 0) + 1;
        questSystem.onHarvest(crop.id);
        player.gainExp(5);
      }
    }
    showToast(r.message, duration: 2);
  }

  // ------------------------------------------------------------------ 出售与背包

  /// 出售背包中指定作物。
  int sellCrop(String cropId, [int amount = 1]) {
    final Crop? c = CropsData.byId(cropId);
    final int have = bag[cropId] ?? 0;
    if (c == null || have <= 0) return 0;
    final int n = math.min(have, math.max(1, amount));
    final int gold = c.price * n;
    bag[cropId] = have - n;
    if (bag[cropId] == 0) bag.remove(cropId);
    player.addGold(gold);
    return gold;
  }

  /// 出售背包全部作物，返回总收益。
  int sellAll() {
    int total = 0;
    for (final String id in bag.keys.toList(growable: false)) {
      total += sellCrop(id, bag[id] ?? 0);
    }
    return total;
  }

  /// 背包物品总数。
  int get bagCount => bag.values.fold(0, (int a, int b) => a + b);

  /// 物品栏总数。
  int get itemCount => items.values.fold(0, (int a, int b) => a + b);

  bool hasItem(String id) => (items[id] ?? 0) > 0 || (bag[id] ?? 0) > 0;

  void addItem(String id, [int n = 1]) {
    if (id.isEmpty || n <= 0) return;
    items[id] = (items[id] ?? 0) + n;
  }

  // ------------------------------------------------------------------ 底栏工具

  void _onToolSelected(ToolType t) {
    switch (t) {
      case ToolType.hoe:
      case ToolType.seed:
        setState(() => selectedTool = t);
        if (t == ToolType.seed && selectedCrop == null) {
          showToast('先选择种子：点击「工具」→「种子商店」', duration: 3);
        } else {
          showToast(t == ToolType.hoe ? '锄地模式：点击空地开垦，点击成熟作物收获' : '播种模式：${selectedCrop?.name ?? ''}，点击已开垦土地播种', duration: 3);
        }
        break;
      case ToolType.tool:
        _openToolMenu();
        break;
      case ToolType.npc:
        _openNpcList();
        break;
      case ToolType.bag:
        _openBag();
        break;
    }
  }

  void _openToolMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _sheetTitle('工具与操作'),
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFFFFE066)),
              title: const Text('种子商店（购买并选择种子）',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('${season.label}当季作物',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _openSeedShop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.water, color: Color(0xFF7BD3F0)),
              title: const Text('钓鱼', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('需站在水边（湖畔 / 码头）',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _goFishing();
              },
            ),
            ListTile(
              leading: const Icon(Icons.landscape, color: Color(0xFFC8A165)),
              title: Text(inMine ? '离开矿洞' : '进入矿洞（7 层）',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                  inMine
                      ? '返回地面牧场'
                      : '当前位于第 ${mineManager.currentFloor == 0 ? 1 : mineManager.currentFloor} 层',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                if (inMine) {
                  _leaveMine();
                } else {
                  _enterMine();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Color(0xFFFFB347)),
              title: const Text('任务列表', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('已完成 ${questSystem.completedCount}/${QuestSystem.count}',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _openQuestPanel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.nightlife, color: Color(0xFFF0A5C0)),
              title: const Text('祭典日历', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('共 ${FestivalSystem.count} 个祭典，今年已参加 ${festivalSystem.attendedCount} 个',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _openFestivalPanel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.hotel, color: Color(0xFF9BE36B)),
              title: const Text('睡觉进入第二天', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('恢复全部体力，作物继续生长',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _sleep();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: <Widget>[
            Text(text,
                style: const TextStyle(
                    color: Color(0xFF9BE36B),
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$seasonLabel · $dayLabel $timeLabel',
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
          ],
        ),
      );

  /// 睡觉：推进到第二天早上 6 点。
  void _sleep() {
    if (inMine) {
      showToast('在矿洞里无法睡觉，先回到地面', duration: 2);
      return;
    }
    final double minutesToNextDay = kHoursPerDay * 60 - gameMinutes + 6 * 60;
    final double hours = minutesToNextDay / 60;
    fields.updateHours(hours);
    gameMinutes = 6 * 60;
    _onNewDay();
    audio.playSfx('sleep');
    showToast('睡了一觉，体力完全恢复！', duration: 3);
  }

  /// 种子商店：选择当季种子。
  void _openSeedShop() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext c, StateSetter setSheetState) => SizedBox(
          height: MediaQuery.of(c).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _sheetTitle('种子商店 · ${season.label}（金币 ${player.gold}）'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: <Widget>[
                    for (final Crop c2 in CropsData.bySeason(season))
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(c2.color),
                          child: const Text('', style: TextStyle(fontSize: 1)),
                        ),
                        title: Text(
                          '${c2.name}　种子 ${c2.seedCost} 金 / 售价 ${c2.price} 金',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        subtitle: Text(
                          '生长 ${c2.growHours}h · ${c2.stages} 阶段 · ${c2.regrow ? '可再生' : '一次性'}',
                          style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11),
                        ),
                        trailing: Text(
                          selectedCrop?.id == c2.id ? '已选中' : '选择',
                          style: TextStyle(
                            color: selectedCrop?.id == c2.id
                                ? const Color(0xFF9BE36B)
                                : const Color(0xCCFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          setSheetState(() {
                            selectedCrop = c2;
                            selectedTool = ToolType.seed;
                          });
                          setState(() {});
                          showToast('已选择「${c2.name}」，点击已开垦的土地播种（每次扣 ${c2.seedCost} 金）', duration: 3);
                        },
                      ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('关闭'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 背包：查看与出售。
  void _openBag() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext c, StateSetter setSheetState) => SizedBox(
          height: MediaQuery.of(c).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _sheetTitle('背包（作物 $bagCount 件 · 物品 $itemCount 件 · 金币 ${player.gold}）'),
              if (bag.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      const Text('作物', style: TextStyle(color: Color(0xFF9BE36B), fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final int g = sellAll();
                          setSheetState(() {});
                          setState(() {});
                          showToast(g > 0 ? '全部出售，获得 $g 金币' : '没有可出售的作物');
                        },
                        icon: const Icon(Icons.sell, size: 14, color: Color(0xFFFFE066)),
                        label: const Text('全部出售', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: <Widget>[
                    for (final MapEntry<String, int> e in bag.entries)
                      if (e.value > 0)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(CropsData.byId(e.key)?.color ?? 0xFF888888),
                            child: const Text('', style: TextStyle(fontSize: 1)),
                          ),
                          title: Text('${CropsData.byId(e.key)?.name ?? e.key} × ${e.value}',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text('单价 ${CropsData.byId(e.key)?.price ?? 0} 金',
                              style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextButton(
                                onPressed: () {
                                  final int g = sellCrop(e.key, 1);
                                  setSheetState(() {});
                                  setState(() {});
                                  showToast('出售 1 个，+$g 金币');
                                },
                                child: const Text('卖 1', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () {
                                  final int g = sellCrop(e.key, e.value);
                                  setSheetState(() {});
                                  setState(() {});
                                  showToast('全部出售，+$g 金币');
                                },
                                child: const Text('全卖', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                    if (bag.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('背包里还没有作物，去田里收获吧',
                            style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 12)),
                      ),
                    if (items.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                        child: Text('物品', style: TextStyle(color: Color(0xFF9BE36B), fontSize: 12)),
                      ),
                    for (final MapEntry<String, int> e in items.entries)
                      if (e.value > 0)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.card_giftcard,
                              size: 16, color: Color(0xFFFFE066)),
                          title: Text('${kItemNames[e.key] ?? e.key} × ${e.value}',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('关闭'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ NPC 交互

  void _openNpcList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      isScrollControlled: true,
      builder: (BuildContext ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _sheetTitle('村民（${NpcData.count} 位）'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  for (final NpcRelation rel in npcSystem.rankedByAffinity)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(rel.npc.color),
                        child: Text(rel.npc.name.substring(0, 1),
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text(
                        '${rel.npc.name} · ${rel.npc.job}${rel.npc.marriageable ? '（可攻略）' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${rel.level.label} 好感 ${rel.affinity}${rel.married ? ' · 已婚' : ''}',
                        style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _walkTo(rel.npc.xAtHour(hourOfDay), kHorizonY + 30);
                          _pending = _PendingKind.npcInteract;
                          _pendingNpc = rel.npc;
                        },
                        child: const Text('前往', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNpcDialog(Npc npc) {
    final NpcRelation? rel = npcSystem.relationOf(npc.id);
    if (rel == null) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xF5243B24),
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(npc.color),
              child: Text(npc.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('${npc.name} · ${npc.job}',
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                  Text('好感 ${rel.affinity}/1000 · ${rel.level.label}${rel.married ? ' · 已婚' : ''}',
                      style: const TextStyle(color: Color(0xFF9BE36B), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '「${npc.greeting}」\n\n位置：${npc.locationAtHour(hourOfDay)}\n'
            '生日：${npc.birthday}\n'
            '喜欢：${npc.likes.map((String id) => CropsData.byId(id)?.name ?? id).join('、')}\n'
            '厌恶：${npc.dislikes.map((String id) => CropsData.byId(id)?.name ?? id).join('、')}',
            style: const TextStyle(color: Color(0xEEFFFFFF), fontSize: 12, height: 1.5),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              final NpcActionResult r = npcSystem.talk(npc.id);
              questSystem.onTalk(npc.id);
              Navigator.pop(ctx);
              showToast(r.message, duration: 3);
              setState(() {});
            },
            child: const Text('对话'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openGiftPicker(npc);
            },
            child: const Text('送礼'),
          ),
          if (npcSystem.canPropose(npc.id))
            TextButton(
              onPressed: () {
                final NpcActionResult r = npcSystem.propose(npc.id);
                Navigator.pop(ctx);
                showToast(r.message, duration: 4);
                setState(() {});
              },
              child: const Text('求婚', style: TextStyle(color: Color(0xFFFF9BB3))),
            ),
          TextButton(
            onPressed: () {
              final String? blocker = npcSystem.proposeBlocker(npc.id);
              Navigator.pop(ctx);
              if (blocker != null) showToast(blocker, duration: 3);
            },
            child: const Text('离开'),
          ),
        ],
      ),
    );
  }

  void _openGiftPicker(Npc npc) {
    if (bag.isEmpty) {
      showToast('背包里没有可以送出的作物', duration: 2);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _sheetTitle('送给 ${npc.name} 的礼物'),
            for (final MapEntry<String, int> e in bag.entries)
              if (e.value > 0)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 11,
                    backgroundColor: Color(CropsData.byId(e.key)?.color ?? 0xFF888888),
                    child: const Text('', style: TextStyle(fontSize: 1)),
                  ),
                  title: Text('${CropsData.byId(e.key)?.name ?? e.key} × ${e.value}',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: npc.likesCrop(e.key)
                      ? const Text('喜欢', style: TextStyle(color: Color(0xFF9BE36B), fontSize: 12))
                      : npc.dislikesCrop(e.key)
                          ? const Text('厌恶', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12))
                          : const Text('普通', style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 12)),
                  onTap: () {
                    final Crop? c = CropsData.byId(e.key);
                    if (c == null) return;
                    bag[e.key] = e.value - 1;
                    if (bag[e.key] == 0) bag.remove(e.key);
                    final NpcActionResult r = npcSystem.giveGift(npc.id, c);
                    Navigator.pop(ctx);
                    showToast(r.message, duration: 3);
                    setState(() {});
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 祭典

  void _offerFestival(Festival f) {
    // 组件已销毁或已有弹窗时不再重复叠加。
    if (!mounted || _festivalDialogShown) return;
    _festivalDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xF5243B24),
        title: Text('${f.name}（${f.type.label}）',
            style: const TextStyle(color: Color(0xFFFFE066), fontSize: 16)),
        content: Text(
          '${f.description}\n\n地点：${f.location}\n'
          '需要等级：${f.minLevel}　体力消耗：${f.staminaCost}\n'
          '奖励：${f.goldReward} 金币、${f.expReward} 经验'
          '${f.staminaReward > 0 ? '、${f.staminaReward} 体力' : ''}'
          '${f.affinityReward > 0 ? '、全村好感 +${f.affinityReward}' : ''}',
          style: const TextStyle(color: Color(0xEEFFFFFF), fontSize: 12, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('暂不参加'),
          ),
          TextButton(
            onPressed: () {
              final FestivalResult r = _attendFestival(f);
              Navigator.pop(ctx);
              showToast(r.message, duration: 4);
            },
            child: const Text('参加'),
          ),
        ],
      ),
    ).then((_) => _festivalDialogShown = false);
  }
  FestivalResult _attendFestival(Festival f) {
    final FestivalResult r = festivalSystem.attend(
      f,
      season: season,
      day: day,
      playerLevel: player.level,
      playerStamina: player.stamina,
      hasItem: hasItem,
    );
    if (!r.allowed) return r;

    if (f.staminaCost > 0) player.useStamina(f.staminaCost);
    if (r.goldReward > 0) player.addGold(r.goldReward);
    if (r.staminaReward > 0) player.restoreStamina(r.staminaReward);
    if (r.expReward > 0) {
      final int lv = player.gainExp(r.expReward);
      if (lv > 0) {
        effects.levelUp(player.x, player.y - 30);
        audio.playSfx('levelup');
        showToast('等级提升！现在是 Lv.${player.level}', duration: 4);
      }
    }
    if (r.affinityReward > 0) npcSystem.increaseAll(r.affinityReward);
    if (r.itemReward.isNotEmpty) addItem(r.itemReward);
    // 前往祭典地点
    player.stopMoving();
    _walkTo(900, kHorizonY + 20);
    setState(() {});
    return r;
  }

  void _openFestivalPanel() {
    final (Festival, int)? next = festivalSystem.nextFestival(season, day);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      isScrollControlled: true,
      builder: (BuildContext ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _sheetTitle('祭典日历（共 ${FestivalSystem.count} 个）'),
            if (next != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                    '下一个：${next.$1.name}（${next.$1.season.label}${next.$1.day}日，'
                    '${next.$2 == 0 ? '就是今天' : '${next.$2} 天后'}）',
                    style: const TextStyle(color: Color(0xFFFFE066), fontSize: 12)),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  for (final Festival f in festivalSystem.festivals)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        f.type == FestivalType.celebration
                            ? Icons.celebration
                            : f.type == FestivalType.contest
                                ? Icons.emoji_events
                                : Icons.storefront,
                        size: 18,
                        color: festivalSystem.hasAttended(f.id)
                            ? const Color(0x66FFFFFF)
                            : const Color(0xFFFFB347),
                      ),
                      title: Text(
                        '${f.name} · ${f.season.label}${f.day}日 · ${f.type.label}'
                        '${festivalSystem.hasAttended(f.id) ? '（已参加）' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(f.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11)),
                      trailing: (f.occursOn(season, day) && !festivalSystem.hasAttended(f.id))
                          ? TextButton(
                              onPressed: () {
                                final FestivalResult r = _attendFestival(f);
                                Navigator.pop(ctx);
                                showToast(r.message, duration: 4);
                              },
                              child: const Text('参加', style: TextStyle(fontSize: 12)),
                            )
                          : null,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 任务

  void _openQuestPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0223B22),
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext c, StateSetter setSheetState) => SizedBox(
          height: MediaQuery.of(c).size.height * 0.65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _sheetTitle('任务（已完成 ${questSystem.completedCount}/${QuestSystem.count}）'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 8, 8, 2),
                      child: Text('主线任务（7）',
                          style: TextStyle(color: Color(0xFFFFE066), fontSize: 12)),
                    ),
                    for (final QuestProgress p in questSystem.mainProgress)
                      _questTile(p, ctx, setSheetState),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 12, 8, 2),
                      child: Text('支线任务（8）',
                          style: TextStyle(color: Color(0xFF9BE36B), fontSize: 12)),
                    ),
                    for (final QuestProgress p in questSystem.sideProgress)
                      _questTile(p, ctx, setSheetState),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questTile(QuestProgress p, BuildContext ctx, StateSetter setSheetState) {
    final bool canClaim = p.status == QuestStatus.completed && !p.rewardClaimed;
    final Color titleColor = p.status == QuestStatus.completed
        ? const Color(0x88FFFFFF)
        : p.status == QuestStatus.inProgress
            ? Colors.white
            : const Color(0x66FFFFFF);

    return ListTile(
      dense: true,
      leading: Icon(
        p.status == QuestStatus.completed
            ? Icons.check_circle
            : p.status == QuestStatus.inProgress
                ? Icons.radio_button_checked
                : Icons.lock,
        size: 18,
        color: p.status == QuestStatus.completed
            ? const Color(0xFF9BE36B)
            : const Color(0xFF7BD3F0),
      ),
      title: Text('${p.quest.title}（${p.quest.type.label}）',
          style: TextStyle(color: titleColor, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(p.quest.description,
              style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11)),
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              SizedBox(
                width: 90,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.ratio,
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9BE36B)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${p.status.label} ${p.progressText}',
                  style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 10)),
            ],
          ),
        ],
      ),
      trailing: p.status == QuestStatus.notStarted
          ? TextButton(
              onPressed: questSystem.canAccept(p.quest.id)
                  ? () {
                      questSystem.accept(p.quest.id);
                      setState(() {});
                      setSheetState(() {});
                      showToast('已接受任务：${p.quest.title}');
                    }
                  : null,
              child: const Text('接受', style: TextStyle(fontSize: 12)),
            )
          : canClaim
              ? TextButton(
                  onPressed: () => _claimQuest(p, setSheetState),
                  child: const Text('领奖', style: TextStyle(fontSize: 12)),
                )
              : null,
    );
  }

  void _claimQuest(QuestProgress p, StateSetter setSheetState) {
    final (int, int, String, int)? reward = questSystem.claim(p.quest.id);
    if (reward == null) return;
    player.addGold(reward.$1);
    final int lv = player.gainExp(reward.$2);
    if (reward.$3.isNotEmpty) addItem(reward.$3, math.max(1, reward.$4));
    if (reward.$3 == 'iron_sword' || reward.$3 == 'legendary_hoe') {
      weaponBonus += reward.$3 == 'legendary_hoe' ? 40 : 10;
    }
    if (lv > 0) {
      effects.levelUp(player.x, player.y - 30);
      audio.playSfx('levelup');
    }
    audio.playSfx('coin');
    setSheetState(() {});
    setState(() {});
    showToast(
      '任务完成：${p.quest.title}！+${reward.$1} 金币、+${reward.$2} 经验'
      '${reward.$3.isNotEmpty ? '、${kItemNames[reward.$3] ?? reward.$3}' : ''}'
      '${lv > 0 ? '（升到 Lv.${player.level}）' : ''}',
      duration: 4,
    );
  }

  // ------------------------------------------------------------------ 钓鱼

  void _goFishing() {
    bool atWater = false;
    for (final (double a, double b) in kWaterSpots) {
      if (player.x >= a && player.x <= b) {
        atWater = true;
        break;
      }
    }
    if (!atWater) {
      _walkTo(2500, kHorizonY + 20);
      showToast('已前往码头，到达后再点「工具」→「钓鱼」', duration: 3);
      return;
    }
    if (!player.useStamina(5)) {
      showToast('体力不足，无法钓鱼', duration: 2);
      return;
    }
    player.playAction(PlayerAction.harvesting, duration: 0.6);
    final double roll = rng.nextDouble();
    if (roll < 0.2) {
      showToast('鱼跑掉了……（体力 -5）', duration: 2);
      setState(() {});
      return;
    }
    final bool big = roll > 0.85;
    final String fishId = big ? 'fish_big' : 'fish_normal';
    final int gold = big ? 120 : 35;
    addItem(fishId);
    player.addGold(gold);
    final int lv = player.gainExp(big ? 20 : 8);
    questSystem.onFish(fishId);
    effects.fishSplash(player.x, GameWorldState.kHorizonY + 40);
    audio.playSfx('fish');
    if (lv > 0) {
      effects.levelUp(player.x, player.y - 30);
      audio.playSfx('levelup');
    }
    showToast('钓到了${big ? '一条大鱼！' : '一条鱼'}+$gold 金币${lv > 0 ? '，升到 Lv.${player.level}' : ''}',
        duration: 3);
    setState(() {});
  }

  // ------------------------------------------------------------------ 矿洞

  void _enterMine() {
    if (player.stamina < 10) {
      showToast('体力不足 10 点，无法进入矿洞', duration: 2);
      return;
    }
    inMine = true;
    final MineFloor f = mineManager.enter();
    camera.setWorldSize(f.pixelWidth, f.pixelHeight);
    player
      ..x = f.spawnCol * MineFloor.cellSize + MineFloor.cellSize / 2
      ..y = f.spawnRow * MineFloor.cellSize + MineFloor.cellSize / 2
      ..stopMoving();
    camera.snapTo(player.x, player.y);
    questSystem.onExplore('mine_floor_1');
    showToast('进入矿洞第 1 层：点击格子移动，撞上怪物会战斗，点击矿石可采集', duration: 5);
    setState(() {});
  }

  void _leaveMine() {
    inMine = false;
    mineManager.exit();
    camera.setWorldSize(kWorldWidth, kWorldHeight);
    player
      ..x = kMineEntranceX
      ..y = kHorizonY + 30
      ..stopMoving();
    camera.snapTo(player.x, player.y);
    showToast('回到了地面牧场', duration: 2);
    setState(() {});
  }

  void _handleMineTap(double wx, double wy) {
    final MineFloor? f = mineManager.current;
    if (f == null) return;
    final int col = (wx / MineFloor.cellSize).floor();
    final int row = (wy / MineFloor.cellSize).floor();
    if (!f.inBounds(col, row)) return;

    final Cell? cell = f.at(col, row);
    if (cell == null) return;

    // 相邻格直接交互，远处则先走过去
    final int pc = (player.x / MineFloor.cellSize).floor();
    final int pr = (player.y / MineFloor.cellSize).floor();
    final bool adjacent = (pc - col).abs() <= 1 && (pr - row).abs() <= 1;

    if (cell.type == CellType.wall && !adjacent) {
      showToast('那是墙壁，无法通行', duration: 2);
      return;
    }

    if (adjacent && (cell.type == CellType.ore || cell.monster != null || cell.type == CellType.stairs)) {
      _pendingCol = col;
      _pendingRow = row;
      _performMineAction(col, row);
      return;
    }

    if (cell.blocksMovement) {
      // 走向该格相邻的可通行位置
      final List<(int, int)> around = <(int, int)>[(col - 1, row), (col + 1, row), (col, row - 1), (col, row + 1)];
      (int, int)? spot;
      for (final (int c2, int r2) in around) {
        if (f.isWalkable(c2, r2)) {
          spot = (c2, r2);
          break;
        }
      }
      if (spot == null) {
        showToast('无法抵达那个位置', duration: 2);
        return;
      }
      player.moveTo(
        spot.$1 * MineFloor.cellSize + MineFloor.cellSize / 2,
        spot.$2 * MineFloor.cellSize + MineFloor.cellSize / 2,
        minX: 0,
        maxX: f.pixelWidth,
      );
      _pending = _PendingKind.mineMove;
      _pendingCol = col;
      _pendingRow = row;
      return;
    }

    player.moveTo(
      col * MineFloor.cellSize + MineFloor.cellSize / 2,
      row * MineFloor.cellSize + MineFloor.cellSize / 2,
      minX: 0,
      maxX: f.pixelWidth,
    );
  }

  void _performMineAction(int col, int row) {
    final MineFloor? f = mineManager.current;
    if (f == null) return;
    final Cell? cell = f.at(col, row);
    if (cell == null) return;

    // 1) 怪物战斗
    final Monster? m = cell.monster;
    if (m != null) {
      // 使用 MineFloor.attack：胜利后会把怪物从格子与楼层列表中移除，
      // 避免重复点击同一格反复获取金币与经验。
      final BattleResult? res = f.attack(
        col,
        row,
        playerAttack: playerAttack,
        playerHp: player.stamina,
        playerDefense: playerDefense,
      );
      if (res == null) {
        setState(() {});
        return;
      }
      if (res.playerWon) {
        player.stamina = math.max(1, player.stamina - res.damageTaken);
        player.addGold(res.goldGain);
        final int lv = player.gainExp(res.expGain);
        questSystem.onKill(m.type.id);
        if (res.dropped.isNotEmpty) addItem(res.dropped);
        effects.harvest(player.x, player.y);
        audio.playSfx('harvest');
        if (lv > 0) {
          effects.levelUp(player.x, player.y - 30);
          audio.playSfx('levelup');
        }
        showToast(
          '击败了${m.name}！+${res.goldGain} 金币、+${res.expGain} 经验'
          '${res.dropped.isNotEmpty ? '、获得${kItemNames[res.dropped] ?? res.dropped}' : ''}'
          '${lv > 0 ? '（升到 Lv.${player.level}）' : ''}',
          duration: 4,
        );
      } else {
        player.stamina = 0;
        showToast('被${m.name}击败了，体力耗尽，被迫返回地面', duration: 4);
        _leaveMine();
      }
      player.playAction(PlayerAction.hoeing, duration: 0.5);
      setState(() {});
      return;
    }

    // 2) 采矿石
    if (cell.type == CellType.ore) {
      if (!player.useStamina(2)) {
        showToast('体力不足，无法采矿', duration: 2);
        return;
      }
      // 采集成功后格子内的矿石类型会被清空，需先记录用于提示。
      final OreType? oreBefore = cell.ore;
      final int value = f.mine(col, row);
      player.playAction(PlayerAction.hoeing, duration: 0.4);
      effects.hoe(player.x, player.y);
      audio.playSfx('hoe');
      if (value > 0) {
        player.addGold(value);
        player.gainExp(6);
        effects.coin(player.x, player.y - 20);
        audio.playSfx('coin');
        showToast(
            '采集成功！+$value 金币${oreBefore != null ? '（${oreBefore.label}）' : ''}',
            duration: 2);
      } else {
        showToast('继续敲击矿石…', duration: 1.5);
      }
      setState(() {});
      return;
    }

    // 3) 楼梯
    if (cell.type == CellType.stairs) {
      if (f.isDeepest) {
        showToast('这里已经是最深处（第 ${MineFloor.totalFloors} 层）', duration: 2);
        return;
      }
      final MineFloor? next = mineManager.descend();
      if (next == null) return;
      player
        ..x = next.spawnCol * MineFloor.cellSize + MineFloor.cellSize / 2
        ..y = next.spawnRow * MineFloor.cellSize + MineFloor.cellSize / 2
        ..stopMoving();
      camera.setWorldSize(next.pixelWidth, next.pixelHeight);
      camera.snapTo(player.x, player.y);
      questSystem.onExplore('mine_floor_${mineManager.currentFloor}');
      showToast('下到第 ${mineManager.currentFloor} 层（怪物更强，矿石更珍贵）', duration: 3);
      setState(() {});
      return;
    }
  }

  // ------------------------------------------------------------------ 构建 UI

  @override
  Widget build(BuildContext context) {
    final Map<ToolType, String> badges = <ToolType, String>{
      if (fields.harvestableCount > 0) ToolType.hoe: '${fields.harvestableCount}',
      if (bagCount > 0) ToolType.bag: '$bagCount',
      if (questSystem.claimable.isNotEmpty) ToolType.tool: '${questSystem.claimable.length}',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            TopBar(
              gameName: '牧场物语',
              gold: player.gold,
              stamina: player.stamina,
              maxStamina: player.maxStamina,
              level: player.level,
              expProgress: player.expProgress,
              seasonLabel: seasonLabel,
              dayLabel: dayLabel,
              timeLabel: timeLabel,
              locationLabel: locationLabel,
              onTapName: _openQuestPanel,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  camera.setViewport(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (TapUpDetails d) =>
                              _handleTap(d.localPosition.dx, d.localPosition.dy),
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: inMine
                                ? _MinePainter(this)
                                : _FarmPainter(this),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _AudioToggle(
                              icon: audio.bgmEnabled ? Icons.music_note : Icons.music_off,
                              onTap: () async {
                                await audio.toggleBgm();
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 4),
                            _AudioToggle(
                              icon: audio.sfxEnabled ? Icons.volume_up : Icons.volume_off,
                              onTap: () {
                                audio.toggleSfx();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      if (toast.isNotEmpty)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xCC10240F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              toast,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            BottomBar(
              selected: selectedTool,
              onSelected: _onToolSelected,
              badges: badges,
              hint: inMine
                  ? '矿洞第 ${mineManager.currentFloor} 层 · 攻击 $playerAttack'
                  : '种子：${selectedCrop?.name ?? '未选择'}',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- 绘制

/// 农场场景绘制。
class _FarmPainter extends CustomPainter {
  _FarmPainter(this.state);

  final GameWorldState state;

  @override
  void paint(Canvas canvas, Size size) {
    final Camera cam = state.camera;

    canvas
      ..save()
      ..scale(cam.zoom, cam.zoom)
      ..translate(-cam.x, -cam.y);

    _drawSkyAndGround(canvas);
    _drawClouds(canvas);
    _drawVillage(canvas);
    _drawField(canvas);
    _drawNpcs(canvas);
    _drawPlayer(canvas);
    state.effects.draw(canvas);

    canvas.restore();

    // 屏幕空间：目标点标记
    if (state.player.isMoving && state.player.targetX != null) {
      final Paint p = Paint()
        ..color = const Color(0x889BE36B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final double sx = cam.toScreenX(state.player.targetX!);
      final double sy = cam.toScreenY(state.player.targetY ?? state.player.y);
      canvas.drawCircle(Offset(sx, sy), 8, p);
    }
  }

  void _drawSkyAndGround(Canvas canvas) {
    const Rect sky = Rect.fromLTWH(0, 0, GameWorldState.kWorldWidth, GameWorldState.kHorizonY);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF87CEEB), Color(0xFFD9F0FF)],
        ).createShader(sky),
    );

    // 远山
    final Paint hill = Paint()..color = const Color(0xFF9BC58A);
    for (int i = 0; i < 12; i++) {
      final double cx = i * 640.0 + 200;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, GameWorldState.kHorizonY + 10), width: 700, height: 260),
        hill,
      );
    }

    // 地面
    const Rect ground = Rect.fromLTWH(
        0, GameWorldState.kHorizonY, GameWorldState.kWorldWidth,
        GameWorldState.kWorldHeight - GameWorldState.kHorizonY);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF7CB342), Color(0xFF558B2F)],
        ).createShader(ground),
    );

    // 水域
    final Paint water = Paint()..color = const Color(0xFF62B6E8);
    for (final (double a, double b) in GameWorldState.kWaterSpots) {
      final double wcx = (a + b) / 2;
      final double wcy = GameWorldState.kHorizonY + 40;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(wcx, wcy), width: b - a, height: 90),
        water,
      );
      // 水面涟漪动画
      for (int i = 0; i < 3; i++) {
        final double phase = (state.animTime * 0.6 + i * 0.33) % 1.0;
        final double rw = phase * (b - a) * 0.35;
        final int alpha = ((1 - phase) * 90).round();
        canvas.drawOval(
          Rect.fromCenter(center: Offset(wcx, wcy), width: rw * 2, height: rw),
          Paint()
            ..color = Color((alpha << 24) | 0x00FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      // 水面闪光
      final double sparkle = (math.sin(state.animTime * 3) + 1) * 0.5;
      canvas.drawCircle(
        Offset(wcx - (b - a) * 0.2, wcy - 10),
        2 + sparkle * 2,
        Paint()..color = Color(((0x88 + (sparkle * 64).round()) << 24) | 0x00FFFFFF),
      );
    }
  }

  /// 绘制漂移云朵。
  void _drawClouds(Canvas canvas) {
    final Paint cloud = Paint()..color = const Color(0xCCFFFFFF);
    const double span = GameWorldState.kWorldWidth + 400;
    for (int i = 0; i < 7; i++) {
      final double drift = (state.animTime * (12 + i * 3) + i * 900) % span - 200;
      final double cy = 40 + (i % 3) * 55;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(drift, cy, 100, 32),
          const Radius.circular(16),
        ),
        cloud,
      );
      canvas.drawCircle(Offset(drift + 30, cy + 4), 22, cloud);
      canvas.drawCircle(Offset(drift + 65, cy + 8), 18, cloud);
    }
  }

  void _drawVillage(Canvas canvas) {
    // 矿洞入口
    const double mx = GameWorldState.kMineEntranceX;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(mx - 60, GameWorldState.kHorizonY - 110, 120, 120),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFF6D5A48),
      )
      ..drawOval(
        const Rect.fromLTWH(mx - 28, GameWorldState.kHorizonY - 78, 56, 78),
        Paint()..color = const Color(0xFF1A1A1A),
      );
    _text(canvas, '矿洞', const Offset(mx - 18, GameWorldState.kHorizonY - 130),
        color: Colors.white, size: 12);

    // 每个 NPC 的房子
    for (final Npc n in NpcData.all) {
      final double hx = n.x;
      final Rect body = Rect.fromLTWH(hx - 40, GameWorldState.kHorizonY - 90, 80, 90);
      canvas
        ..drawRect(body, Paint()..color = colorWithAlpha(n.color, 0.85))
        ..drawPath(
          Path()
            ..moveTo(hx - 50, GameWorldState.kHorizonY - 90)
            ..lineTo(hx, GameWorldState.kHorizonY - 130)
            ..lineTo(hx + 50, GameWorldState.kHorizonY - 90)
            ..close(),
          Paint()..color = const Color(0xFF8D4A3A),
        )
        ..drawRect(
          Rect.fromLTWH(hx - 12, GameWorldState.kHorizonY - 50, 24, 50),
          Paint()..color = const Color(0xFF4A332A),
        );
      _text(canvas, '${n.name}·${n.job}', Offset(hx - 34, GameWorldState.kHorizonY - 148),
          color: const Color(0xFFFFFFFF), size: 10);
    }
  }

  void _drawField(Canvas canvas) {
    final FieldManager fm = state.fields;
    final double ts = fm.tileSize;
    const double originX = GameWorldState.kFieldOriginX;
    const double originY = GameWorldState.kFieldOriginY;
    final double camX = state.camera.x;
    final double camW = state.camera.viewportWidth / state.camera.zoom;

    // 田地底板
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(originX - 8, originY - 8, fm.pixelWidth + 16, fm.pixelHeight + 16),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF6B4B2A),
    );

    for (final FieldTile t in fm.tiles) {
      final double x = originX + t.col * ts;
      // 视口裁剪
      if (x + ts < camX || x > camX + camW) continue;
      final double y = originY + t.row * ts;
      final Rect r = Rect.fromLTWH(x + 1, y + 1, ts - 2, ts - 2);

      switch (t.state) {
        case TileState.empty:
          canvas.drawRect(r, Paint()..color = const Color(0xFF8B6F47));
          break;
        case TileState.hoe:
          canvas.drawRect(r, Paint()..color = const Color(0xFF5D4023));
          _furrows(canvas, r);
          break;
        case TileState.planted:
        case TileState.grown:
        case TileState.withered:
          canvas.drawRect(r, Paint()..color = const Color(0xFF5D4023));
          _furrows(canvas, r);
          _drawCrop(canvas, t, r);
          break;
      }
    }
  }

  void _furrows(Canvas canvas, Rect r) {
    final Paint p = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final double y = r.top + r.height * i / 4;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), p);
    }
  }

  void _drawCrop(Canvas canvas, FieldTile t, Rect r) {
    final Crop? c = t.crop;
    if (c == null) return;
    final double cx = r.center.dx;
    final double bottom = r.bottom - 4;

    if (t.state == TileState.withered) {
      final Paint w = Paint()
        ..color = const Color(0xFF8A7A5A)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas
        ..drawLine(Offset(cx - 5, bottom), Offset(cx - 2, bottom - 10), w)
        ..drawLine(Offset(cx + 5, bottom), Offset(cx + 2, bottom - 10), w);
      return;
    }

    final int stage = t.stage;
    final double growth = c.stages <= 1 ? 1 : stage / (c.stages - 1);
    final double h = 4 + growth * (r.height - 10);

    // 摇摆偏移（风效，随位置相位错开）
    final double sway = math.sin(state.animTime * 2.2 + t.col * 0.6 + t.row * 0.4) * 1.8 * growth;
    final double topX = cx + sway;
    final double topY = bottom - h;

    // 茎
    final Paint stem = Paint()
      ..color = const Color(0xFF4E8A3A)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, bottom), Offset(topX, topY), stem);

    // 叶
    if (growth > 0.25) {
      final Paint leaf = Paint()..color = const Color(0xFF6FBF4A);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(topX - 5, bottom - h * 0.55), width: 9, height: 5), leaf);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(topX + 5, bottom - h * 0.45), width: 9, height: 5), leaf);
    }

    // 果实（按阶段逐步显色，成熟时最大最亮）
    if (growth > 0.5) {
      final double radius = 2.5 + growth * 4.5;
      canvas.drawCircle(
        Offset(topX, topY),
        radius,
        Paint()..color = colorWithAlpha(c.color, t.state == TileState.grown ? 1 : 0.55),
      );
    }

    // 成熟高亮（脉冲呼吸）
    if (t.state == TileState.grown) {
      final double pulse = (math.sin(state.animTime * 3.5) + 1) * 0.5;
      canvas.drawCircle(
        Offset(topX, topY),
        9 + pulse * 2,
        Paint()
          ..color = Color(((0x44 + (pulse * 0x33).round()) << 24) | 0x00FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final double bounce = math.sin(state.animTime * 4) * 2;
      _text(canvas, '!', Offset(topX - 2, topY - 20 + bounce),
          color: const Color(0xFFFFE066), size: 11, bold: true);
    } else if (t.state == TileState.planted) {
      // 生长进度条
      final double w = r.width - 8;
      final Rect bg = Rect.fromLTWH(r.left + 4, r.top + 2, w, 3);
      canvas.drawRect(bg, Paint()..color = const Color(0x44000000));
      canvas.drawRect(
        Rect.fromLTWH(r.left + 4, r.top + 2, w * t.progress, 3),
        Paint()..color = t.watered ? const Color(0xFF7BD3F0) : const Color(0xFF9BE36B),
      );
    }
  }

  void _drawNpcs(Canvas canvas) {
    for (final Npc n in NpcData.all) {
      final double nx = n.xAtHour(state.hourOfDay);
      final double bob = math.sin(state.animTime * 2.5 + n.x * 0.01) * 1.5;
      final double ny = GameWorldState.kHorizonY + 26 + bob;
      final Color col = Color(n.color);

      // 身体
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(nx - 8, ny - 26, 16, 22), const Radius.circular(5)),
        Paint()..color = col,
      );
      // 头
      canvas.drawCircle(Offset(nx, ny - 33), 7, Paint()..color = const Color(0xFFFFE0BD));
      // 腿
      final Paint leg = Paint()
        ..color = const Color(0xFF3E4A5A)
        ..strokeWidth = 3;
      canvas
        ..drawLine(Offset(nx - 3, ny - 4), Offset(nx - 3, ny + 4), leg)
        ..drawLine(Offset(nx + 3, ny - 4), Offset(nx + 3, ny + 4), leg);
      // 可攻略标记
      if (n.marriageable) {
        _text(canvas, '♥', Offset(nx - 4, ny - 52),
            color: const Color(0xFFFF7BA0), size: 10);
      }
      _text(canvas, n.name, Offset(nx - n.name.length * 5.0, ny + 8),
          color: Colors.white, size: 9);
    }
  }

  void _drawPlayer(Canvas canvas) =>
      drawPlayerFigure(canvas, state.player);

  void _text(Canvas canvas, String s, Offset offset,
      {Color color = Colors.white, double size = 10, bool bold = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          shadows: const <Shadow>[Shadow(color: Color(0x88000000), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FarmPainter oldDelegate) => true;
}

/// 按透明度构造颜色（纯整数运算）。
///
/// 同时兼容文档要求的 Flutter 3.2+ 与当前新版 SDK：
/// 不使用已弃用的 `withOpacity`，也不使用 3.27+ 才提供的 `withValues`。
Color colorWithAlpha(int argb, double alpha) {
  final int a = (alpha.clamp(0.0, 1.0) * 255).round();
  return Color((a << 24) | (argb & 0x00FFFFFF));
}

/// 玩家角色绘制（农场与矿洞共用）。
void drawPlayerFigure(Canvas canvas, Player p) {
  final double x = p.x;
  final double y = p.y;
  final bool flip = p.facing == Facing.left;
  final double swing = p.action == PlayerAction.walking
      ? math.sin(p.walkCycle * 10) * 4
      : 0;

  // 影子
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x, y + 2), width: 24, height: 7),
    Paint()..color = const Color(0x33000000),
  );

  // 腿
  final Paint leg = Paint()
    ..color = const Color(0xFF3E5C76)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(Offset(x - 4, y - 14), Offset(x - 4 - swing, y), leg)
    ..drawLine(Offset(x + 4, y - 14), Offset(x + 4 + swing, y), leg);

  // 身体（背带裤）
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 9, y - 32, 18, 20), const Radius.circular(5)),
    Paint()..color = const Color(0xFF4A90D9),
  );
  // 上衣
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 9, y - 34, 18, 9), const Radius.circular(4)),
    Paint()..color = const Color(0xFFF2F2F2),
  );

  // 手臂与工具
  final Paint arm = Paint()
    ..color = const Color(0xFFFFE0BD)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;
  double armAngle = 0;
  switch (p.action) {
    case PlayerAction.hoeing:
      armAngle = -0.9;
      break;
    case PlayerAction.planting:
      armAngle = 0.7;
      break;
    case PlayerAction.harvesting:
      armAngle = 0.3;
      break;
    case PlayerAction.walking:
      armAngle = math.sin(p.walkCycle * 10) * 0.3;
      break;
    case PlayerAction.idle:
      armAngle = 0;
      break;
  }
  final double dir = flip ? -1 : 1;
  final Offset shoulder = Offset(x + dir * 7, y - 30);
  final Offset hand = Offset(
    shoulder.dx + dir * 12 * math.cos(armAngle),
    shoulder.dy + 12 * math.sin(armAngle) + 6,
  );
  canvas.drawLine(shoulder, hand, arm);

  // 工具（锄头）
  if (p.action == PlayerAction.hoeing || p.action == PlayerAction.idle) {
    final Paint tool = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..strokeWidth = 2.5;
    canvas
      ..drawLine(hand, Offset(hand.dx + dir * 6, hand.dy - 16), tool)
      ..drawLine(
        Offset(hand.dx + dir * 2, hand.dy - 16),
        Offset(hand.dx + dir * 12, hand.dy - 14),
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..strokeWidth = 3,
      );
  }

  // 头
  canvas.drawCircle(Offset(x, y - 41), 8, Paint()..color = const Color(0xFFFFE0BD));
  // 草帽
  canvas
    ..drawOval(
      Rect.fromCenter(center: Offset(x, y - 46), width: 26, height: 7),
      Paint()..color = const Color(0xFFE3C567),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 6, y - 54, 12, 8), const Radius.circular(3)),
      Paint()..color = const Color(0xFFD4B455),
    );
  // 眼睛
  canvas.drawCircle(Offset(x + dir * 3, y - 41), 1.3, Paint()..color = Colors.black);

  // 体力过低提示
  if (p.isExhausted) {
    final TextPainter tp = TextPainter(
      text: const TextSpan(
          text: '💤', style: TextStyle(fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x + 8, y - 62));
  }
}

/// 矿洞场景绘制。
class _MinePainter extends CustomPainter {
  _MinePainter(this.state);

  final GameWorldState state;

  @override
  void paint(Canvas canvas, Size size) {
    final Camera cam = state.camera;
    final MineFloor? f = state.mineManager.current;
    if (f == null) return;

    canvas
      ..save()
      ..scale(cam.zoom, cam.zoom)
      ..translate(-cam.x, -cam.y);

    // 背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, f.pixelWidth, f.pixelHeight),
      Paint()..color = const Color(0xFF1C1A22),
    );

    const double cs = MineFloor.cellSize;
    for (int r = 0; r < f.height; r++) {
      for (int c = 0; c < f.width; c++) {
        final Cell? cell = f.at(c, r);
        if (cell == null) continue;
        final Rect rect = Rect.fromLTWH(c * cs + 0.5, r * cs + 0.5, cs - 1, cs - 1);

        switch (cell.type) {
          case CellType.floor:
            canvas.drawRect(rect, Paint()..color = const Color(0xFF3A3444));
            break;
          case CellType.wall:
            canvas.drawRect(rect, Paint()..color = const Color(0xFF5A5060));
            canvas.drawRect(
              Rect.fromLTWH(rect.left + 3, rect.top + 3, rect.width - 6, rect.height - 6),
              Paint()..color = const Color(0xFF4A4152),
            );
            break;
          case CellType.ore:
            canvas.drawRect(rect, Paint()..color = const Color(0xFF3A3444));
            final Color oc = Color((cell.ore ?? OreType.stone).color);
            canvas
              ..drawCircle(rect.center, 9, Paint()..color = const Color(0xFF6A6070))
              ..drawCircle(rect.center, 5.5, Paint()..color = oc);
            // 剩余敲击次数
            _text(canvas, '${cell.oreHp}', Offset(rect.right - 8, rect.top + 1),
                color: const Color(0xCCFFFFFF), size: 8);
            break;
          case CellType.stairs:
            canvas.drawRect(rect, Paint()..color = const Color(0xFF2A2434));
            final Paint sp = Paint()
              ..color = const Color(0xFFE3C567)
              ..strokeWidth = 2;
            for (int i = 0; i < 3; i++) {
              final double yy = rect.top + 6 + i * 8;
              canvas.drawLine(Offset(rect.left + 6, yy), Offset(rect.right - 6, yy), sp);
            }
            break;
        }

        // 怪物
        final Monster? m = cell.monster;
        if (m != null && m.isAlive) {
          final Color mc = Color(m.type.color);
          canvas
            ..drawCircle(rect.center, m.type.size / 2, Paint()..color = mc)
            ..drawCircle(Offset(rect.center.dx - 4, rect.center.dy - 3), 2,
                Paint()..color = Colors.white)
            ..drawCircle(Offset(rect.center.dx + 4, rect.center.dy - 3), 2,
                Paint()..color = Colors.white)
            ..drawCircle(Offset(rect.center.dx - 4, rect.center.dy - 3), 1,
                Paint()..color = Colors.black)
            ..drawCircle(Offset(rect.center.dx + 4, rect.center.dy - 3), 1,
                Paint()..color = Colors.black);
          // HP 条
          const double w = cs - 8;
          canvas.drawRect(Rect.fromLTWH(rect.left + 4, rect.top + 2, w, 3),
              Paint()..color = const Color(0x66000000));
          canvas.drawRect(
            Rect.fromLTWH(rect.left + 4, rect.top + 2, w * m.hpRatio, 3),
            Paint()..color = const Color(0xFFFF6B6B),
          );
        }
      }
    }

    // 玩家
    drawPlayerFigure(canvas, state.player);

    canvas.restore();

    // 屏幕空间信息
    _text(
      canvas,
      '第 ${state.mineManager.currentFloor}/${MineFloor.totalFloors} 层　'
      '怪物 ${f.aliveMonsters}　矿石 ${f.remainingOres}　'
      '${f.isDeepest ? '已是最深层' : '找楼梯继续下行'}',
      const Offset(10, 8),
      color: Colors.white,
      size: 12,
    );
  }

  void _text(Canvas canvas, String s, Offset offset,
      {Color color = Colors.white, double size = 10}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          shadows: const <Shadow>[Shadow(color: Color(0xCC000000), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MinePainter oldDelegate) => true;
}

/// 音频开关小按钮。
class _AudioToggle extends StatelessWidget {
  const _AudioToggle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0x66000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
