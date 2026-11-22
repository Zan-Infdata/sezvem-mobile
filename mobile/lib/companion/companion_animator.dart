import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'companion_state.dart';
import 'styles/companion_style.dart';

/// Decides which animation the character plays.
///
/// Actions call its methods to play one-shot clips or change the companion's
/// state and mood. [CompanionCharacter] turns the values it exposes into a
/// [CompanionPose] for the selected style. Window position is handled
/// separately by the movement controller.
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
      ),
      _emote = AnimationController(vsync: vsync) {
    for (final controller in [_bounce, _flip, _sadness, _scale, _emote]) {
      controller.addListener(notifyListeners);
    }
  }

  /// The largest size the character can grow to, relative to its normal size.
  static const maxScale = CompanionStyle.maxInflate;

  final AnimationController _bounce;
  final AnimationController _flip;
  final AnimationController _sadness;
  final AnimationController _scale;
  final AnimationController _emote;
  CompanionEmotion? _emotion;
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

  /// Bounce progress from 0 to 1.
  double get bounceProgress => _bounce.value;

  /// Backflip progress from 0 to 1.
  double get backflipProgress => _flip.value;

  /// Sad expression, 0 normal to 1 fully sad.
  double get sadness => _sadness.value;

  /// Size relative to normal, from 1 to [maxScale].
  double get scale => _scale.value;

  /// The emotion playing, or null for none.
  CompanionEmotion? get emotion => _emotion;

  /// How strongly [emotion] shows, from 0 to 1. It eases in over
  /// [emotionRise] and out over [emotionFall].
  double get emotionAmount {
    if (_emotion == null) return 0;
    final elapsed = emotionTime;
    final total = _emotionSeconds(_emote.duration);
    final rising = elapsed / _emotionSeconds(emotionRise);
    final falling = (total - elapsed) / _emotionSeconds(emotionFall);
    return Curves.easeOut.transform(math.min(rising, falling).clamp(0.0, 1.0));
  }

  /// Seconds since [emotion] started.
  double get emotionTime =>
      _emotion == null ? 0 : _emote.value * _emotionSeconds(_emote.duration);

  static const emotionRise = Duration(milliseconds: 180);
  static const emotionFall = Duration(milliseconds: 300);

  /// How long each emotion plays by default.
  static Duration emotionDuration(CompanionEmotion emotion) =>
      switch (emotion) {
        CompanionEmotion.surprised => const Duration(milliseconds: 1400),
        CompanionEmotion.laughing => const Duration(milliseconds: 1800),
        CompanionEmotion.scared => const Duration(milliseconds: 1800),
        CompanionEmotion.confused => const Duration(milliseconds: 2000),
        CompanionEmotion.happy => const Duration(milliseconds: 1600),
      };

  static double _emotionSeconds(Duration? duration) =>
      (duration?.inMicroseconds ?? 1) / Duration.microsecondsPerSecond;

  /// Shows [emotion] for [duration], or its [emotionDuration], then returns
  /// to the current mood. A new emotion replaces one that is playing.
  Future<void> emote(CompanionEmotion emotion, {Duration? duration}) {
    _emotion = emotion;
    _emote.duration = duration ?? emotionDuration(emotion);
    final clip = _emote.forward(from: 0);
    return _settle(clip).then((_) {
      // A later emotion may have taken over meanwhile.
      if (_emotion == emotion && !_emote.isAnimating) {
        _emotion = null;
        notifyListeners();
      }
    });
  }

  /// A quick squash and stretch.
  Future<void> bounce() => _settle(_bounce.forward(from: 0));

  /// Jumps and spins backwards once. Run it with the window at
  /// [CompanionStyle.backflipSize].
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
    for (final controller in [_bounce, _flip, _sadness, _scale, _emote]) {
      controller.dispose();
    }
    super.dispose();
  }
}
