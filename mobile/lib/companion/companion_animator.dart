import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'companion_state.dart';

/// Decides which animation the character plays.
///
/// Actions call its methods to play one-shot clips or change the companion's
/// state and mood. [CompanionCharacter] reads the values it exposes. Window
/// position is handled separately by the movement controller.
class CompanionAnimator extends ChangeNotifier {
  CompanionAnimator({required TickerProvider vsync})
    : _bounce = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 320),
      ),
      _flip = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 750),
      ),
      _sadness = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 250),
      ),
      _scale = AnimationController(
        vsync: vsync,
        value: 1,
        lowerBound: 1,
        upperBound: maxScale,
      ) {
    for (final controller in [_bounce, _flip, _sadness, _scale]) {
      controller.addListener(notifyListeners);
    }
  }

  /// The largest size the character can grow to, relative to its normal size.
  static const maxScale = 2.0;

  final AnimationController _bounce;
  final AnimationController _flip;
  final AnimationController _sadness;
  final AnimationController _scale;
  var _state = CompanionState.hidden;
  var _facing = CompanionFacing.left;

  CompanionState get state => _state;
  set state(CompanionState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  CompanionFacing get facing => _facing;
  set facing(CompanionFacing value) {
    if (_facing == value) return;
    _facing = value;
    notifyListeners();
  }

  /// Squash from a bounce, 0 none to 1 fully squashed.
  double get squash => math.sin(_bounce.value * math.pi);

  /// Backflip rotation in radians.
  double get flipAngle => Curves.easeInOut.transform(_flip.value) * 2 * math.pi;

  /// Backflip jump height, 0 on the ground to 1 at the top.
  double get jump => math.sin(_flip.value * math.pi);

  /// Sad expression, 0 normal to 1 fully sad.
  double get sadness => _sadness.value;

  /// Size relative to normal, from 1 to [maxScale].
  double get scale => _scale.value;

  /// A quick squash and stretch.
  Future<void> bounce() => _settle(_bounce.forward(from: 0));

  /// Jumps and spins backwards once. Needs about 64 logical pixels of room
  /// above the character.
  Future<void> backflip() => _settle(_flip.forward(from: 0));

  Future<void> setMood(CompanionMood mood) => switch (mood) {
    CompanionMood.sad => _settle(_sadness.forward()),
    CompanionMood.normal => _settle(_sadness.reverse()),
  };

  /// Grows toward [target] over [duration]. Completes early if [deflate]
  /// interrupts it.
  Future<void> inflateTo(double target, Duration duration) {
    target = target.clamp(1.0, maxScale);
    if (target <= _scale.value) return Future.value();
    final remaining = (target - _scale.value) / (target - 1);
    return _settle(
      _scale.animateTo(
        target,
        duration: duration * remaining.clamp(0, 1),
        curve: Curves.easeOut,
      ),
    );
  }

  /// Shrinks back to the normal size.
  Future<void> deflate() => _settle(
    _scale.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeIn,
    ),
  );

  /// Completes when the clip ends, including when another clip interrupts it
  /// or the animator is disposed. A plain [TickerFuture] never completes then.
  static Future<void> _settle(TickerFuture clip) =>
      clip.orCancel.then<void>((_) {}, onError: (Object _) {});

  @override
  void dispose() {
    for (final controller in [_bounce, _flip, _sadness, _scale]) {
      controller.dispose();
    }
    super.dispose();
  }
}
