/// 田地系统
///
/// 支持 5 种状态：empty（空地）、hoe（锄地）、planted（已播种）、
/// grown（成熟）、withered（枯萎）。
/// [FieldManager] 管理 20×15 块田地，支持锄地、播种、收获操作。
///
/// 扣费约定：本层只做**合法性检查**（通过 [hasStamina] / [hasGold] 回调），
/// 不直接修改玩家数值；成功后由调用方按 [FieldResult.staminaCost] 与
/// [FieldResult.goldCost] 扣除，避免出现扣款后回退失败的中间状态。
library;

import 'dart:math' as math;

import '../data/crops_data.dart';

/// 田块状态。
enum TileState {
  /// 空地：未开垦。
  empty('空地'),

  /// 锄地：已开垦，可播种。
  hoe('锄地'),

  /// 已播种：作物生长中。
  planted('已播种'),

  /// 成熟：可收获。
  grown('成熟'),

  /// 枯萎：超时未收获或季节不符。
  withered('枯萎');

  const TileState(this.label);

  /// 中文名称。
  final String label;

  /// 是否可以播种。
  bool get canPlant => this == TileState.hoe;

  /// 是否可以收获。
  bool get canHarvest => this == TileState.grown;

  /// 是否为已开垦土地（锄地/播种/成熟/枯萎）。
  bool get isTilled => this != TileState.empty;
}

/// 单个田块。
class FieldTile {
  FieldTile({required this.col, required this.row});

  /// 列索引（0 ~ cols-1）。
  final int col;

  /// 行索引（0 ~ rows-1）。
  final int row;

  /// 当前状态。
  TileState state = TileState.empty;

  /// 种植的作物配置，未种植为 null。
  Crop? crop;

  /// 播种时刻（毫秒时间戳）。
  int plantedAt = 0;

  /// 已累计的生长小时数。
  double elapsedHours = 0;

  /// 成熟后累计的过熟小时数，超过阈值则枯萎。
  double overripeHours = 0;

  /// 是否已浇水（浇水可加速生长）。
  bool watered = false;

  /// 浇水加速倍率。
  static const double waterSpeedUp = 1.25;

  /// 成熟后多少小时未收获会枯萎。
  static const double witherAfterHours = 48;

  /// 当前生长阶段索引。
  int get stage => crop?.stageAt(elapsedHours) ?? 0;

  /// 生长进度 0~1。
  double get progress {
    final Crop? c = crop;
    if (c == null || c.growHours <= 0) return 0;
    final double p = elapsedHours / c.growHours;
    if (p <= 0) return 0;
    return p >= 1 ? 1 : p;
  }

  /// 距离成熟还剩多少小时。
  double get remainHours {
    final Crop? c = crop;
    if (c == null) return 0;
    return math.max(0, c.growHours - elapsedHours);
  }

  /// 推进生长时间。[hours] 为本次经过的游戏小时数。
  void advanceHours(double hours) {
    if (hours <= 0) return;
    final double h = watered ? hours * waterSpeedUp : hours;

    switch (state) {
      case TileState.empty:
      case TileState.hoe:
      case TileState.withered:
        break;
      case TileState.planted:
        elapsedHours += h;
        final Crop? c = crop;
        if (c != null && c.isGrown(elapsedHours)) {
          state = TileState.grown;
          overripeHours = 0;
        }
        break;
      case TileState.grown:
        overripeHours += hours;
        if (overripeHours >= witherAfterHours) {
          state = TileState.withered;
        }
        break;
    }
  }

  /// 开垦：空地 → 锄地。
  bool hoeUp() {
    if (state != TileState.empty) return false;
    state = TileState.hoe;
    return true;
  }

  /// 播种：锄地 → 已播种。
  bool plant(Crop c, int nowMs) {
    if (!state.canPlant) return false;
    crop = c;
    plantedAt = nowMs;
    elapsedHours = 0;
    overripeHours = 0;
    watered = false;
    state = TileState.planted;
    return true;
  }

  /// 浇水，仅对生长中的田块有效。
  bool water() {
    if (state != TileState.planted || watered) return false;
    watered = true;
    return true;
  }

