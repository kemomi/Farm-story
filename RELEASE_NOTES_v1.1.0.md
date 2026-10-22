# Farm Story v1.1.0 发布说明

## 版本信息
- **版本号**: 1.1.0
- **构建号**: 2
- **发布日期**: 2024-10-22

## 新功能

### 🌱 浇水系统
- 新增「浇水」工具（水壶图标）
- 点击生长中的作物可浇水加速生长
- 浇水消耗 1 点体力
- 浇水后作物显示蓝色进度条

### 💾 存档/读档系统
- 使用 `shared_preferences` 本地存储
- 保存内容：玩家数据、田地状态、NPC 好感度、任务进度、祭典参与记录、游戏时间、背包物品
- UI 新增「保存」和「加载」按钮（右上角）

### 🔊 音效系统
- 集成 `just_audio` 库
- 支持背景音乐（BGM）和音效（SFX）
- 音效类型：锄地、播种、收获、浇水、钓鱼、战斗、采矿、点击
- 音量控制、开关切换

### 📚 游戏引导
- 新手引导步骤：移动、锄地、播种、生长、收获、出售
- 高级引导：NPC 交互、任务系统、祭典、矿洞、钓鱼
- UI 新增「帮助」按钮（右上角）

## 依赖更新

```yaml
dependencies:
  shared_preferences: ^2.2.2  # 新增
  just_audio: ^0.9.37         # 新增
```

## 文件变更

### 新增文件
- `lib/systems/audio_manager.dart` - 音效管理器
- `lib/systems/save_manager.dart` - 存档管理器
- `lib/systems/tutorial_system.dart` - 引导系统

### 修改文件
- `lib/pubspec.yaml` - 添加依赖和 assets
- `lib/ui/bottom_bar.dart` - 添加浇水工具
- `lib/game/game_world.dart` - 集成所有新功能

## 构建发布包

### Android APK

```bash
# 在本地环境执行
cd farm-story
flutter pub get
flutter build apk --release
```

生成的 APK 路径：
- `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA

```bash
# 在 macOS 环境执行
cd farm-story
flutter pub get
flutter build ios --release
```

生成的 IPA 路径：
- `build/ios/Release-iphoneos/Runner.app`

## 后续版本计划

### v1.2.0
- [ ] 畜牧系统（养鸡、养牛、养羊）
- [ ] 烹饪系统
- [ ] 温室建筑

### v1.3.0
- [ ] 联机功能
- [ ] 更多 NPC 剧情
- [ ] 季节活动

## 已知问题

1. 音效文件需要手动添加到 `assets/sfx/` 目录
2. 背景音乐文件需要手动添加到 `assets/audio/` 目录

## 贡献者

- Farm Game Developer

---

**GitHub 仓库**: https://github.com/kemomi/Farm-story
**分支**: feature/improvements
