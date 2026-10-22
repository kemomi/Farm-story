/// 粒子特效系统
///
/// 在游戏 Canvas 上绘制粒子特效：收获金光、播种尘土、锄地飞溅、
/// 金币飞舞、升级星爆、水花、作物成熟闪光等。
///
/// 所有粒子在世界坐标系中运动，由 [GameWorldState] 每帧调用 [update]
/// 推进，再由绘制器调用 [draw] 渲染到 Canvas。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 粒子绘制类型。
enum _ParticleKind {
  /// 发光火花（收获金光）。
  sparkle,
  /// 尘土团（锄地/播种）。
  dust,
  /// 飞行金币。
  coin,
  /// 星星（升级）。
  star,
  /// 飘落绿叶。
  leaf,
  /// 水滴。
  drop,
  /// 成熟微光（持续脉冲）。
  glow,
}

/// 单个粒子。
class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.size,
    required this.kind,
    this.gravity = 0,
    this.spin = 0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final Color color;
  final double size;
  final _ParticleKind kind;
  final double gravity;
  final double spin;
  double angle = 0;
}

/// 特效系统：管理粒子生命周期与绘制。
class EffectSystem {
  EffectSystem();

  final math.Random _rng = math.Random();
  final List<_Particle> _particles = <_Particle>[];

  /// 是否有活跃粒子。
  bool get hasParticles => _particles.isNotEmpty;

  /// 活跃粒子数。
  int get count => _particles.length;

