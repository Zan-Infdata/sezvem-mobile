import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'companion_overlay.dart';

/// Test driver that controls the companion from the main app while it is in
/// the background.
///
/// Every [minDelay] to [maxDelay], picked uniformly, sends a visible
/// companion to a random point in 0 to 1 screen coordinates.
/// Monitoring alerts decide when to summon a hidden companion.
class CompanionWanderTest {
  CompanionWanderTest({
    required this.companion,
    math.Random? random,
    this.minDelay = const Duration(seconds: 4),
    this.maxDelay = const Duration(seconds: 8),
  }) : _random = random ?? math.Random();

  final CompanionOverlay companion;
  final math.Random _random;

  final Duration minDelay;
  final Duration maxDelay;

  Timer? _timer;

  bool get isRunning => _timer != null;

  void start() {
    if (isRunning) return;
    _timer = Timer(nextDelay(), _step);
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

  Future<void> _step() async {
    final timer = _timer;
    try {
      if (await companion.hasPermission() && await companion.isShowing()) {
        // A busy companion declines the move. The next step tries again.
        if (identical(_timer, timer)) await companion.moveTo(nextPoint());
      }
    } on PlatformException {
      // Try the next move if the window was temporarily unavailable.
    } on MissingPluginException {
      // The overlay is available on Android only.
    } finally {
      if (identical(_timer, timer)) {
        _timer = Timer(nextDelay(), _step);
      }
    }
  }
}
