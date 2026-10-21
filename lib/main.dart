import 'package:flutter/material.dart';

import 'game/game_world.dart';

void main() {
  runApp(const FarmGameApp());
}

/// 牧场物语应用根组件。
class FarmGameApp extends StatelessWidget {
  const FarmGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '牧场物语',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF87CEEB),
      ),
      home: const GameWorld(),
    );
  }
}