  /// 收获特效：金色火花 + 绿叶飞溅。
  void harvest(double x, double y, {int color = 0xFFFFE066}) {
    for (int i = 0; i < 14; i++) {
      final double a = _rng.nextDouble() * math.pi * 2;
      final double sp = 40 + _rng.nextDouble() * 90;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - 70,
        life: 0.5 + _rng.nextDouble() * 0.5,
        maxLife: 1.0,
        color: Color(color),
        size: 2 + _rng.nextDouble() * 3,
        kind: _ParticleKind.sparkle,
        gravity: 220,
      ));
    }
    for (int i = 0; i < 7; i++) {
      final double a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi;
      final double sp = 30 + _rng.nextDouble() * 60;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        life: 0.5 + _rng.nextDouble() * 0.4,
        maxLife: 0.9,
        color: const Color(0xFF6FBF4A),
        size: 3 + _rng.nextDouble() * 2,
        kind: _ParticleKind.leaf,
        gravity: 140,
        spin: (_rng.nextDouble() - 0.5) * 8,
      ));
    }
  }

  /// 播种特效：尘土 + 种子微粒。
  void plant(double x, double y) {
    for (int i = 0; i < 8; i++) {
      final double a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 0.8;
      final double sp = 20 + _rng.nextDouble() * 40;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        life: 0.3 + _rng.nextDouble() * 0.3,
        maxLife: 0.6,
        color: const Color(0xFF8B6F47),
        size: 2 + _rng.nextDouble() * 2,
        kind: _ParticleKind.dust,
        gravity: 180,
      ));
    }
  }

  /// 锄地特效：尘土飞溅。
  void hoe(double x, double y) {
    for (int i = 0; i < 10; i++) {
      final double a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi;
      final double sp = 30 + _rng.nextDouble() * 50;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - 20,
        life: 0.25 + _rng.nextDouble() * 0.25,
        maxLife: 0.5,
        color: const Color(0xFFA08060),
        size: 2 + _rng.nextDouble() * 2.5,
        kind: _ParticleKind.dust,
        gravity: 200,
      ));
    }
  }

  /// 金币飞舞特效。
  void coin(double x, double y) {
    for (int i = 0; i < 6; i++) {
      _particles.add(_Particle(
        x: x + (_rng.nextDouble() - 0.5) * 10,
        y: y,
        vx: (_rng.nextDouble() - 0.5) * 40,
        vy: -60 - _rng.nextDouble() * 50,
        life: 0.6 + _rng.nextDouble() * 0.3,
        maxLife: 0.9,
        color: const Color(0xFFFFE066),
        size: 4 + _rng.nextDouble() * 2,
        kind: _ParticleKind.coin,
        gravity: 160,
        spin: (_rng.nextDouble() - 0.5) * 10,
      ));
    }
  }

  /// 升级星爆特效。
  void levelUp(double x, double y) {
    for (int i = 0; i < 18; i++) {
      final double a = (i / 18) * math.pi * 2;
      final double sp = 60 + _rng.nextDouble() * 60;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        life: 0.7 + _rng.nextDouble() * 0.4,
        maxLife: 1.1,
        color: const Color(0xFFFFE066),
        size: 3 + _rng.nextDouble() * 3,
        kind: _ParticleKind.star,
        gravity: 60,
        spin: 4,
      ));
    }
  }

  /// 水花特效。
  void waterSplash(double x, double y) {
    for (int i = 0; i < 12; i++) {
      final double a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 0.7;
      final double sp = 30 + _rng.nextDouble() * 60;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        life: 0.3 + _rng.nextDouble() * 0.3,
        maxLife: 0.6,
        color: const Color(0xFF7BD3F0),
        size: 2 + _rng.nextDouble() * 2,
        kind: _ParticleKind.drop,
        gravity: 200,
      ));
    }
  }

  /// 钓鱼水花特效（更大范围）。
  void fishSplash(double x, double y) {
    for (int i = 0; i < 16; i++) {
      final double a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi;
      final double sp = 40 + _rng.nextDouble() * 80;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - 30,
        life: 0.4 + _rng.nextDouble() * 0.4,
        maxLife: 0.8,
        color: const Color(0xFF62B6E8),
        size: 2.5 + _rng.nextDouble() * 2.5,
        kind: _ParticleKind.drop,
        gravity: 180,
      ));
    }
  }

  /// 作物成熟微光（柔和脉冲）。
  void matureGlow(double x, double y, int color) {
    for (int i = 0; i < 5; i++) {
      final double a = (i / 5) * math.pi * 2;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: math.cos(a) * 15,
        vy: math.sin(a) * 15 - 10,
        life: 0.8,
        maxLife: 0.8,
        color: Color(color),
        size: 2,
        kind: _ParticleKind.glow,
      ));
    }
  }

  /// 每帧更新：推进粒子运动与生命。
  void update(double dt) {
    if (dt <= 0) return;
    for (int i = _particles.length - 1; i >= 0; i--) {
      final _Particle p = _particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.angle += p.spin * dt;
    }
  }

  /// 将所有粒子绘制到 Canvas（世界坐标系）。
  void draw(Canvas canvas) {
    for (final _Particle p in _particles) {
      final double t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final int alpha = (t * 255).round();
      final Paint paint = Paint()..color = _withAlpha(p.color, alpha);

      switch (p.kind) {
        case _ParticleKind.sparkle:
          canvas.drawCircle(Offset(p.x, p.y), p.size * t, paint);
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * 2 * t,
            Paint()..color = _withAlpha(p.color, (alpha * 0.3).round()),
          );
          break;
        case _ParticleKind.dust:
          canvas.drawCircle(Offset(p.x, p.y), p.size * (1.2 - t * 0.4), paint);
          break;
        case _ParticleKind.coin:
          final double sx = p.size * math.cos(p.angle).abs();
          canvas.drawOval(
            Rect.fromCenter(center: Offset(p.x, p.y), width: sx * 2, height: p.size * 2),
            paint,
          );
          break;
        case _ParticleKind.star:
          _drawStar(canvas, p.x, p.y, p.size * (0.5 + t * 0.5), p.angle, paint);
          break;
        case _ParticleKind.leaf:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size),
            paint,
          );
          canvas.restore();
          break;
        case _ParticleKind.drop:
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;
        case _ParticleKind.glow:
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size + (1 - t) * 6,
            Paint()..color = _withAlpha(p.color, (alpha * 0.5).round()),
          );
          break;
      }
    }
  }

  /// 绘制四角星。
  void _drawStar(Canvas canvas, double cx, double cy, double r, double angle, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      final double a = angle + i * math.pi / 2;
      final double a2 = a + math.pi / 4;
      if (i == 0) {
        path.moveTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
      } else {
        path.lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
      }
      path.lineTo(cx + math.cos(a2) * r * 0.4, cy + math.sin(a2) * r * 0.4);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// 清除全部粒子。
  void clear() => _particles.clear();

  /// 给颜色设置透明度。
  static Color _withAlpha(Color c, int alpha) {
    final int a = alpha.clamp(0, 255);
    return Color((a << 24) | (c.value & 0x00FFFFFF));
  }
}