  /// 收获：成功返回 1。
  /// 再生作物收获后回到 [TileState.planted] 并保留剩余生长时间，
  /// 非再生作物收获后回到 [TileState.hoe]（保留开垦状态，可直接再播种）。
  int harvest() {
    if (!state.canHarvest || crop == null) return 0;
    final Crop c = crop!;
    if (c.regrow && c.regrowHours > 0) {
      elapsedHours = (c.growHours - c.regrowHours).toDouble();
      overripeHours = 0;
      watered = false;
      state = TileState.planted;
    } else {
      crop = null;
      plantedAt = 0;
      elapsedHours = 0;
      overripeHours = 0;
      watered = false;
      state = TileState.hoe;
    }
    return 1;
  }

  /// 完全重置为空地。
  void reset() {
    state = TileState.empty;
    crop = null;
    plantedAt = 0;
    elapsedHours = 0;
    overripeHours = 0;
    watered = false;
  }

  /// 清除枯萎作物，恢复为锄地状态。
  bool clearWithered() {
    if (state != TileState.withered) return false;
    crop = null;
    plantedAt = 0;
    elapsedHours = 0;
    overripeHours = 0;
    watered = false;
    state = TileState.hoe;
    return true;
  }

  @override
  String toString() => 'FieldTile($col,$row,${state.label})';
}

/// 田地操作结果。
class FieldResult {
  const FieldResult(
    this.success,
    this.message, {
    this.gain = 0,
    this.staminaCost = 0,
    this.goldCost = 0,
  });

  /// 成功结果。
  const FieldResult.ok(
    String message, {
    int gain = 0,
    int staminaCost = 0,
    int goldCost = 0,
  }) : this(true, message, gain: gain, staminaCost: staminaCost, goldCost: goldCost);

  /// 失败结果。
  const FieldResult.fail(String message) : this(false, message);

  /// 是否成功。
  final bool success;

  /// 提示文案。
  final String message;

  /// 获得金币数（仅收获成功时有值）。
  final int gain;

  /// 调用方应扣除的体力。
  final int staminaCost;

  /// 调用方应扣除的金币。
  final int goldCost;
}

/// 体力检查回调：给定消耗量，返回是否够用。
typedef StaminaCheck = bool Function(int cost);

/// 金币检查回调：给定金额，返回是否买得起。
typedef GoldCheck = bool Function(int cost);

/// 田地管理器：20×15 网格。
class FieldManager {
  FieldManager({
    this.cols = defaultCols,
    this.rows = defaultRows,
    this.tileSize = defaultTileSize,
  }) {
    _tiles = List<FieldTile>.generate(
      cols * rows,
      (int i) => FieldTile(col: i % cols, row: i ~/ cols),
    );
  }

  /// 默认列数。
  static const int defaultCols = 20;

  /// 默认行数。
  static const int defaultRows = 15;

  /// 默认单块田边长（像素）。
  static const double defaultTileSize = 40;

  /// 锄地消耗体力。
  static const int hoeStaminaCost = 2;

  /// 播种消耗体力。
  static const int plantStaminaCost = 1;

  /// 收获消耗体力。
  static const int harvestStaminaCost = 2;

  /// 浇水消耗体力。
  static const int waterStaminaCost = 1;

  /// 列数。
  final int cols;

  /// 行数。
  final int rows;

  /// 单块田边长。
  final double tileSize;

  late List<FieldTile> _tiles;

  /// 只读田块列表（行优先）。
  List<FieldTile> get tiles => List<FieldTile>.unmodifiable(_tiles);

  /// 田地总像素宽度。
  double get pixelWidth => cols * tileSize;

  /// 田地总像素高度。
  double get pixelHeight => rows * tileSize;

