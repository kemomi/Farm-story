/// 游戏引导系统
///
/// 提供新手玩家引导，包括基础操作说明、游戏目标、系统介绍。
library;

import 'package:flutter/material.dart';

/// 引导步骤。
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    this.imageAsset,
    this.action,
  });

  /// 步骤 ID。
  final String id;

  /// 步骤标题。
  final String title;

  /// 步骤描述。
  final String description;

  /// 图片资源路径（可选）。
  final String? imageAsset;

  /// 关联的操作（可选）。
  final String? action;
}

/// 游戏引导数据。
class GameTutorial {
  GameTutorial._();

  /// 新手引导步骤。
  static const List<TutorialStep> beginnerSteps = <TutorialStep>[
    TutorialStep(
      id: 'move',
      title: '移动',
      description: '点击地面即可移动到目标位置。',
      action: '点击地面',
    ),
    TutorialStep(
      id: 'hoe',
      title: '锄地',
      description: '选择「锄地」工具，点击空地开垦土地。',
      action: '点击锄地按钮',
    ),
    TutorialStep(
      id: 'plant',
      title: '播种',
      description: '选择「种子商店」购买种子，选择「播种」工具，点击已开垦的土地播种。',
      action: '点击播种按钮',
    ),
    TutorialStep(
      id: 'grow',
      title: '生长',
      description: '作物需要时间生长，可以点击「浇水」加速生长。',
      action: '点击浇水按钮',
    ),
    TutorialStep(
      id: 'harvest',
      title: '收获',
      description: '作物成熟后点击「收获」获得金币。',
      action: '点击收获',
    ),
    TutorialStep(
      id: 'sell',
      title: '出售',
      description: '在「背包」中可以出售作物换取金币。',
      action: '打开背包',
    ),
  ];

  /// 高级引导步骤。
  static const List<TutorialStep> advancedSteps = <TutorialStep>[
    TutorialStep(
      id: 'npc',
      title: 'NPC 交互',
      description: '与村民对话可以增加好感度，送礼可以更快提升好感。',
    ),
    TutorialStep(
      id: 'quest',
      title: '任务系统',
      description: '完成任务可以获得金币、经验和物品奖励。',
    ),
    TutorialStep(
      id: 'festival',
      title: '祭典',
      description: '每个季节都有祭典，参加祭典可以获得丰厚奖励。',
    ),
    TutorialStep(
      id: 'mine',
      title: '矿洞',
      description: '进入矿洞可以采集矿石、击败怪物，获得稀有物品。',
    ),
    TutorialStep(
      id: 'fish',
      title: '钓鱼',
      description: '站在水边使用「钓鱼」工具可以钓到鱼。',
    ),
  ];
}

/// 引导对话框。
class TutorialDialog extends StatelessWidget {
  const TutorialDialog({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  /// 引导步骤列表。
  final List<TutorialStep> steps;

  /// 当前步骤索引。
  final int currentIndex;

  /// 下一步回调。
  final VoidCallback onNext;

  /// 上一步回调。
  final VoidCallback onPrev;

  /// 关闭回调。
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TutorialStep step = steps[currentIndex];

    return AlertDialog(
      backgroundColor: const Color(0xF5243B24),
      title: Text(
        '${currentIndex + 1}/${steps.length} ${step.title}',
        style: const TextStyle(color: Color(0xFFFFE066), fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (step.imageAsset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Image.asset(
                  step.imageAsset!,
                  height: 120,
                  fit: BoxFit.fitWidth,
                ),
              ),
            Text(
              step.description,
              style: const TextStyle(color: Color(0xEEFFFFFF), fontSize: 14, height: 1.5),
            ),
            if (step.action != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x339BE36B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.touch_app, size: 16, color: Color(0xFF9BE36B)),
                    const SizedBox(width: 8),
                    Text(
                      step.action!,
                      style: const TextStyle(color: Color(0xFF9BE36B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        if (currentIndex > 0)
          TextButton(
            onPressed: onPrev,
            child: const Text('上一步', style: TextStyle(color: Colors.white)),
          ),
        if (currentIndex < steps.length - 1)
          TextButton(
            onPressed: onNext,
            child: const Text('下一步', style: TextStyle(color: Colors.white)),
          ),
        TextButton(
          onClose,
          child: Text(
            currentIndex == steps.length - 1 ? '完成' : '关闭',
            style: const TextStyle(color: Color(0xFF9BE36B)),
          ),
        ),
      ],
    );
  }
}

/// 游戏帮助面板。
class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xF5243B24),
      title: const Text(
        '游戏帮助',
        style: TextStyle(color: Color(0xFFFFE066), fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '基础操作',
              style: TextStyle(color: Color(0xFF9BE36B), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildHelpItem('点击地面', '移动到目标位置'),
            _buildHelpItem('锄地工具', '开垦空地，可以播种'),
            _buildHelpItem('播种工具', '在已开垦的土地上播种'),
            _buildHelpItem('浇水工具', '加速作物生长'),
            _buildHelpItem('收获', '成熟作物直接收获'),
            const SizedBox(height: 12),
            const Text(
              '游戏目标',
              style: TextStyle(color: Color(0xFF9BE36B), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 开垦土地，种植作物，收获金币',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 与村民互动，提升好感度',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 完成任务，获得奖励',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 探索矿洞，收集稀有物品',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '提示',
              style: TextStyle(color: Color(0xFF9BE36B), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 不同季节只能种植对应季节的作物',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 浇水可以加速作物生长',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 成熟作物要及时收获，否则会枯萎',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
            const Text(
              '• 与村民对话每天首次会增加好感度',
              style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭', style: TextStyle(color: Color(0xFF9BE36B))),
        ),
      ],
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('• ', style: TextStyle(color: Color(0xFF9BE36B), fontSize: 13)),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(text: '$title：', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  TextSpan(text: description, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
