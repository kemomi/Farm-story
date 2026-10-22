/// 游戏存档管理器
///
/// 使用 shared_preferences 持久化存储游戏进度。
/// 存档包含：玩家数据、田地状态、NPC 好感度、任务进度、祭典参与记录、游戏时间等。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/crops_data.dart';
import '../models/field.dart';
import '../models/mine_floor.dart';
import '../models/monster.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../systems/festival_system.dart';
import '../systems/npc_system.dart';
import '../systems/quest_system.dart';

/// 存档键名。
class SaveKeys {
  static const String saveData = 'farm_game_save_data';
  static const String saveVersion = 'farm_game_save_version';
  static const String saveTimestamp = 'farm_game_save_timestamp';
}

/// 当前存档版本（用于兼容未来数据结构变更）。
const int saveVersion = 1;

/// 游戏存档数据。
class GameSaveData {
  GameSaveData({
    required this.player,
    required this.fields,
    required this.npcSystem,
    required this.festivalSystem,
    required this.questSystem,
    required this.mineManager,
    required this.gameMinutes,
    required this.day,
    required this.seasonIndex,
    required this.year,
    required this.bag,
    required this.items,
    required this.inMine,
  });

  /// 玩家数据。
  final Map<String, dynamic> player;

  /// 田地数据。
  final List<Map<String, dynamic>> fields;

  /// NPC 系统数据。
  final Map<String, dynamic> npcSystem;

  /// 祭典系统数据。
  final List<String> festivalSystem;

  /// 任务系统数据。
  final Map<String, dynamic> questSystem;

  /// 矿洞管理器数据。
  final Map<String, dynamic> mineManager;

  /// 游戏内分钟数。
  final double gameMinutes;

  /// 当前日。
  final int day;

  /// 季节索引。
  final int seasonIndex;

  /// 当前年。
  final int year;

  /// 背包数据。
  final Map<String, int> bag;

  /// 物品栏数据。
  final Map<String, int> items;

  /// 是否在矿洞中。
  final bool inMine;

  /// 从 JSON 创建。
  factory GameSaveData.fromJson(Map<String, dynamic> json) {
    return GameSaveData(
      player: Map<String, dynamic>.from(json['player'] ?? {}),
      fields: List<Map<String, dynamic>>.from(
          json['fields'] ?? <Map<String, dynamic>>[]),
      npcSystem: Map<String, dynamic>.from(json['npcSystem'] ?? {}),
      festivalSystem: List<String>.from(json['festivalSystem'] ?? []),
      questSystem: Map<String, dynamic>.from(json['questSystem'] ?? {}),
      mineManager: Map<String, dynamic>.from(json['mineManager'] ?? {}),
      gameMinutes: (json['gameMinutes'] as num?)?.toDouble() ?? 6 * 60,
      day: json['day'] as int? ?? 1,
      seasonIndex: json['seasonIndex'] as int? ?? 0,
      year: json['year'] as int? ?? 1,
      bag: Map<String, int>.from(json['bag'] ?? {}),
      items: Map<String, int>.from(json['items'] ?? {}),
      inMine: json['inMine'] as bool? ?? false,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'player': player,
        'fields': fields,
        'npcSystem': npcSystem,
        'festivalSystem': festivalSystem,
        'questSystem': questSystem,
        'mineManager': mineManager,
        'gameMinutes': gameMinutes,
        'day': day,
        'seasonIndex': seasonIndex,
        'year': year,
        'bag': bag,
        'items': items,
        'inMine': inMine,
      };
}

/// 存档管理器。
class SaveManager {
  SaveManager._();

  static final SaveManager _instance = SaveManager._();

  factory SaveManager() => _instance;

  late final SharedPreferences _prefs;

  /// 是否已完成初始化。
  bool _initialized = false;

