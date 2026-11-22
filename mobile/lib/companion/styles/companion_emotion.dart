import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../companion_state.dart';
import 'companion_style.dart';

/// How an emotion moves the whole body in one frame.
///
/// A style applies it to the whole body, so a new style shows the emotions
/// without its own motion code. Lengths are multiples of the body radius.
/// Squash, stretch, and rotation pivot on the feet.
class EmotionMotion {
  const EmotionMotion({
    this.lift = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  /// The body motion for [pose] when facing [direction], -1 left or 1 right.
  factory EmotionMotion.of(CompanionPose pose, double direction) {
    final t = pose.emotionTime;
    final wave = 2 * math.pi * t;
    var lift = 0.0, scaleX = 1.0, scaleY = 1.0, rotation = 0.0;

    // surprised: a quick startled hop that stretches the body upward.
    final surprised = pose.amountOf(CompanionEmotion.surprised);
    if (surprised > 0) {
      final hop = math.sin((t / 0.45).clamp(0.0, 1.0) * math.pi);
      lift += surprised * hop * 0.3;
      scaleX *= 1 - surprised * 0.06;
      scaleY *= 1 + surprised * 0.08;
    }

    // laughing: fast little bounces with a side-to-side wobble.
    final laughing = pose.amountOf(CompanionEmotion.laughing);
    if (laughing > 0) {
      final shake = math.sin(wave * 1.6).abs();
      lift += laughing * shake * 0.12;
      scaleX *= 1 + laughing * (1 - shake) * 0.06;
      scaleY *= 1 - laughing * (1 - shake) * 0.06;
      rotation += laughing * math.sin(wave * 1.2) * 0.07;
    }

    // scared: shrinks and leans away from where it faces. Styles tremble
    // the eyes.
    final scared = pose.amountOf(CompanionEmotion.scared);
    if (scared > 0) {
      scaleX *= 1 - scared * 0.1;
      scaleY *= 1 - scared * 0.12;
      rotation -= scared * direction * 0.06;
    }

    // confused: tilts its head away from where it faces and sways slowly.
    final confused = pose.amountOf(CompanionEmotion.confused);
    if (confused > 0) {
      rotation -= confused * direction * (0.12 + math.sin(wave * 0.7) * 0.04);
    }

    // happy: a few springy hops.
    final happy = pose.amountOf(CompanionEmotion.happy);
    if (happy > 0) {
      final hop = math.sin(wave * 1.4).abs();
      lift += happy * hop * 0.18;
      scaleY *= 1 + happy * (hop - 0.5) * 0.08;
    }

    return EmotionMotion(
      lift: lift,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
    );
  }

  final double lift;
  final double scaleX;
  final double scaleY;
  final double rotation;

  /// Applies the squash, stretch, and rotation around the feet at `y = feetY`
  /// in the current canvas coordinates. Apply [lift] to the body center before
  /// this.
  void applyAtFeet(Canvas canvas, double feetY) {
    canvas.translate(0, feetY);
    canvas.rotate(rotation);
    canvas.scale(scaleX, scaleY);
    canvas.translate(0, -feetY);
  }
}

/// How far fear shakes the eye on [side], -1 left or 1 right, in multiples
/// of the body radius. Zero unless the companion is scared.
Offset emotionEyeShake(CompanionPose pose, double side) {
  final scared = pose.amountOf(CompanionEmotion.scared);
  if (scared == 0) return Offset.zero;
  final time = 2 * math.pi * pose.emotionTime;
  return Offset(
        math.sin(time * 6 + side * 1.3) * 0.015,
        math.cos(time * 7.5 + side * 0.7) * 0.01,
      ) *
      scared;
}
