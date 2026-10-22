/// 音频系统
///
/// 管理背景音乐（BGM）与音效（SFX）的播放、开关与资源释放。
/// 使用 [audioplayers](https://pub.dev/packages/audioplayers) 包，
/// BGM 循环播放，SFX 通过 4 路播放池实现叠加不中断。
///
/// 所有方法均吞掉异常——音频加载失败绝不中断游戏主循环。
library;

import 'package:audioplayers/audioplayers.dart';

/// 音效名称 → 资源路径映射。
const Map<String, String> _kSfxPaths = <String, String>{
  'harvest': 'audio/sfx_harvest.wav',
  'plant': 'audio/sfx_plant.wav',
  'hoe': 'audio/sfx_hoe.wav',
  'coin': 'audio/sfx_coin.wav',
  'levelup': 'audio/sfx_levelup.wav',
  'water': 'audio/sfx_water.wav',
  'fish': 'audio/sfx_fish.wav',
  'click': 'audio/sfx_click.wav',
  'sleep': 'audio/sfx_sleep.wav',
};

/// BGM 资源路径。
const String _kBgmPath = 'audio/bgm_farm.wav';

/// 音频系统：管理 BGM 与 SFX。
class AudioSystem {
  AudioSystem();

  /// BGM 播放器。
  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// SFX 播放池（4 路，轮转使用以支持叠加）。
  final List<AudioPlayer> _sfxPool = List<AudioPlayer>.generate(
    4,
    (_) => AudioPlayer(),
  );

  /// 当前 SFX 池索引。
  int _sfxIndex = 0;

  /// BGM 是否开启。
  bool _bgmEnabled = true;

  /// 音效是否开启。
  bool _sfxEnabled = true;

  /// 是否已初始化。
  bool _initialized = false;

  /// BGM 开关状态。
  bool get bgmEnabled => _bgmEnabled;

  /// 音效开关状态。
  bool get sfxEnabled => _sfxEnabled;

  /// 初始化并开始播放 BGM（幂等）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.3);
      if (_bgmEnabled) {
        await _bgmPlayer.play(AssetSource(_kBgmPath));
      }
    } catch (_) {
      // 音频初始化失败不中断游戏。
    }
  }

  /// 播放一个音效（按名称查找）。未初始化或已静音时直接返回。
  Future<void> playSfx(String name) async {
    if (!_sfxEnabled || !_initialized) return;
    final String? path = _kSfxPaths[name];
    if (path == null) return;
    try {
      final AudioPlayer p = _sfxPool[_sfxIndex];
      _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
      await p.stop();
      await p.setVolume(0.5);
      await p.play(AssetSource(path));
    } catch (_) {
      // 忽略播放错误。
    }
  }

  /// 切换 BGM 开关，返回切换后状态。
  Future<bool> toggleBgm() async {
    _bgmEnabled = !_bgmEnabled;
    try {
      if (_bgmEnabled) {
        await _bgmPlayer.play(AssetSource(_kBgmPath));
      } else {
        await _bgmPlayer.pause();
      }
    } catch (_) {}
    return _bgmEnabled;
  }

  /// 切换音效开关，返回切换后状态。
  bool toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
    return _sfxEnabled;
  }

  /// 释放全部音频资源。
  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
      for (final AudioPlayer p in _sfxPool) {
        await p.dispose();
      }
    } catch (_) {}
  }
}
