// 牧场游戏单元测试
//
// 覆盖数据层（75 种作物）、模型层（玩家/田地/怪物/矿洞/NPC）、
// 系统层（NPC 好感度/祭典/任务）与 UI 层（顶栏/底栏）。
//
// 说明：不直接 pumpWidget(GameWorld)，因为 GameWorld 在 initState 中
// 启动了 Ticker 主循环，在 widget test 环境下会产生挂起的 ticker；
// 核心玩法逻辑通过模型层与系统层的纯逻辑测试覆盖。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farm_game/data/crops_data.dart';
import 'package:farm_game/game/camera.dart';
import 'package:farm_game/models/field.dart';
import 'package:farm_game/models/mine_floor.dart';
import 'package:farm_game/models/monster.dart';
import 'package:farm_game/models/npc.dart';
import 'package:farm_game/models/player.dart';
import 'package:farm_game/systems/festival_system.dart';
import 'package:farm_game/systems/npc_system.dart';
import 'package:farm_game/systems/quest_system.dart';
import 'package:farm_game/ui/bottom_bar.dart';
import 'package:farm_game/ui/top_bar.dart';

void main() {
  // ------------------------------------------------------------------ 数据层
  group('作物数据（75 种）', () {
    test('总数为 75，且 ID 唯一', () {
      expect(CropsData.count, 75);
      final Set<String> ids =
          CropsData.all.map((Crop c) => c.id).toSet();
      expect(ids.length, 75);
    });

    test('每个季节各 15 种', () {
      for (final Season s in Season.values) {
        expect(CropsData.bySeason(s).length, 15, reason: '${s.label} 应为 15 种');
      }
    });

    test('每种作物字段完整且合法', () {
      for (final Crop c in CropsData.all) {
        expect(c.name.isNotEmpty, isTrue);
        expect(c.growHours > 0, isTrue, reason: '${c.id} 生长时长必须为正');
        expect(c.stages >= 2, isTrue, reason: '${c.id} 阶段数至少为 2');
        expect(c.price > 0, isTrue);
        expect(c.seedCost > 0, isTrue);
        expect(c.color != 0, isTrue);
        if (c.regrow) {
          expect(c.regrowHours > 0, isTrue, reason: '${c.id} 再生作物需有再生时长');
          expect(c.regrowHours < c.growHours, isTrue,
              reason: '${c.id} 再生时长应短于总生长时长');
        }
      }
    });

    test('ID 与名称查找可用', () {
      expect(CropsData.byId('spring_wheat')?.name, '小麦');
      expect(CropsData.byId('not_exist'), isNull);
      expect(CropsData.byName('榴莲')?.id, 'gh_durian');
    });

    test('生长阶段随时间推进直至成熟', () {
      final Crop wheat = CropsData.byId('spring_wheat')!;
      expect(wheat.stageAt(0), 0);
      expect(wheat.stageAt(wheat.growHours / 2),
          greaterThan(0));
      expect(wheat.isGrown(wheat.growHours.toDouble()), isTrue);
      expect(wheat.stageAt(wheat.growHours.toDouble()), wheat.stages - 1);
      // 超出成熟时间不会越界
      expect(wheat.stageAt(wheat.growHours * 10.0), wheat.stages - 1);
    });

    test('收益排序与极值查询可用', () {
      final List<Crop> ranked = CropsData.byProfitPerHour(Season.spring);
      expect(ranked.length, 15);
      for (int i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].profitPerHour >= ranked[i].profitPerHour, isTrue);
      }
      expect(CropsData.mostValuable.id, 'gh_durian');
      expect(CropsData.fastest.id, 'spring_arugula');
    });
  });

  // ------------------------------------------------------------------ 玩家
  group('玩家模型', () {
    test('初始数值符合预期', () {
      final Player p = Player();
      expect(p.gold, 500);
      expect(p.stamina, 100);
      expect(p.level, 1);
      expect(p.isMoving, isFalse);
    });

    test('移动插值逐步逼近目标并最终停止', () {
      final Player p = Player(x: 0, y: 600);
      p.moveTo(300, 600);
      expect(p.isMoving, isTrue);
      expect(p.facing, Facing.right);

      // 速度 180 px/s，走 1 秒后应前进约 180 且仍未到达
      p.update(1.0);
      expect(p.x, closeTo(180, 1));
      expect(p.isMoving, isTrue);

      // 再走 2 秒必然到达并被吸附到目标点
      p.update(2.0);
      expect(p.x, 300);
      expect(p.isMoving, isFalse);
      expect(p.action, PlayerAction.idle);
    });

    test('向左移动时朝向翻转', () {
      final Player p = Player(x: 500, y: 600);
      p.moveTo(200, 600);
      expect(p.facing, Facing.left);
    });

    test('目标点会被限制在可行走范围内', () {
      final Player p = Player(x: 100, y: 600);
      p.moveTo(99999, 600, minX: 0, maxX: 1000);
      expect(p.targetX, 1000);
    });

    test('金币增减：余额不足时不扣款', () {
      final Player p = Player(gold: 100);
      expect(p.addGold(50), isTrue);
      expect(p.gold, 150);
      expect(p.canAfford(200), isFalse);
      expect(p.spendGold(200), isFalse);
      expect(p.gold, 150, reason: '扣款失败不应改变余额');
      expect(p.spendGold(50), isTrue);
      expect(p.gold, 100);
    });

    test('体力消耗与恢复受上限约束', () {
      final Player p = Player(stamina: 10, maxStamina: 100);
      expect(p.useStamina(20), isFalse);
      expect(p.stamina, 10);
      expect(p.useStamina(5), isTrue);
      expect(p.stamina, 5);
      expect(p.restoreStamina(200), 95);
      expect(p.stamina, 100);
    });

    test('经验升级会提升体力上限', () {
      final Player p = Player();
      final int beforeMax = p.maxStamina;
      final int levels = p.gainExp(p.expToNext + 10);
      expect(levels, greaterThanOrEqualTo(1));
      expect(p.level, greaterThan(1));
      expect(p.maxStamina, greaterThan(beforeMax));
      expect(p.stamina, p.maxStamina, reason: '升级应回满体力');
    });
  });

  // ------------------------------------------------------------------ 田地
  group('田地系统（20×15，5 种状态）', () {
    test('网格规格与状态枚举正确', () {
      final FieldManager fm = FieldManager();
      expect(fm.cols, 20);
      expect(fm.rows, 15);
      expect(fm.tiles.length, 300);
      expect(TileState.values.length, 5);
      expect(fm.tileAt(-1, 0), isNull);
      expect(fm.tileAt(20, 0), isNull);
    });

    test('世界坐标能反算出正确田块', () {
      final FieldManager fm = FieldManager();
      final FieldTile? t = fm.tileAtWorld(320 + 41, 540 + 81,
          originX: 320, originY: 540);
      expect(t, isNotNull);
      expect(t!.col, 1);
      expect(t.row, 2);
    });

    test('完整状态流转：空地 → 锄地 → 播种 → 成熟 → 收获', () {
      final FieldManager fm = FieldManager();
      final Crop wheat = CropsData.byId('spring_wheat')!;

      expect(fm.tileAt(0, 0)!.state, TileState.empty);

      final FieldResult hoeRes = fm.hoe(0, 0);
      expect(hoeRes.success, isTrue);
      expect(hoeRes.staminaCost, FieldManager.hoeStaminaCost);
      expect(fm.tileAt(0, 0)!.state, TileState.hoe);

      // 重复锄地应失败
      expect(fm.hoe(0, 0).success, isFalse);

      final FieldResult plantRes = fm.plant(0, 0, wheat, 1000);
      expect(plantRes.success, isTrue);
      expect(plantRes.goldCost, wheat.seedCost);
      expect(fm.tileAt(0, 0)!.state, TileState.planted);
      expect(fm.tileAt(0, 0)!.crop, wheat);

      // 未成熟时不能收获
      expect(fm.harvest(0, 0).success, isFalse);

      fm.updateHours(wheat.growHours.toDouble() + 1);
      expect(fm.tileAt(0, 0)!.state, TileState.grown);
      expect(fm.harvestableCount, 1);

      final FieldResult harvestRes = fm.harvest(0, 0);
      expect(harvestRes.success, isTrue);
      expect(harvestRes.gain, wheat.price);
      expect(fm.tileAt(0, 0)!.state, TileState.hoe,
          reason: '一次性作物收获后应保留开垦状态');
      expect(fm.tileAt(0, 0)!.crop, isNull);
      expect(fm.harvestedCountOf(wheat.id), 1);
    });

    test('再生作物收获后回到生长中并保留再生进度', () {
      final FieldManager fm = FieldManager();
      final Crop berry = CropsData.byId('spring_strawberry')!;
      expect(berry.regrow, isTrue);

      fm.hoe(0, 0);
      fm.plant(0, 0, berry, 1000);
      fm.updateHours(berry.growHours.toDouble() + 1);
      expect(fm.tileAt(0, 0)!.state, TileState.grown);

      fm.harvest(0, 0);
      final FieldTile t = fm.tileAt(0, 0)!;
      expect(t.state, TileState.planted);
      expect(t.crop, berry, reason: '再生作物应保留作物配置');
      expect(t.elapsedHours, closeTo(berry.growHours - berry.regrowHours, 0.001));
    });

    test('未播种不能直接收获，未锄地不能播种', () {
      final FieldManager fm = FieldManager();
      final Crop wheat = CropsData.byId('spring_wheat')!;
      expect(fm.harvest(3, 3).success, isFalse);
      final FieldResult r = fm.plant(3, 3, wheat, 1000);
      expect(r.success, isFalse);
      expect(r.message, contains('需要先锄地'));
    });

    test('体力与金币检查回调会拦截操作且不改变田块', () {
      final FieldManager fm = FieldManager();
      final Crop wheat = CropsData.byId('spring_wheat')!;

      // 体力不足
      final FieldResult noStamina =
          fm.hoe(0, 0, hasStamina: (int cost) => false);
      expect(noStamina.success, isFalse);
      expect(fm.tileAt(0, 0)!.state, TileState.empty);

      fm.hoe(0, 0);
      // 金币不足
      final FieldResult noGold = fm.plant(0, 0, wheat, 1000,
          hasGold: (int cost) => false);
      expect(noGold.success, isFalse);
      expect(fm.tileAt(0, 0)!.state, TileState.hoe,
          reason: '播种失败不应改变田块状态');
    });

    test('浇水加速生长，且不能重复浇水', () {
      final FieldManager fm = FieldManager();
      final Crop wheat = CropsData.byId('spring_wheat')!;
      fm.hoe(0, 0);
      fm.plant(0, 0, wheat, 1000);

      expect(fm.water(0, 0).success, isTrue);
      expect(fm.tileAt(0, 0)!.watered, isTrue);
      expect(fm.water(0, 0).success, isFalse);

      final FieldManager dry = FieldManager();
      dry.hoe(0, 0);
      dry.plant(0, 0, wheat, 1000);

      fm.updateHours(10);
      dry.updateHours(10);
      expect(fm.tileAt(0, 0)!.elapsedHours,
          greaterThan(dry.tileAt(0, 0)!.elapsedHours),
          reason: '浇水后生长进度应更快');
    });

    test('成熟后超过 48 小时未收获会枯萎，可清理复耕', () {
      final FieldManager fm = FieldManager();
      final Crop wheat = CropsData.byId('spring_wheat')!;
      fm.hoe(0, 0);
      fm.plant(0, 0, wheat, 1000);
      fm.updateHours(wheat.growHours.toDouble() + 1);
      expect(fm.tileAt(0, 0)!.state, TileState.grown);

      fm.updateHours(FieldTile.witherAfterHours + 1);
      expect(fm.tileAt(0, 0)!.state, TileState.withered);
      expect(fm.witheredCount, 1);
      expect(fm.harvest(0, 0).success, isFalse);

      expect(fm.clearWithered(0, 0).success, isTrue);
      expect(fm.tileAt(0, 0)!.state, TileState.hoe);
    });

    test('季节更替使不符季作物枯萎，温室作物豁免', () {
      final FieldManager fm = FieldManager();
      final Crop springWheat = CropsData.byId('spring_wheat')!;
      final Crop ghDurian = CropsData.byId('gh_durian')!;

      fm.hoe(0, 0);
      fm.plant(0, 0, springWheat, 1000);
      fm.hoe(1, 0);
      fm.plant(1, 0, ghDurian, 1000);

      final int withered = fm.applySeasonChange(Season.winter);
      expect(withered, 1);
      expect(fm.tileAt(0, 0)!.state, TileState.withered);
      expect(fm.tileAt(1, 0)!.state, TileState.planted,
          reason: '温室作物不受季节影响');
    });
  });

  // ------------------------------------------------------------------ NPC
  group('NPC 数据（17 位）', () {
    test('共 17 位，其中 5 位可攻略', () {
      expect(NpcData.count, 17);
      expect(NpcData.marriageable.length, 5);
      final Set<String> ids = NpcData.all.map((Npc n) => n.id).toSet();
      expect(ids.length, 17);
    });

    test('喜好与厌恶引用的作物 ID 全部真实存在', () {
      for (final Npc n in NpcData.all) {
        for (final String id in n.likes) {
          expect(CropsData.byId(id), isNotNull, reason: '${n.id} 喜好 $id 不存在');
        }
        for (final String id in n.dislikes) {
          expect(CropsData.byId(id), isNotNull, reason: '${n.id} 厌恶 $id 不存在');
        }
      }
    });

    test('行程能按小时返回坐标与地点', () {
      final Npc maya = NpcData.byId('maya')!;
      expect(maya.xAtHour(6), 2500, reason: '清晨应在码头');
      expect(maya.locationAtHour(6), '码头');
      expect(maya.xAtHour(20), 2060, reason: '夜间应回到渔屋');
    });
  });

  group('NPC 好感度系统', () {
    test('增减好感度受 0~1000 边界约束', () {
      final NpcSystem s = NpcSystem();
      expect(s.increase('john', 50), 50);
      expect(s.affinityOf('john'), 50);
      expect(s.decrease('john', 200), 50, reason: '不会降到负数');
      expect(s.affinityOf('john'), 0);

      s.increase('john', 5000);
      expect(s.affinityOf('john'), NpcSystem.maxAffinity);
      expect(s.increase('john', 10), 0, reason: '已满级不再增加');
    });

    test('好感度等级随数值提升', () {
      expect(AffinityLevel.of(0), AffinityLevel.stranger);
      expect(AffinityLevel.of(100), AffinityLevel.acquaintance);
      expect(AffinityLevel.of(800), AffinityLevel.inLove);
      final NpcSystem s = NpcSystem();
      s.setAffinity('mary', 300);
      expect(s.relationOf('mary')!.level, AffinityLevel.friend);
    });

    test('每日首次对话加好感，重复对话不再加', () {
      final NpcSystem s = NpcSystem();
      final NpcActionResult first = s.talk('john');
      expect(first.success, isTrue);
      expect(first.delta, NpcSystem.talkGain);
      final NpcActionResult second = s.talk('john');
      expect(second.success, isTrue);
      expect(second.delta, 0);

      s.onNewDay();
      expect(s.talk('john').delta, NpcSystem.talkGain, reason: '跨天后应重新计数');
    });

    test('送礼按喜好/厌恶给出不同好感变化', () {
      final NpcSystem s = NpcSystem();
      final Npc eileen = NpcData.byId('eileen')!;

      // 每日送礼次数有上限，跨天后计数才会重置。
      final NpcActionResult loved =
          s.giveGift('eileen', CropsData.byId(eileen.likes.first)!);
      expect(loved.delta, NpcSystem.lovedGiftGain);

      s.onNewDay();
      final NpcActionResult disliked =
          s.giveGift('eileen', CropsData.byId(eileen.dislikes.first)!);
      expect(disliked.delta, -NpcSystem.dislikedGiftLoss);

      s.onNewDay();
      final NpcActionResult neutral =
          s.giveGift('eileen', CropsData.byId('spring_wheat')!);
      expect(neutral.delta, NpcSystem.normalGiftGain);
    });

    test('每日送礼次数受限', () {
      final NpcSystem s = NpcSystem();
      final Crop wheat = CropsData.byId('spring_wheat')!;
      for (int i = 0; i < NpcSystem.maxGiftsPerDay; i++) {
        expect(s.giveGift('john', wheat).success, isTrue);
      }
      expect(s.giveGift('john', wheat).success, isFalse);
    });

    test('求婚需 800 好感且对方可攻略', () {
      final NpcSystem s = NpcSystem();
      expect(NpcSystem.marriageThreshold, 800);

      // 可攻略但好感不足
      expect(s.canPropose('eileen'), isFalse);
      expect(s.proposeBlocker('eileen'), contains('好感度不足'));

      // 好感达标
      s.setAffinity('eileen', 800);
      expect(s.canPropose('eileen'), isTrue);
      expect(s.proposeBlocker('eileen'), isNull);
      expect(s.proposable.length, 1);

      final NpcActionResult r = s.propose('eileen');
      expect(r.success, isTrue);
      expect(s.spouse?.npc.id, 'eileen');
      expect(s.canPropose('eileen'), isFalse, reason: '已婚后不可重复求婚');
      expect(s.propose('eileen').message, contains('已经'));
    });

    test('不可攻略的村民无法求婚', () {
      final NpcSystem s = NpcSystem();
      s.setAffinity('john', 1000);
      expect(s.canPropose('john'), isFalse);
      expect(s.proposeBlocker('john'), contains('并不是可攻略'));
      expect(s.propose('john').success, isFalse);
    });

    test('全员好感加成与统计可用', () {
      final NpcSystem s = NpcSystem();
      s.increaseAll(10);
      expect(s.affinityOf('john'), 10);
      expect(s.averageAffinity, 10);
      expect(s.countAtLeast(10), NpcData.count);
      expect(s.rankedByAffinity.length, NpcData.count);
    });

    test('存档与读档可往返', () {
      final NpcSystem s = NpcSystem();
      s.setAffinity('maya', 620);
      s.talk('maya');
      final Map<String, dynamic> saved = s.save();

      final NpcSystem restored = NpcSystem();
      restored.load(saved);
      expect(restored.affinityOf('maya'), s.affinityOf('maya'));
      expect(restored.relationOf('maya')!.talkDays, 1);
    });
  });

  // ------------------------------------------------------------------ 怪物与矿洞
  group('怪物模型（7 种）', () {
    test('共 7 种，分别对应 1~7 层', () {
      expect(MonsterData.count, 7);
      expect(MonsterData.all.map((MonsterType m) => m.floor).toList(),
          <int>[1, 2, 3, 4, 5, 6, 7]);
      expect(MonsterData.byId('dragon')?.name, '幼龙');
    });

    test('深层怪物属性递增', () {
      for (int i = 1; i < MonsterData.all.length; i++) {
        expect(MonsterData.all[i].maxHp,
            greaterThan(MonsterData.all[i - 1].maxHp));
        expect(MonsterData.all[i].attack,
            greaterThan(MonsterData.all[i - 1].attack));
      }
    });

    test('伤害结算不会低于 1，且受防御减免', () {
      final Monster slime = MonsterData.byId('slime')!.spawn();
      final int dmg = slime.takeDamage(1000);
      expect(dmg, greaterThanOrEqualTo(1));
      expect(slime.hp, lessThan(slime.type.maxHp));

      final Monster weak = MonsterData.byId('slime')!.spawn();
      expect(weak.takeDamage(1), 1, reason: '攻击力低于防御时仍造成 1 点伤害');
    });

    test('战斗可判定胜负并发放奖励', () {
      final Monster dragon = MonsterData.byId('dragon')!.spawn();
      final BattleResult win = MonsterData.resolveBattle(
        dragon,
        playerAttack: 100000,
        playerHp: 100000,
      );
      expect(win.playerWon, isTrue);
      expect(win.expGain, dragon.type.expReward);
      expect(win.goldGain, dragon.type.goldReward);

      final Monster golem = MonsterData.byId('golem')!.spawn();
      final BattleResult lose = MonsterData.resolveBattle(
        golem,
        playerAttack: 1,
        playerHp: 1,
      );
      expect(lose.playerWon, isFalse);
      expect(lose.goldGain, 0);
    });
  });

  group('采矿楼层（7 层，每层 30×20）', () {
    test('楼层规格正确', () {
      expect(MineFloor.totalFloors, 7);
      expect(MineFloor.defaultWidth, 30);
      expect(MineFloor.defaultRows, 20);

      final MineManager mm = MineManager(seed: 42);
      final MineFloor f = mm.enter();
      expect(f.floorNumber, 1);
      expect(f.width, 30);
      expect(f.height, 20);
      expect(f.cells.length, 600);
      expect(mm.inMine, isTrue);
    });

    test('边界为墙壁，出生点可通行，出口为楼梯', () {
      final MineManager mm = MineManager(seed: 42);
      final MineFloor f = mm.enter();

      expect(f.at(0, 0)!.type, CellType.wall);
      expect(f.at(f.width - 1, 0)!.type, CellType.wall);
      expect(f.at(1, 1)!.type, CellType.floor, reason: '出生点应为可通行地面');
      expect(f.isWalkable(1, 1), isTrue);
      expect(f.at(f.stairsCol, f.stairsRow)!.type, CellType.stairs);
      expect(f.isStairs(f.stairsCol, f.stairsRow), isTrue);
    });

    test('每层都生成了矿石与怪物', () {
      final MineManager mm = MineManager(seed: 7);
      for (int floor = 1; floor <= MineFloor.totalFloors; floor++) {
        final MineFloor f = mm.floor(floor);
        expect(f.remainingOres, greaterThan(0), reason: '第 $floor 层应有矿石');
        expect(f.monsters, isNotEmpty, reason: '第 $floor 层应有怪物');
      }
    });

    test('深层可遇到更多种类的怪物', () {
      final MineManager mm = MineManager(seed: 7);
      expect(MonsterData.encounterableOn(1).length, 1);
      expect(MonsterData.encounterableOn(7).length, 7);
      expect(mm.floor(7).aliveMonsters, greaterThan(0));
    });

    test('采集矿石需多次敲击并产出收益', () {
      final MineManager mm = MineManager(seed: 42);
      final MineFloor f = mm.enter();

      // 找到一个矿石格
      int oreCol = -1, oreRow = -1;
      for (int r = 0; r < f.height && oreCol < 0; r++) {
        for (int c = 0; c < f.width; c++) {
          if (f.at(c, r)!.type == CellType.ore) {
            oreCol = c;
            oreRow = r;
            break;
          }
        }
      }
      expect(oreCol, greaterThanOrEqualTo(0), reason: '应能找到矿石');

      final Cell cell = f.at(oreCol, oreRow)!;
      final int hpBefore = cell.oreHp;
      expect(hpBefore, greaterThan(0));

      final int before = f.remainingOres;
      int earned = 0;
      for (int i = 0; i < hpBefore; i++) {
        earned = f.mine(oreCol, oreRow);
      }
      expect(earned, greaterThan(0), reason: '采完后应产出收益');
      expect(cell.type, CellType.floor);
      expect(f.remainingOres, before - 1);
    });

    test('击败怪物后会从地图移除，不可重复获取奖励', () {
      final MineManager mm = MineManager(seed: 42);
      final MineFloor f = mm.enter();
      final Monster m = f.monsters.first;

      int mc = -1, mr = -1;
      for (int r = 0; r < f.height && mc < 0; r++) {
        for (int c = 0; c < f.width; c++) {
          if (f.at(c, r)!.monster == m) {
            mc = c;
            mr = r;
            break;
          }
        }
      }
      expect(mc, greaterThanOrEqualTo(0));

      final int before = f.aliveMonsters;
      final BattleResult? res = f.attack(mc, mr,
          playerAttack: 100000, playerHp: 100000);
      expect(res, isNotNull);
      expect(res!.playerWon, isTrue);
      expect(f.at(mc, mr)!.monster, isNull);
      expect(f.aliveMonsters, before - 1);

      // 再次攻击同一格应返回 null（怪物已移除）
      expect(
          f.attack(mc, mr, playerAttack: 100000, playerHp: 100000), isNull);
    });

    test('逐层下行至最深层后无法继续，可逐层上行离开', () {
      final MineManager mm = MineManager(seed: 1);
      mm.enter();
      expect(mm.currentFloor, 1);

      for (int i = 2; i <= MineFloor.totalFloors; i++) {
        final MineFloor? next = mm.descend();
        expect(next, isNotNull);
        expect(mm.currentFloor, i);
      }
      expect(mm.current!.isDeepest, isTrue);
      expect(mm.descend(), isNull, reason: '最深层不能再下行');

      expect(mm.ascend(), isNotNull);
      expect(mm.currentFloor, MineFloor.totalFloors - 1);

      mm.exit();
      expect(mm.inMine, isFalse);
      expect(mm.current, isNull);
    });
  });

  // ------------------------------------------------------------------ 祭典
  group('祭典系统（7 个）', () {
    test('共 7 个，三种类型齐备', () {
      expect(FestivalSystem.count, 7);
      final Set<FestivalType> types =
          FestivalSystem.all.map((Festival f) => f.type).toSet();
      expect(types.length, FestivalType.values.length);
    });

    test('四季均有祭典，日期合法', () {
      for (final Season s in <Season>[
        Season.spring,
        Season.summer,
        Season.autumn,
        Season.winter
      ]) {
        expect(FestivalSystem().inSeason(s), isNotEmpty,
            reason: '${s.label} 应有祭典');
      }
      for (final Festival f in FestivalSystem.all) {
        expect(f.day >= 1 && f.day <= FestivalSystem.daysPerSeason, isTrue);
        expect(f.season, isNot(Season.greenhouse),
            reason: '温室不参与祭典日历');
      }
    });

    test('按日期触发，非当日不触发', () {
      final FestivalSystem fs = FestivalSystem();
      expect(fs.isFestivalDay(Season.spring, 8), isTrue);
      expect(fs.todayFestival(Season.spring, 8)?.name, '花之祭');
      expect(fs.isFestivalDay(Season.spring, 9), isFalse);
      expect(fs.todayFestival(Season.spring, 9), isNull);
    });

    test('满足条件可参与并发放奖励', () {
      final FestivalSystem fs = FestivalSystem();
      final Festival f = fs.todayFestival(Season.spring, 8)!;
      final FestivalResult r = fs.attend(f,
          season: Season.spring,
          day: 8,
          playerLevel: 5,
          playerStamina: 100);
      expect(r.allowed, isTrue);
      expect(r.goldReward, f.goldReward);
      expect(r.affinityReward, f.affinityReward);
      expect(fs.hasAttended(f.id), isTrue);
      expect(fs.attendedCount, 1);
    });

    test('同一祭典不可重复参与', () {
      final FestivalSystem fs = FestivalSystem();
      final Festival f = fs.todayFestival(Season.spring, 8)!;
      fs.attend(f,
          season: Season.spring, day: 8, playerLevel: 5, playerStamina: 100);
      final FestivalResult again = fs.attend(f,
          season: Season.spring, day: 8, playerLevel: 5, playerStamina: 100);
      expect(again.allowed, isFalse);
      expect(again.message, contains('已经参加过'));
    });

    test('非举办日、等级不足、体力不足、缺物品均被拒绝', () {
      final FestivalSystem fs = FestivalSystem();
      final Festival flower = fs.todayFestival(Season.spring, 8)!;

      expect(
          fs
              .attend(flower,
                  season: Season.summer,
                  day: 8,
                  playerLevel: 5,
                  playerStamina: 100)
              .allowed,
          isFalse,
          reason: '季节不符');

      final Festival fishing = fs.todayFestival(Season.summer, 12)!;
      expect(
          fs
              .attend(fishing,
                  season: Season.summer,
                  day: 12,
                  playerLevel: 1,
                  playerStamina: 100)
              .allowed,
          isFalse,
          reason: '等级不足（需 3 级）');
      expect(
          fs
              .attend(fishing,
                  season: Season.summer,
                  day: 12,
                  playerLevel: 9,
                  playerStamina: 0)
              .allowed,
          isFalse,
          reason: '体力不足');
      expect(
          fs
              .attend(fishing,
                  season: Season.summer,
                  day: 12,
                  playerLevel: 9,
                  playerStamina: 100,
                  hasItem: (String id) => false)
              .allowed,
          isFalse,
          reason: '缺少必需物品');
      expect(fs.hasAttended(fishing.id), isFalse,
          reason: '被拒绝的参与不应计入记录');
    });

    test('祭典所需物品均可实际获得（作物或钓鱼）', () {
      for (final Festival f in FestivalSystem.all) {
        if (f.requiredItemId.isEmpty) continue;
        final bool obtainable = CropsData.byId(f.requiredItemId) != null ||
            f.requiredItemId == 'fish_big';
        expect(obtainable, isTrue,
            reason: '${f.name} 要求的 ${f.requiredItemId} 无法获得');
      }
    });

    test('下一个祭典按四季日历推算', () {
      final FestivalSystem fs = FestivalSystem();
      final (Festival, int)? next = fs.nextFestival(Season.spring, 1);
      expect(next, isNotNull);
      expect(next!.$1.id, 'spring_flower');
      expect(next.$2, 7, reason: '春季第 1 天到第 8 天相差 7 天');

      // 温室内没有祭典日历
      expect(fs.nextFestival(Season.greenhouse, 1), isNull);

      // 参加后应顺延到下一个祭典
      fs.attend(next.$1,
          season: Season.spring, day: 8, playerLevel: 5, playerStamina: 100);
      final (Festival, int)? after = fs.nextFestival(Season.spring, 8);
      expect(after, isNotNull);
      expect(after!.$1.id, 'summer_fishing');
      expect(after.$2, 32);
    });

    test('跨年重置参与记录', () {
      final FestivalSystem fs = FestivalSystem();
      fs.attend(fs.todayFestival(Season.spring, 8)!,
          season: Season.spring, day: 8, playerLevel: 5, playerStamina: 100);
      expect(fs.attendedCount, 1);
      fs.onNewYear();
      expect(fs.attendedCount, 0);
      expect(fs.unattended.length, FestivalSystem.count);
    });
  });

  // ------------------------------------------------------------------ 任务
  group('任务系统（15 个）', () {
    test('共 15 个：主线 7 + 支线 8', () {
      expect(QuestSystem.count, 15);
      expect(QuestSystem.mainCount, 7);
      expect(QuestSystem.sideCount, 8);
      final QuestSystem qs = QuestSystem();
      expect(qs.progressList.length, 15);
    });

    test('六种任务类型全部覆盖', () {
      final Map<QuestType, int> byType = QuestSystem().countByType();
      expect(byType.length, QuestType.values.length);
      for (final QuestType t in QuestType.values) {
        expect(byType[t], greaterThan(0), reason: '${t.label} 类任务缺失');
      }
    });

    test('任务目标 ID 均指向真实存在的作物或怪物', () {
      const Set<String> meta = <String>{
        'any_monster',
        'any_crop',
        'any_fish',
        'any_npc',
        'all_npc',
        'hoe_tile',
      };
      for (final Quest q in QuestSystem.all) {
        if (meta.contains(q.targetId)) continue;
        final bool exists = CropsData.byId(q.targetId) != null ||
            MonsterData.byId(q.targetId) != null;
        expect(exists, isTrue,
            reason: '任务 ${q.id} 的目标 ${q.targetId} 不存在，将永远无法完成');
      }
    });

    test('主线任务前置链完整且顺序解锁', () {
      final QuestSystem qs = QuestSystem();
      expect(qs.progressOf('main_1')!.status, QuestStatus.inProgress);
      expect(qs.progressOf('main_2')!.status, QuestStatus.notStarted);
      expect(qs.canAccept('main_2'), isFalse, reason: '前置未完成不可接受');
      expect(qs.accept('main_2'), isFalse);

      qs.progressOf('main_1')!.progress = 5;
      qs.progressOf('main_1')!.status = QuestStatus.completed;
      qs.accept('main_1'); // 已完成后接受应失败
      expect(qs.canAccept('main_2'), isTrue);
      expect(qs.accept('main_2'), isTrue);
      expect(qs.progressOf('main_2')!.status, QuestStatus.inProgress);
    });

    test('锄地推进开垦任务，进入矿洞不会误推进', () {
      final QuestSystem qs = QuestSystem();
      for (int i = 0; i < 4; i++) {
        qs.onHoe();
      }
      expect(qs.progressOf('main_1')!.progress, 4);
      expect(qs.progressOf('main_1')!.status, QuestStatus.inProgress);

      // 探索类事件不应推进开垦任务
      qs.onExplore('mine_floor_1');
      expect(qs.progressOf('main_1')!.progress, 4);

      qs.onHoe();
      expect(qs.progressOf('main_1')!.status, QuestStatus.completed);
      expect(qs.progressOf('main_1')!.progressText, '5/5');
      expect(qs.progressOf('main_1')!.ratio, 1);
    });

    test('种植与收获按作物 ID 精确推进对应任务', () {
      final QuestSystem qs = QuestSystem();
      qs.onPlant('spring_wheat');
      qs.onPlant('spring_wheat');
      qs.onPlant('spring_wheat');
      expect(qs.progressOf('main_2')!.progress, 0,
          reason: 'main_2 尚未解锁，不应累计');

      qs.onHarvest('spring_wheat');
      expect(qs.progressOf('side_1')!.progress, 1);
      qs.onHarvest('spring_strawberry');
      expect(qs.progressOf('side_1')!.progress, 1,
          reason: '不同作物不应推进该任务');
    });

    test('击杀按怪物 ID 推进，any_monster 匹配任意怪物', () {
      final QuestSystem qs = QuestSystem();
      qs.onKill('goblin');
      expect(qs.progressOf('side_3')!.progress, 1);

      // 主线 any_monster 任务未解锁，先解锁再验证
      final QuestProgress main4 = qs.progressOf('main_4')!;
      main4.status = QuestStatus.inProgress;
      qs.onKill('slime');
      expect(main4.progress, 1);
      qs.onKill('bat');
      expect(main4.progress, 2);
    });

    test('对话任务按 NPC 去重，重复交谈不重复计数', () {
      final QuestSystem qs = QuestSystem();
      // main_3 的前置链未满足，需先解锁才会追踪进度。
      qs.progressOf('main_3')!.status = QuestStatus.inProgress;

      qs.onTalk('john');
      qs.onTalk('john');
      qs.onTalk('john');
      expect(qs.progressOf('main_3')!.progress, 1);

      qs.onTalk('mary');
      expect(qs.progressOf('main_3')!.progress, 2);

      // all_npc 任务需集齐 17 位（john、mary 已在上面计入）
      final QuestProgress side8 = qs.progressOf('side_8')!;
      side8.status = QuestStatus.inProgress;
      expect(side8.progress, 2);
      for (final Npc n in NpcData.all) {
        qs.onTalk(n.id);
      }
      expect(side8.progress, 17);
      expect(side8.status, QuestStatus.completed);
      expect(side8.remaining, 0);
    });

    test('钓鱼任务可被推进', () {
      final QuestSystem qs = QuestSystem();
      qs.onFish('fish_normal');
      expect(qs.progressOf('side_5')!.progress, 1);
      qs.onFish('fish_big');
      expect(qs.progressOf('side_5')!.progress, 2);
    });

    test('完成后可领奖，且只能领一次', () {
      final QuestSystem qs = QuestSystem();
      for (int i = 0; i < 5; i++) {
        qs.onHoe();
      }
      final QuestProgress main1 = qs.progressOf('main_1')!;
      expect(main1.status, QuestStatus.completed);
      expect(qs.claimable, contains(main1));

      final (int, int, String, int)? reward = qs.claim('main_1');
      expect(reward, isNotNull);
      expect(reward!.$1, main1.quest.goldReward);
      expect(reward.$2, main1.quest.expReward);

      expect(qs.claim('main_1'), isNull, reason: '奖励不可重复领取');
      expect(qs.claim('not_exist'), isNull);
    });

    test('未完成任务不可领奖', () {
      final QuestSystem qs = QuestSystem();
      expect(qs.claim('main_1'), isNull);
      expect(qs.completedCount, 0);
    });

    test('任务可完成：全部 15 个任务的目标都能达成', () {
      final QuestSystem qs = QuestSystem();

      // 逐个任务验证：派发事件前同时重置状态与进度。
      // 注意 any_* 类任务会顺带推进同类型的其他任务，
      // 而 advance() 对已完成任务不再生效，故必须在每轮前重置。
      for (final Quest q in QuestSystem.all) {
        final QuestProgress p = qs.progressOf(q.id)!;
        p.status = QuestStatus.inProgress;
        p.progress = 0;

        switch (q.type) {
          case QuestType.explore:
            for (int i = 0; i < q.targetCount; i++) {
              qs.onHoe();
            }
            break;
          case QuestType.plant:
            for (int i = 0; i < q.targetCount; i++) {
              qs.onPlant(q.targetId == 'any_crop' ? 'spring_wheat' : q.targetId);
            }
            break;
          case QuestType.collect:
            for (int i = 0; i < q.targetCount; i++) {
              qs.onHarvest(q.targetId == 'any_crop' ? 'spring_wheat' : q.targetId);
            }
            break;
          case QuestType.kill:
            for (int i = 0; i < q.targetCount; i++) {
              qs.onKill(q.targetId == 'any_monster' ? 'slime' : q.targetId);
            }
            break;
          case QuestType.fish:
            for (int i = 0; i < q.targetCount; i++) {
              qs.onFish('fish_normal');
            }
            break;
          case QuestType.talk:
            if (q.targetId == 'all_npc' || q.targetId == 'any_npc') {
              for (int i = 0; i < q.targetCount && i < NpcData.count; i++) {
                qs.onTalk(NpcData.all[i].id);
              }
            }
            break;
        }
        expect(p.progress, greaterThan(0),
            reason: '任务 ${q.id} 无法被推进，玩家可能永远无法完成');
        // 目标数量可达时应当完成
        if (q.targetId != 'all_npc') {
          expect(p.status, QuestStatus.completed,
              reason: '任务 ${q.id} 达成目标数量后应完成');
        }
      }
    });

    test('存档与读档可往返', () {
      final QuestSystem qs = QuestSystem();
      qs.onHoe();
      qs.onHoe();
      final Map<String, dynamic> saved = qs.save();

      final QuestSystem restored = QuestSystem();
      restored.load(saved);
      expect(restored.progressOf('main_1')!.progress, 2);
      expect(restored.progressOf('main_1')!.status, QuestStatus.inProgress);
    });
  });

  // ------------------------------------------------------------------ 相机
  group('相机系统', () {
    test('世界坐标与屏幕坐标互转可逆', () {
      final Camera cam = Camera(
          viewportWidth: 800, viewportHeight: 480,
          worldWidth: 8000, worldHeight: 1200);
      cam.snapTo(1000, 600);
      expect(cam.toScreenX(cam.toWorldX(123)), closeTo(123, 0.001));
      expect(cam.toWorldX(cam.toScreenX(1234)), closeTo(1234, 0.001));
    });

    test('相机不会越出世界边界', () {
      final Camera cam = Camera(
          viewportWidth: 800, viewportHeight: 480,
          worldWidth: 8000, worldHeight: 1200);
      cam.snapTo(-5000, -5000);
      expect(cam.x, 0);
      expect(cam.y, 0);

      cam.snapTo(999999, 999999);
      expect(cam.x, 8000 - 800);
      expect(cam.y, 1200 - 480);
    });

    test('平滑跟随逐步逼近目标', () {
      final Camera cam = Camera(
          viewportWidth: 800, viewportHeight: 480,
          worldWidth: 8000, worldHeight: 1200);
      cam.snapTo(0, 600);
      final double startX = cam.x;
      cam.follow(3000, 600, dt: 1 / 60);
      expect(cam.x, greaterThan(startX));
      expect(cam.x, lessThan(3000));

      // 多帧后应显著靠近目标
      for (int i = 0; i < 600; i++) {
        cam.follow(3000, 600, dt: 1 / 60);
      }
      expect(cam.x, closeTo(3000 - 400, 5));
    });

    test('可见性裁剪判定正确', () {
      final Camera cam = Camera(
          viewportWidth: 800, viewportHeight: 480,
          worldWidth: 8000, worldHeight: 1200);
      cam.snapTo(1000, 600);
      expect(cam.isVisible(1200, 700), isTrue);
      expect(cam.isVisible(7000, 700), isFalse);
      expect(cam.rectVisible(1100, 650, 50, 50), isTrue);
      expect(cam.rectVisible(6000, 650, 50, 50), isFalse);
    });

    test('缩放受范围约束', () {
      final Camera cam = Camera();
      cam.setZoom(10);
      expect(cam.zoom, 2.0);
      cam.setZoom(0.01);
      expect(cam.zoom, 0.5);
    });
  });

  // ------------------------------------------------------------------ UI
  group('UI 组件', () {
    testWidgets('顶栏显示名称、金币与体力', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TopBar(
            gameName: '牧场物语',
            gold: 1234,
            stamina: 80,
            maxStamina: 100,
            level: 3,
            expProgress: 0.5,
            seasonLabel: '春季',
            dayLabel: '第 5 天',
            timeLabel: '08:30',
            locationLabel: '我的牧场',
          ),
        ),
      ));
      expect(find.text('牧场物语'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('80/100'), findsOneWidget);
      expect(find.text('Lv.3'), findsOneWidget);
      expect(find.text('我的牧场'), findsOneWidget);
      expect(find.text('春季 第 5 天 08:30'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2),
          reason: '经验条与体力条各一');
    });

    testWidgets('顶栏高度为 28px', (WidgetTester tester) async {
      expect(TopBar.barHeight, 28);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TopBar(gameName: '牧场物语', gold: 0, stamina: 1, maxStamina: 1),
        ),
      ));
      expect(tester.getSize(find.byType(TopBar)).height, 28);
    });

    testWidgets('底栏包含锄地、播种、工具、NPC、背包五个按钮',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomBar(
            selected: ToolType.hoe,
            onSelected: (ToolType t) {},
          ),
        ),
      ));
      for (final ToolType t in ToolType.values) {
        expect(find.text(t.label), findsOneWidget);
      }
      expect(ToolType.values.length, 5);
    });

    testWidgets('底栏高度为 44px 且点击可回调', (WidgetTester tester) async {
      expect(BottomBar.barHeight, 44);
      ToolType? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomBar(
            selected: null,
            onSelected: (ToolType t) => tapped = t,
          ),
        ),
      ));
      expect(tester.getSize(find.byType(BottomBar)).height, 44);

      await tester.tap(find.text('背包'));
      expect(tapped, ToolType.bag);

      await tester.tap(find.text('播种'));
      expect(tapped, ToolType.seed);
    });

    testWidgets('底栏禁用时不响应点击，角标可显示', (WidgetTester tester) async {
      ToolType? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomBar(
            selected: ToolType.hoe,
            onSelected: (ToolType t) => tapped = t,
            enabled: false,
            badges: const <ToolType, String>{ToolType.bag: '12'},
            hint: '提示文案',
          ),
        ),
      ));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('提示文案'), findsOneWidget);
      await tester.tap(find.text('锄地'));
      expect(tapped, isNull, reason: '禁用状态下不应触发回调');
    });
  });
}
