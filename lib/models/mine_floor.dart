/// 采矿楼层系统（7 层）
///
/// 每层 30×20 地图，包含墙壁、矿石、怪物、楼梯出口。随机生成地图。
library;

import 'dart:math' as math;

import 'monster.dart';

/// 地图格子类型。
enum CellType {
  /// 地面：可通行。
  floor,

  /// 墙壁：不可通行。
  wall,

  /// 矿石：可采集，采集后变为地面。
  ore,

  /// 楼梯出口：通往下一层。
  stairs,
}

/// 矿石种类。
enum OreType {
  stone('石头', 0xFF9E9E9E, value: 5, hp: 1),
  copper('铜矿', 0xFFC87F4A, value: 20, hp: 2),
  iron('铁矿', 0xFFB0A8A0, value: 45, hp: 3),
  silver('银矿', 0xFFDCE3E8, value: 90, hp: 4),
  gold('金矿', 0xFFE3C34A, value: 200, hp: 5),
  gem('宝石', 0xFF5FC9D6, value: 480, hp: 6);

  const OreType(this.label, this.color, {required this.value, required this.hp});

  /// 中文名称。
  final String label;

  /// 代表色（ARGB）。
  final int color;

  /// 出售价格。
  final int value;

  /// 开采所需敲击次数。
  final int hp;
}

/// 地图单元格。
class Cell {
  Cell(this.type, {this.ore, this.oreHp = 0, this.monster});

  /// 格子类型。
  CellType type;

  /// 矿石种类（仅 [CellType.ore] 有效）。
  OreType? ore;

  /// 矿石剩余敲击次数。
  int oreHp;

  /// 占据该格的怪物（可空）。
  Monster? monster;

  /// 是否阻挡通行。
  bool get blocksMovement => type == CellType.wall || type == CellType.ore;

  /// 敲击一次矿石，返回是否被采完；采完时格子变为地面。
  /// 非矿石格返回 false。
  bool hitOre() {
    if (type != CellType.ore) return false;
    oreHp--;
    if (oreHp <= 0) {
      final OreType o = ore ?? OreType.stone;
      type = CellType.floor;
      oreHp = 0;
      ore = null;
      // 采完后记录产出，便于调用方结算收益。
      lastMinedValue = o.value;
      return true;
    }
    return false;
  }

  /// 最近一次采完矿石的价值（0 表示本次未采完）。
  int lastMinedValue = 0;

  @override
  String toString() => 'Cell(${type.name})';
}

/// 单层采矿地图。
class MineFloor {
  MineFloor({
    required this.floorNumber,
    required this.width,
    required this.height,
    required this.seed,
  }) {
    _cells = List<Cell>.generate(
      width * height,
      (_) => Cell(CellType.floor),
    );
    _generate();
  }

  /// 默认地图宽度（列数）。
  static const int defaultWidth = 30;

  /// 默认地图高度（行数）。
  static const int defaultRows = 20;

  /// 采矿总层数。
  static const int totalFloors = 7;

  /// 单格边长（像素）。
  static const double cellSize = 32;

  /// 层号（1~7）。
  final int floorNumber;

  /// 地图宽度（列数）。
  final int width;

  /// 地图高度（行数）。
  final int height;

  /// 随机种子（便于复现同一层地图）。
  final int seed;

  late List<Cell> _cells;
  late math.Random _rng;

  /// 玩家出生点列。
  int spawnCol = 1;

  /// 玩家出生点行。
  int spawnRow = 1;

  /// 楼梯出口列。
  int stairsCol = 0;

  /// 楼梯出口行。
  int stairsRow = 0;

  /// 本层怪物列表。
  final List<Monster> monsters = <Monster>[];

  /// 地图总像素宽度。
  double get pixelWidth => width * cellSize;

  /// 地图总像素高度。
  double get pixelHeight => height * cellSize;

  /// 是否已是最后一层（无下一层出口）。
  bool get isDeepest => floorNumber >= totalFloors;

  // ------------------------------------------------------------------ 生成

