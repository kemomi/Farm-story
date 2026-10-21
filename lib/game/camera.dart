/// 相机系统
///
/// 负责世界坐标与屏幕坐标的相互转换、跟随玩家、边界限制。
/// 横版视角下相机主要沿 X 轴滚动，Y 轴在地图高度超出视口时同样跟随。
library;

import 'dart:math' as math;

/// 相机。
class Camera {
  Camera({
    this.viewportWidth = 800,
    this.viewportHeight = 480,
    this.worldWidth = 8000,
    this.worldHeight = 900,
  });

  /// 视口宽度（屏幕像素）。
  double viewportWidth;

  /// 视口高度（屏幕像素）。
  double viewportHeight;

  /// 世界总宽度。
  double worldWidth;

  /// 世界总高度。
  double worldHeight;

  /// 相机左上角的世界坐标 X。
  double x = 0;

  /// 相机左上角的世界坐标 Y。
  double y = 0;

  /// 平滑跟随系数（0~1，越大越快）。
  double followSmooth = 0.12;

  /// 是否启用平滑跟随；关闭后为瞬时对齐。
  bool smoothing = true;

  /// 最大移动速度（像素/秒），用于限制平滑跟随的漂移速度。
  double maxFollowSpeed = 1600;

  /// 缩放倍率（1.0 为原始大小）。
  double zoom = 1.0;

  // ------------------------------------------------------------------ 更新

  /// 设置视口尺寸（屏幕尺寸变化时调用）。
  void setViewport(double w, double h) {
    viewportWidth = math.max(1, w);
    viewportHeight = math.max(1, h);
  }

  /// 设置世界尺寸。
  void setWorldSize(double w, double h) {
    worldWidth = math.max(1, w);
    worldHeight = math.max(1, h);
    clampToBounds();
  }

  /// 跟随目标点（通常是玩家中心），[dt] 为帧间隔秒数。
  void follow(double targetX, double targetY, {double dt = 0}) {
    final double desiredX = targetX - viewportWidth / (2 * zoom);
    final double desiredY = targetY - viewportHeight / (2 * zoom);

    if (!smoothing || dt <= 0) {
      x = desiredX;
      y = desiredY;
    } else {
      final double t = math.max(0.0, math.min(1.0, followSmooth * dt * 60));
      double dx = (desiredX - x) * t;
      double dy = (desiredY - y) * t;
      final double limit = maxFollowSpeed * dt;
      dx = dx.clamp(-limit, limit).toDouble();
      dy = dy.clamp(-limit, limit).toDouble();
      x += dx;
      y += dy;
    }
    clampToBounds();
  }

  /// 立即对准目标点（无动画）。
  void snapTo(double targetX, double targetY) {
    x = targetX - viewportWidth / (2 * zoom);
    y = targetY - viewportHeight / (2 * zoom);
    clampToBounds();
  }

  /// 限制相机不越出世界边界。
  void clampToBounds() {
    final double maxX = math.max(0, worldWidth - viewportWidth / zoom);
    final double maxY = math.max(0, worldHeight - viewportHeight / zoom);
    if (x < 0) x = 0;
    if (x > maxX) x = maxX;
    if (y < 0) y = 0;
    if (y > maxY) y = maxY;
  }

  /// 设置缩放，自动限制在合理范围并重新夹取边界。
  void setZoom(double z) {
    zoom = z.clamp(0.5, 2.0).toDouble();
    clampToBounds();
  }

  // ------------------------------------------------------------------ 坐标转换

  /// 世界坐标 → 屏幕坐标 X。
  double toScreenX(double wx) => (wx - x) * zoom;

  /// 世界坐标 → 屏幕坐标 Y。
  double toScreenY(double wy) => (wy - y) * zoom;

  /// 屏幕坐标 → 世界坐标 X。
  double toWorldX(double sx) => sx / zoom + x;

  /// 屏幕坐标 → 世界坐标 Y。
  double toWorldY(double sy) => sy / zoom + y;

  /// 屏幕点 → 世界点。
  math.Point<double> toWorld(math.Point<double> screen) =>
      math.Point<double>(toWorldX(screen.x), toWorldY(screen.y));

  /// 世界点 → 屏幕点。
  math.Point<double> toScreen(math.Point<double> world) =>
      math.Point<double>(toScreenX(world.x), toScreenY(world.y));

  /// 某个世界坐标是否落在可视范围内（含 [margin] 余量，用于裁剪绘制）。
  bool isVisible(double wx, double wy, {double margin = 64}) =>
      wx >= x - margin &&
      wx <= x + viewportWidth / zoom + margin &&
      wy >= y - margin &&
      wy <= y + viewportHeight / zoom + margin;

  /// 某个世界矩形是否与视口相交（用于批量裁剪）。
  bool rectVisible(double rx, double ry, double rw, double rh) =>
      rx + rw >= x && rx <= x + viewportWidth / zoom &&
      ry + rh >= y && ry <= y + viewportHeight / zoom;

  /// 当前可视的世界范围。
  math.Rectangle<double> get visibleWorld => math.Rectangle<double>(
        x,
        y,
        viewportWidth / zoom,
        viewportHeight / zoom,
      );

  /// 可视范围内起始列索引（用于网格裁剪绘制）。
  int startCol(double cellSize) => math.max(0, (x / cellSize).floor());

  /// 可视范围内结束列索引（不含）。
  int endCol(double cellSize) =>
      math.min(((x + viewportWidth / zoom) / cellSize).ceil(), 1 << 30);

  /// 可视范围内起始行索引。
  int startRow(double cellSize) => math.max(0, (y / cellSize).floor());

  /// 可视范围内结束行索引（不含）。
  int endRow(double cellSize) =>
      math.min(((y + viewportHeight / zoom) / cellSize).ceil(), 1 << 30);

  @override
  String toString() =>
      'Camera(pos=(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}), '
      'viewport=$viewportWidth×$viewportHeight, zoom=$zoom)';
}
