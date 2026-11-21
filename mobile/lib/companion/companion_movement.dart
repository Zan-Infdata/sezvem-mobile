import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'companion_window.dart';

/// Moves the overlay window across the screen at a steady speed.
///
/// This controller only owns the window position. It doesn't know which
/// animation the character plays.
class CompanionMovementController {
  CompanionMovementController({
    required this.window,
    required CompanionWindowLayout layout,
    required TickerProvider vsync,
    this.speed = 180,
  }) : _layout = layout,
       x = layout.x,
       y = layout.y {
    _ticker = vsync.createTicker(_onTick);
  }

  final CompanionWindow window;

  /// Walking speed in logical pixels per second.
  final double speed;

  CompanionWindowLayout _layout;
  late final Ticker _ticker;
  double x;
  double y;
  double _fromX = 0;
  double _toX = 0;
  Duration _duration = Duration.zero;
  Completer<void>? _walk;

  /// Resting x position near the right edge of the usable screen area.
  double get restX => _layout.screenRight - _layout.width - 8 * _layout.density;

  /// The x position just past the left or right screen edge.
  double offscreenX({required bool left}) =>
      left ? _layout.screenLeft - _layout.width : _layout.screenRight;

  void updateLayout(CompanionWindowLayout layout) {
    _layout = layout;
    if (!_ticker.isActive) {
      x = layout.x;
      y = layout.y;
    }
  }

  /// Walks horizontally to [targetX]. A new walk replaces the current one.
  /// [speed] overrides the default walking speed for this walk.
  Future<void> walkTo(double targetX, {double? speed}) {
    _stop();
    final pixelsPerSecond = (speed ?? this.speed) * _layout.density;
    final distance = (targetX - x).abs();
    if (distance < 1 || pixelsPerSecond <= 0) {
      x = targetX;
      unawaited(window.moveTo(x, y));
      return Future.value();
    }
    _fromX = x;
    _toX = targetX;
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
    x = _fromX + (_toX - _fromX) * t;
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