  void _generate() {
    _rng = math.Random(seed + floorNumber * 7919);

    // 1) 边界墙。
    for (int c = 0; c < width; c++) {
      _set(c, 0, Cell(CellType.wall));
      _set(c, height - 1, Cell(CellType.wall));
    }
    for (int r = 0; r < height; r++) {
      _set(0, r, Cell(CellType.wall));
      _set(width - 1, r, Cell(CellType.wall));
    }

    // 2) 内部随机墙壁（密度随层数递增，越深越复杂）。
    final double wallDensity = 0.10 + floorNumber * 0.012;
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (_rng.nextDouble() < wallDensity) {
          _set(c, r, Cell(CellType.wall));
        }
      }
    }

    // 3) 保证出生点与出口周围为可通行地面。
    spawnCol = 1;
    spawnRow = 1;
    stairsCol = width - 2;
    stairsRow = height - 2;
    _clearArea(spawnCol, spawnRow, radius: 1);
    _clearArea(stairsCol, stairsRow, radius: 1);

    // 4) 生成矿石（层数越深，高价值矿石概率越高）。
    final int oreCount = 12 + floorNumber * 4;
    for (int i = 0; i < oreCount; i++) {
      final Cell? cell = _randomEmptyCell();
      if (cell == null) continue;
      final OreType ore = _pickOre();
      cell.type = CellType.ore;
      cell.ore = ore;
      cell.oreHp = ore.hp;
    }

    // 5) 生成怪物（每层以本层怪物为主，混入低层怪物）。
    final int monsterCount = 4 + floorNumber * 2;
    final List<MonsterType> pool = MonsterData.encounterableOn(floorNumber);
    for (int i = 0; i < monsterCount && pool.isNotEmpty; i++) {
      final Cell? cell = _randomEmptyCell();
      if (cell == null) continue;
      // 越深的层，越倾向抽到高层怪物。
      final int idx = _rng.nextInt(pool.length);
      final MonsterType type = pool[idx];
      final Monster m = Monster(type: type);
      cell.monster = m;
      monsters.add(m);
    }

    // 6) 放置楼梯出口。
    _set(stairsCol, stairsRow, Cell(CellType.stairs));

    // 7) 连通性修复：确保出生点到出口可达（简化为清除一条 L 形通道）。
    _carveCorridor();
  }

  void _set(int c, int r, Cell cell) {
    if (c < 0 || c >= width || r < 0 || r >= height) return;
    _cells[r * width + c] = cell;
  }

  void _clearArea(int c, int r, {int radius = 1}) {
    for (int rr = r - radius; rr <= r + radius; rr++) {
      for (int cc = c - radius; cc <= c + radius; cc++) {
        if (cc <= 0 || cc >= width - 1 || rr <= 0 || rr >= height - 1) continue;
        final Cell? cell = at(cc, rr);
        if (cell == null) continue;
        if (cell.type == CellType.wall || cell.type == CellType.ore) {
          cell.type = CellType.floor;
          cell.ore = null;
          cell.oreHp = 0;
        }
      }
    }
  }

  /// 清除一条从出生点到出口的 L 形通道，保证连通。
  void _carveCorridor() {
    for (int c = spawnCol; c <= stairsCol; c++) {
      final Cell? cell = at(c, spawnRow);
      if (cell != null && cell.type == CellType.wall) cell.type = CellType.floor;
    }
    for (int r = spawnRow; r <= stairsRow; r++) {
      final Cell? cell = at(stairsCol, r);
      if (cell != null && cell.type == CellType.wall) cell.type = CellType.floor;
    }
  }

  Cell? _randomEmptyCell() {
    for (int attempt = 0; attempt < 60; attempt++) {
      final int c = 1 + _rng.nextInt(width - 2);
      final int r = 1 + _rng.nextInt(height - 2);
      if (c == spawnCol && r == spawnRow) continue;
      if (c == stairsCol && r == stairsRow) continue;
      final Cell cell = _cells[r * width + c];
      if (cell.type == CellType.floor && cell.monster == null) return cell;
    }
    return null;
  }

  /// 按层数抽取矿石种类：越深高价值矿石概率越高。
  OreType _pickOre() {
    final double roll = _rng.nextDouble();
    final double bonus = floorNumber * 0.05;
    if (roll < 0.02 + bonus * 0.6) return OreType.gem;
    if (roll < 0.08 + bonus) return OreType.gold;
    if (roll < 0.22 + bonus) return OreType.silver;
    if (roll < 0.45) return OreType.iron;
    if (roll < 0.72) return OreType.copper;
    return OreType.stone;
  }

  // ------------------------------------------------------------------ 查询

  /// 索引合法性。
  bool inBounds(int c, int r) => c >= 0 && c < width && r >= 0 && r < height;

  /// 取格子，越界返回 null。
  Cell? at(int c, int r) => inBounds(c, r) ? _cells[r * width + c] : null;

  /// 由世界坐标取格子。
  Cell? cellAtWorld(double wx, double wy) =>
      at((wx / cellSize).floor(), (wy / cellSize).floor());

  /// 只读格子列表（行优先）。
  List<Cell> get cells => List<Cell>.unmodifiable(_cells);

  /// 是否可通行。
  bool isWalkable(int c, int r) {
    final Cell? cell = at(c, r);
    return cell != null && !cell.blocksMovement;
  }

  /// 是否为楼梯出口。
  bool isStairs(int c, int r) => at(c, r)?.type == CellType.stairs;

  /// 采集矿石，返回收益金额（0 表示本次未采完或不是矿石）。
  int mine(int c, int r) {
    final Cell? cell = at(c, r);
    if (cell == null) return 0;
    cell.lastMinedValue = 0;
    cell.hitOre();
    return cell.lastMinedValue;
  }

  /// 攻击指定格子的怪物，返回战斗结果；无怪物返回 null。
  BattleResult? attack(int c, int r,
      {required int playerAttack, required int playerHp, int playerDefense = 0}) {
    final Cell? cell = at(c, r);
    final Monster? m = cell?.monster;
    if (m == null) return null;
    final BattleResult res = MonsterData.resolveBattle(
      m,
      playerAttack: playerAttack,
      playerHp: playerHp,
      playerDefense: playerDefense,
      rng: _rng,
    );
    if (res.playerWon) {
      cell!.monster = null;
      monsters.remove(m);
    }
    return res;
  }

  /// 剩余怪物数。
  int get aliveMonsters =>
      monsters.where((Monster m) => m.isAlive).length;

  /// 剩余矿石数。
  int get remainingOres {
    int n = 0;
    for (final Cell cell in _cells) {
      if (cell.type == CellType.ore) n++;
    }
    return n;
  }

  /// 本层是否已清空（怪物全灭且矿石采完）。
  bool get cleared => aliveMonsters == 0 && remainingOres == 0;
}