  /// 初始化。
  Future<bool> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      return true;
    } catch (e) {
      print('SaveManager init error: $e');
      return false;
    }
  }

  /// 检查是否已初始化。
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SaveManager not initialized. Call init() first.');
    }
  }

  /// 保存游戏。
  Future<bool> saveGame(GameSaveData data) async {
    _ensureInitialized();

    try {
      final Map<String, dynamic> json = data.toJson();
      json['version'] = saveVersion;
      json['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      final String encoded = jsonEncode(json);
      return await _prefs.setString(SaveKeys.saveData, encoded);
    } catch (e) {
      print('SaveGame error: $e');
      return false;
    }
  }

  /// 加载游戏。
  Future<GameSaveData?> loadGame() async {
    _ensureInitialized();

    try {
      final String? encoded = _prefs.getString(SaveKeys.saveData);
      if (encoded == null) return null;

      final Map<String, dynamic> json = jsonDecode(encoded);

      // 检查版本兼容性
      final int version = json['version'] as int? ?? 0;
      if (version > saveVersion) {
        print('Save version $version is newer than current version $saveVersion');
        return null;
      }

      return GameSaveData.fromJson(json);
    } catch (e) {
      print('LoadGame error: $e');
      return null;
    }
  }

  /// 检查是否有存档。
  bool hasSave() {
    _ensureInitialized();
    return _prefs.containsKey(SaveKeys.saveData);
  }

  /// 删除存档。
  Future<bool> deleteSave() async {
    _ensureInitialized();
    return await _prefs.remove(SaveKeys.saveData);
  }

  /// 获取存档时间戳。
  DateTime? getSaveTimestamp() {
    _ensureInitialized();
    final int? ms = _prefs.getInt(SaveKeys.saveTimestamp);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

/// 游戏存档助手 - 提供便捷的方法来保存和加载游戏状态。
class GameSaveHelper {
  GameSaveHelper._();

  /// 保存完整游戏状态。
  static Future<bool> saveFullGame({
    required Player player,
    required FieldManager fields,
    required NpcSystem npcSystem,
    required FestivalSystem festivalSystem,
    required QuestSystem questSystem,
    required MineManager mineManager,
    required double gameMinutes,
    required int day,
    required int seasonIndex,
    required int year,
    required Map<String, int> bag,
    required Map<String, int> items,
    required bool inMine,
  }) async {
    final saveData = GameSaveData(
      player: <String, dynamic>{'x': player.x, 'y': player.y, 'gold': player.gold, 'stamina': player.stamina, 'maxStamina': player.maxStamina, 'level': player.level, 'exp': player.exp},
      fields: fields.tiles
          .map((FieldTile t) => <String, dynamic>{
        'col': t.col,
        'row': t.row,
        'state': t.state.name,
        'crop': t.crop?.id,
        'plantedAt': t.plantedAt,
        'elapsedHours': t.elapsedHours,
        'overripeHours': t.overripeHours,
        'watered': t.watered,
      })
          .toList(),
      npcSystem: npcSystem.save(),
      festivalSystem: festivalSystem.save(),
      questSystem: questSystem.save(),
      mineManager: <String, dynamic>{
        'currentFloor': mineManager.currentFloor,
        'clearState': <String, dynamic>{for (final e in mineManager.clearState.entries) e.key.toString(): e.value},
      },
      gameMinutes: gameMinutes,
      day: day,
      seasonIndex: seasonIndex,
      year: year,
      bag: bag,
      items: items,
      inMine: inMine,
    );

    return await SaveManager().saveGame(saveData);
  }

  /// 加载完整游戏状态。
  static Future<bool> loadFullGame({
    required Player player,
    required FieldManager fields,
    required NpcSystem npcSystem,
    required FestivalSystem festivalSystem,
    required QuestSystem questSystem,
    required MineManager mineManager,
  }) async {
    final saveData = await SaveManager().loadGame();
    if (saveData == null) return false;

    try {
      // 恢复玩家数据
      player.x = (saveData.player['x'] as num?)?.toDouble() ?? player.x;
      player.y = (saveData.player['y'] as num?)?.toDouble() ?? player.y;
      player.gold = saveData.player['gold'] as int? ?? player.gold;
      player.stamina = saveData.player['stamina'] as int? ?? player.stamina;
      player.maxStamina = saveData.player['maxStamina'] as int? ?? player.maxStamina;
      player.level = saveData.player['level'] as int? ?? player.level;
      player.exp = saveData.player['exp'] as int? ?? player.exp;

      // 恢复田地数据
      for (final Map<String, dynamic> tileData in saveData.fields) {
        final int col = tileData['col'] as int? ?? 0;
        final int row = tileData['row'] as int? ?? 0;
        final FieldTile? tile = fields.tileAt(col, row);
        if (tile == null) continue;

        final String stateStr = tileData['state'] as String? ?? '';
        if (stateStr.isNotEmpty) {
          tile.state = TileState.values.firstWhere(
            (TileState s) => s.name == stateStr,
            orElse: () => TileState.empty,
          );
        }

        final String? cropId = tileData['crop'] as String?;
        if (cropId != null) {
          final Crop? crop = CropsData.byId(cropId);
          if (crop != null) {
            tile.crop = crop;
          }
        }

        tile.plantedAt = tileData['plantedAt'] as int? ?? 0;
        tile.elapsedHours = (tileData['elapsedHours'] as num?)?.toDouble() ?? 0;
        tile.overripeHours = (tileData['overripeHours'] as num?)?.toDouble() ?? 0;
        tile.watered = tileData['watered'] as bool? ?? false;
      }

      // 恢复 NPC 系统
      npcSystem.load(saveData.npcSystem);

      // 恢复祭典系统
      festivalSystem.load(saveData.festivalSystem);

      // 恢复任务系统
      questSystem.load(saveData.questSystem);

      // 恢复矿洞管理器
      final int currentFloor = saveData.mineManager['currentFloor'] as int? ?? 0;
      mineManager.currentFloor = currentFloor;

      return true;
    } catch (e) {
      print('LoadFullGame error: $e');
      return false;
    }
  }
}
