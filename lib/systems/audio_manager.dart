/// 音频管理器
///
/// 使用 just_audio 播放背景音乐和音效。
/// 支持背景音乐循环播放、音效播放、音量控制。
library;

import 'package:just_audio/just_audio.dart';

/// 音频管理器。
class AudioManager {
  AudioManager._();

  static final AudioManager _instance = AudioManager._();

  factory AudioManager() => _instance;

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// 是否启用背景音乐。
  bool bgmEnabled = true;

  /// 是否启用音效。
  bool sfxEnabled = true;

  /// 背景音乐音量（0.0 ~ 1.0）。
  double bgmVolume = 0.5;

  /// 音效音量（0.0 ~ 1.0）。
  double sfxVolume = 0.8;

  /// 初始化音频系统。
  Future<void> init() async {
    try {
      // 设置音量
      await _bgmPlayer.setVolume(bgmVolume);
      await _sfxPlayer.setVolume(sfxVolume);
    } catch (e) {
      print('AudioManager init error: $e');
    }
  }

  /// 播放背景音乐。
  /// [assetPath] 为音频文件路径（如 'assets/audio/bgm.mp3'）。
  Future<void> playBgm(String assetPath) async {
    if (!bgmEnabled) return;

    try {
      await _bgmPlayer.setAsset(assetPath);
      await _bgmPlayer.setVolume(bgmVolume);
      await _bgmPlayer.play();
    } catch (e) {
      print('PlayBgm error: $e');
    }
  }

  /// 停止背景音乐。
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      print('StopBgm error: $e');
    }
  }

  /// 播放音效。
  /// [assetPath] 为音效文件路径。
  Future<void> playSfx(String assetPath) async {
    if (!sfxEnabled) return;

    try {
      await _sfxPlayer.setAsset(assetPath);
      await _sfxPlayer.setVolume(sfxVolume);
      await _sfxPlayer.play();
    } catch (e) {
      print('PlaySfx error: $e');
    }
  }

  /// 设置背景音乐音量。
  Future<void> setBgmVolume(double volume) async {
    bgmVolume = volume.clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(bgmVolume);
  }

  /// 设置音效音量。
  Future<void> setSfxVolume(double volume) async {
    sfxVolume = volume.clamp(0.0, 1.0);
    await _sfxPlayer.setVolume(sfxVolume);
  }

  /// 切换背景音乐开关。
  Future<void> toggleBgm() async {
    bgmEnabled = !bgmEnabled;
    if (!bgmEnabled) {
      await stopBgm();
    }
  }

  /// 切换音效开关。
  void toggleSfx() {
    sfxEnabled = !sfxEnabled;
  }

  /// 释放音频资源。
  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}

/// 音效类型。
enum SfxType {
  /// 锄地。
  hoe,

  /// 播种。
  plant,

  /// 收获。
  harvest,

  /// 浇水。
  water,

  /// 钓鱼。
  fish,

  /// 战斗。
  battle,

  /// 采矿。
  mine,

  /// 点击。
  tap,
}

/// 音效管理器 - 提供便捷的方法来播放游戏音效。
class GameSfx {
  GameSfx._();

  static final AudioManager _audio = AudioManager();

  /// 播放指定音效。
  static void play(SfxType type) {
    // 音效文件路径映射
    final Map<SfxType, String> sfxPaths = <SfxType, String>{
      SfxType.hoe: 'assets/sfx/hoe.mp3',
      SfxType.plant: 'assets/sfx/plant.mp3',
      SfxType.harvest: 'assets/sfx/harvest.mp3',
      SfxType.water: 'assets/sfx/water.mp3',
      SfxType.fish: 'assets/sfx/fish.mp3',
      SfxType.battle: 'assets/sfx/battle.mp3',
      SfxType.mine: 'assets/sfx/mine.mp3',
      SfxType.tap: 'assets/sfx/tap.mp3',
    };

    final String? path = sfxPaths[type];
    if (path != null) {
      _audio.playSfx(path);
    }
  }

  /// 播放锄地音效。
  static void hoe() => play(SfxType.hoe);

  /// 播放播种音效。
  static void plant() => play(SfxType.plant);

  /// 播放收获音效。
  static void harvest() => play(SfxType.harvest);

  /// 播放浇水音效。
  static void water() => play(SfxType.water);

  /// 播放钓鱼音效。
  static void fish() => play(SfxType.fish);

  /// 播放战斗音效。
  static void battle() => play(SfxType.battle);

  /// 播放采矿音效。
  static void mine() => play(SfxType.mine);

  /// 播放点击音效。
  static void tap() => play(SfxType.tap);
}