  /// 索引合法性检查。
  bool _valid(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows;

  /// 取田块，越界返回 null。
  FieldTile? tileAt(int col, int row) =>
      _valid(col, row) ? _tiles[row * cols + col] : null;

  /// 按线性索引取田块，越界返回 null。
  FieldTile? tileByIndex(int index) =>
      (index >= 0 && index < _tiles.length) ? _tiles[index] : null;

  /// 由世界坐标反算田块。
  ///
  /// [originX]/[originY] 为田地网格左上角的世界坐标。
  FieldTile? tileAtWorld(double wx, double wy,
      {double originX = 0, double originY = 0}) {
    final int col = ((wx - originX) / tileSize).floor();
    final int row = ((wy - originY) / tileSize).floor();
    return tileAt(col, row);
  }

  // ------------------------------------------------------------------ 操作

  /// 锄地：空地 → 锄地。
  FieldResult hoe(int col, int row, {StaminaCheck? hasStamina}) {
    final FieldTile? t = tileAt(col, row);
    if (t == null) return const FieldResult.fail('超出田地范围');
    if (t.state != TileState.empty) {
      return FieldResult.fail('这块地已经是${t.state.label}了');
    }
    if (hasStamina != null && !hasStamina(hoeStaminaCost)) {
      return const FieldResult.fail('体力不足，无法锄地');
    }
    t.hoeUp();
    return const FieldResult.ok('锄地完成', staminaCost: hoeStaminaCost);
  }

  /// 播种：锄地 → 已播种。[nowMs] 为当前毫秒时间戳。
  FieldResult plant(
    int col,
    int row,
    Crop? crop,
    int nowMs, {
    StaminaCheck? hasStamina,
    GoldCheck? hasGold,
  }) {
    final FieldTile? t = tileAt(col, row);
    if (t == null) return const FieldResult.fail('超出田地范围');
    if (crop == null) return const FieldResult.fail('请先选择种子');
    if (!t.state.canPlant) {
      return t.state == TileState.empty
          ? const FieldResult.fail('需要先锄地')
          : FieldResult.fail('当前状态（${t.state.label}）不能播种');
    }
    if (hasGold != null && !hasGold(crop.seedCost)) {
      return FieldResult.fail('金币不足，${crop.name}种子需要 ${crop.seedCost} 金');
    }
    if (hasStamina != null && !hasStamina(plantStaminaCost)) {
      return const FieldResult.fail('体力不足，无法播种');
    }
    t.plant(crop, nowMs);
    return FieldResult.ok('已播种：${crop.name}',
        staminaCost: plantStaminaCost, goldCost: crop.seedCost);
  }

  /// 浇水：加速生长。
  FieldResult water(int col, int row, {StaminaCheck? hasStamina}) {
    final FieldTile? t = tileAt(col, row);
    if (t == null) return const FieldResult.fail('超出田地范围');
    if (t.state != TileState.planted) {
      return const FieldResult.fail('只有生长中的作物需要浇水');
    }
    if (t.watered) return const FieldResult.fail('已经浇过水了');
    if (hasStamina != null && !hasStamina(waterStaminaCost)) {
      return const FieldResult.fail('体力不足，无法浇水');
    }
    t.water();
    return const FieldResult.ok('浇水完成，生长加速',
        staminaCost: waterStaminaCost);
  }

  /// 收获：成熟 → 锄地（或再生作物回到生长中）。
  FieldResult harvest(int col, int row, {StaminaCheck? hasStamina}) {
    final FieldTile? t = tileAt(col, row);
    if (t == null) return const FieldResult.fail('超出田地范围');
    if (t.state == TileState.withered) {
      return const FieldResult.fail('作物已枯萎，请清理后重新种植');
    }
    if (!t.state.canHarvest || t.crop == null) {
      return const FieldResult.fail('还没有成熟，再等等吧');
    }
    if (hasStamina != null && !hasStamina(harvestStaminaCost)) {
      return const FieldResult.fail('体力不足，无法收获');
    }
    final int price = t.crop!.price;
    final String name = t.crop!.name;
    final String cropId = t.crop!.id;
    if (t.harvest() == 0) return const FieldResult.fail('收获失败');
    logHarvest(cropId);
    return FieldResult.ok('收获 $name，+$price 金币',
        gain: price, staminaCost: harvestStaminaCost);
  }

  /// 清理枯萎作物。
  FieldResult clearWithered(int col, int row) {
    final FieldTile? t = tileAt(col, row);
    if (t == null) return const FieldResult.fail('超出田地范围');
    if (!t.clearWithered()) return const FieldResult.fail('这块地没有枯萎的作物');
    return const FieldResult.ok('已清理枯萎作物');
  }

  /// 批量锄地：以 [col]/[row] 为中心的 3×3 区域。
  List<FieldResult> hoeArea(int col, int row, {StaminaCheck? hasStamina}) {
    final List<FieldResult> results = <FieldResult>[];
    for (int r = row - 1; r <= row + 1; r++) {
      for (int c = col - 1; c <= col + 1; c++) {
        final FieldResult res = hoe(c, r, hasStamina: hasStamina);
        if (res.success) results.add(res);
      }
    }
    return results;
  }

  // ------------------------------------------------------------------ 时间推进

  /// 全局推进时间。[hours] 为经过的游戏小时数。
  void updateHours(double hours) {
    if (hours <= 0) return;
    for (final FieldTile t in _tiles) {
      t.advanceHours(hours);
    }
  }

  /// 按真实毫秒时间戳推进（实时计算生长）。
  ///
  /// 时间流速：现实 1 秒 = 游戏 1 分钟（60 倍速）。
  void updateFromTimestamp(int nowMs, int lastMs) {
    final double ms = (nowMs - lastMs).toDouble();
    if (ms <= 0) return;
    updateHours(ms / 1000 / 60);
  }

  /// 强制让所有生长中的作物立即成熟（调试/演示用）。
  void ripenAll() {
    for (final FieldTile t in _tiles) {
      final Crop? c = t.crop;
      if (t.state == TileState.planted && c != null) {
        t.elapsedHours = c.growHours.toDouble();
        t.state = TileState.grown;
        t.overripeHours = 0;
      }
    }
  }

  /// 季节更替：不属于当前季节的作物枯萎（温室作物豁免）。
  /// 返回受影响的田块数。
  int applySeasonChange(Season season) {
    int withered = 0;
    for (final FieldTile t in _tiles) {
      final Crop? c = t.crop;
      if (c == null) continue;
      if (c.season == Season.greenhouse) continue;
      if (c.season != season && t.state != TileState.withered) {
        t.state = TileState.withered;
        withered++;
      }
    }
    return withered;
  }

  // ------------------------------------------------------------------ 统计查询

  /// 按状态统计田块数量。
  Map<TileState, int> countByState() {
    final Map<TileState, int> m = <TileState, int>{
      for (final TileState s in TileState.values) s: 0,
    };
    for (final FieldTile t in _tiles) {
      m[t.state] = (m[t.state] ?? 0) + 1;
    }
    return m;
  }

  /// 可收获田块数量。
  int get harvestableCount =>
      _tiles.where((FieldTile t) => t.state.canHarvest).length;

  /// 可播种（已锄地）田块数量。
  int get plantableCount =>
      _tiles.where((FieldTile t) => t.state.canPlant).length;

  /// 生长中的田块数量。
  int get growingCount =>
      _tiles.where((FieldTile t) => t.state == TileState.planted).length;

  /// 枯萎田块数量。
  int get witheredCount =>
      _tiles.where((FieldTile t) => t.state == TileState.withered).length;

  /// 找出第一个可收获的田块，用于任务自动定位。
  FieldTile? get firstHarvestable {
    for (final FieldTile t in _tiles) {
      if (t.state.canHarvest) return t;
    }
    return null;
  }

  /// 各作物累计收获次数（key 为作物 ID）。
  final Map<String, int> harvestLog = <String, int>{};

  /// 记录一次收获（供任务系统统计）。
  void logHarvest(String cropId, [int times = 1]) {
    harvestLog[cropId] = (harvestLog[cropId] ?? 0) + times;
  }

  /// 指定作物累计收获次数。
  int harvestedCountOf(String cropId) => harvestLog[cropId] ?? 0;

  /// 全部收获总次数。
  int get totalHarvests => harvestLog.values.fold(0, (int a, int b) => a + b);

  /// 重置所有田地与收获记录。
  void clearAll() {
    for (final FieldTile t in _tiles) {
      t.reset();
    }
    harvestLog.clear();
  }
}
