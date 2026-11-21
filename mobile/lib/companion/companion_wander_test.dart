import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'companion_overlay.dart';

/// Test driver that controls the companion from the main app while it is in
/// the background.
///
/// Shortly after [start], it brings the companion back if it isn't on screen.
/// Then, every [minDelay] to [maxDelay], picked uniformly, it sends the
/// companion to a random point in 0 to 1 screen coordinates, or brings it back
/// if it was dismissed.
class CompanionWanderTest {
  CompanionWanderTest({
    required this.companion,
    math.Random? random,
    this.firstCheck = const Duration(seconds: 1),
    this.minDelay = const Duration(seconds: 4),
    this.maxDelay = const Duration(seconds: 8),
  }) : _random = random ?? math.Random();

  final CompanionOverlay companion;
  final math.Random _random;

  /// Delay before the first presence check. It lets a companion that was just
  /// shown finish starting.
  final Duration firstCheck;
  final Duration minDelay;
  final Duration maxDelay;

  Timer? _timer;

  bool get isRunning => _timer != null;

  void start() {
    if (isRunning) return;
    _timer = Timer(firstCheck, () => _step(moveIfShowing: false));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// A uniformly random delay from [minDelay] to [maxDelay].
  Duration nextDelay() =>
      minDelay + (maxDelay - minDelay) * _random.nextDouble();

  /// A uniformly random point in 0 to 1 screen coordinates.
  Offset nextPoint() => Offset(_random.nextDouble(), _random.nextDouble());

  Future<void> _step({required bool moveIfShowing}) async {
    try {
      if (!await companion.hasPermission()) return;
      if (!await companion.isShowing()) {
        await companion.show();
      } else if (moveIfShowing) {
        // A busy companion declines the move. The next step tries again.
        await companion.moveTo(nextPoint());
      }
    } on PlatformException {
      // Android can refuse to start the companion right now. Try next time.
    } finally {
      if (_timer != null) {
        _timer = Timer(nextDelay(), () => _step(moveIfShowing: true));
      }
    }
  }
}