/// 采矿管理器：维护 7 层地图与当前所在层。
class MineManager {
  MineManager({int? seed}) : _seed = seed ?? math.Random().nextInt(1 << 30);

  final int _seed;
  final Map<int, MineFloor> _cache = <int, MineFloor>{};

  /// 当前所在层（0 表示不在矿洞内）。
  int currentFloor = 0;

  /// 是否在矿洞中。
  bool get inMine => currentFloor > 0;

  /// 总层数。
  static const int totalFloors = MineFloor.totalFloors;

  /// 取指定层地图（懒生成 + 缓存）。层号自动限制在 1~7。
  MineFloor floor(int n) {
    int f = n;
    if (f < 1) f = 1;
    if (f > totalFloors) f = totalFloors;
    return _cache.putIfAbsent(
      f,
      () => MineFloor(
        floorNumber: f,
        width: MineFloor.defaultWidth,
        height: MineFloor.defaultRows,
        seed: _seed,
      ),
    );
  }

  /// 进入矿洞第 1 层。
  MineFloor enter() {
    currentFloor = 1;
    return floor(1);
  }

  /// 当前层地图；不在矿洞中返回 null。
  MineFloor? get current => inMine ? floor(currentFloor) : null;

  /// 下楼；已在最深层返回 null。
  MineFloor? descend() {
    if (!inMine || currentFloor >= totalFloors) return null;
    currentFloor++;
    return floor(currentFloor);
  }

  /// 上楼；已在第 1 层则离开矿洞并返回 null。
  MineFloor? ascend() {
    if (!inMine) return null;
    if (currentFloor <= 1) {
      currentFloor = 0;
      return null;
    }
    currentFloor--;
    return floor(currentFloor);
  }

  /// 离开矿洞。
  void exit() => currentFloor = 0;

  /// 重置所有层地图（重新随机生成）。
  void reset() => _cache.clear();

  /// 各层清空状态。
  Map<int, bool> get clearState => <int, bool>{
        for (int i = 1; i <= totalFloors; i++) i: _cache[i]?.cleared ?? false,
      };
}
