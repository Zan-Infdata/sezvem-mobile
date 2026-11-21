import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'companion_window.dart';

/// Moves the overlay window across the screen at a steady speed.
///
/// This controller only owns the window position. It doesn't know which
/// animation the character plays. Positions are the window's top-left corner
/// in physical pixels.
class CompanionMovementController {
  CompanionMovementController({
    required this.window,
    required CompanionWindowLayout layout,
    required TickerProvider vsync,
    this.speed = 180,
    this.padding = 16,
    this.reserve = EdgeInsets.zero,
  }) : _layout = layout,
       x = layout.x,
       y = layout.y {
    _ticker = vsync.createTicker(_onTick);
  }

  final CompanionWindow window;

  /// Walking speed in logical pixels per second.
  final double speed;

  /// Gap in logical pixels kept between the window and the usable screen
  /// edges for [pointForUv].
  final double padding;

  /// Extra logical pixels kept free on each side for [pointForUv], so the
  /// window can grow there without leaving the screen.
  final EdgeInsets reserve;

  CompanionWindowLayout _layout;
  late final Ticker _ticker;
  double x;
  double y;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Duration _duration = Duration.zero;
  Completer<void>? _walk;

  /// Resting x position near the right edge of the usable screen area.
  double get restX => _layout.screenRight - _layout.width - 8 * _layout.density;

  /// The x position just past the left or right screen edge.
  double offscreenX({required bool left}) =>
      left ? _layout.screenLeft - _layout.width : _layout.screenRight;

  /// Converts a point in 0 to 1 screen coordinates to a window position.
  ///
  /// (0, 0) puts the window in the top-left corner and (1, 1) in the
  /// bottom-right corner of the usable screen area, inset by [padding] plus
  /// [reserve]. The same coordinates give the same relative spot on any
  /// screen size. On a screen too small for the range, the window goes to the
  /// top-left limit.
  Offset pointForUv(Offset uv) {
    final density = _layout.density;
    final left = _layout.screenLeft + (padding + reserve.left) * density;
    final top = _layout.screenTop + (padding + reserve.top) * density;
    final right = _layout.screenRight - (padding + reserve.right) * density;
    final bottom = _layout.screenBottom - (padding + reserve.bottom) * density;
    final width = right - _layout.width - left;
    final height = bottom - _layout.height - top;
    return Offset(
      left + uv.dx.clamp(0.0, 1.0) * (width > 0 ? width : 0),
      top + uv.dy.clamp(0.0, 1.0) * (height > 0 ? height : 0),
    );
  }

  void updateLayout(CompanionWindowLayout layout) {
    _layout = layout;
    if (!_ticker.isActive) {
      x = layout.x;
      y = layout.y;
    }
  }

  /// Walks horizontally to [targetX]. A new walk replaces the current one.
  /// [speed] overrides the default walking speed for this walk.
  Future<void> walkTo(double targetX, {double? speed}) =>
      walkToPoint(Offset(targetX, y), speed: speed);

  /// Walks in a straight line to [target]. A new walk replaces the current
  /// one. [speed] overrides the default walking speed for this walk.
  Future<void> walkToPoint(Offset target, {double? speed}) {
    _stop();
    final pixelsPerSecond = (speed ?? this.speed) * _layout.density;
    final distance = (target - Offset(x, y)).distance;
    if (distance < 1 || pixelsPerSecond <= 0) {
      x = target.dx;
      y = target.dy;
      unawaited(window.moveTo(x, y));
      return Future.value();
    }
    _from = Offset(x, y);
    _to = target;
    _duration = Duration(
      microseconds: (distance / pixelsPerSecond * 1e6).round(),
    );
    final walk = _walk = Completer<void>();
    _ticker.start();
    return walk.future;
  }

  void _onTick(Duration elapsed) {
    final t = (elapsed.inMicroseconds / _duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final point = Offset.lerp(_from, _to, t)!;
    x = point.dx;
    y = point.dy;
    unawaited(window.moveTo(x, y));
    if (t >= 1) _stop();
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    final walk = _walk;
    _walk = null;
    if (walk != null && !walk.isCompleted) walk.complete();
  }

  void dispose() {
    _stop();
    _ticker.dispose();
  }
}
