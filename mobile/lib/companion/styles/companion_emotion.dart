import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../companion_state.dart';
import 'companion_style.dart';

/// How an emotion moves the whole body in one frame.
///
/// Every style can apply it the same way, so each one shows the emotions
/// without its own motion code. Lengths are multiples of the body radius.
/// Squash, stretch, and rotation pivot on the feet.
class EmotionMotion {
  const EmotionMotion({
    this.lift = 0,
    this.shiftX = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  /// The body motion for [pose] when facing [direction], -1 left or 1 right.
  factory EmotionMotion.of(CompanionPose pose, double direction) {
    final t = pose.emotionTime;
    final wave = 2 * math.pi * t;
    var lift = 0.0, shiftX = 0.0, scaleX = 1.0, scaleY = 1.0, rotation = 0.0;

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
      final shake = math.sin(wave * 4).abs();
      lift += laughing * shake * 0.12;
      scaleX *= 1 + laughing * (1 - shake) * 0.06;
      scaleY *= 1 - laughing * (1 - shake) * 0.06;
      rotation += laughing * math.sin(wave * 2.5) * 0.07;
    }

    // scared: shrinks, leans away from where it faces, and trembles.
    final scared = pose.amountOf(CompanionEmotion.scared);
    if (scared > 0) {
      scaleX *= 1 - scared * 0.1;
      scaleY *= 1 - scared * 0.12;
      shiftX += scared * math.sin(wave * 16) * 0.04;
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
      shiftX: shiftX,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
    );
  }

  final double lift;
  final double shiftX;
  final double scaleX;
  final double scaleY;
  final double rotation;

  /// Applies the squash, stretch, and rotation around the feet at `y = feetY`
  /// in the current canvas coordinates. Apply [lift] and [shiftX] to the body
  /// center before this.
  void applyAtFeet(Canvas canvas, double feetY) {
    canvas.translate(0, feetY);
    canvas.rotate(rotation);
    canvas.scale(scaleX, scaleY);
    canvas.translate(0, -feetY);
  }
}

/// How an emotion resizes a simple eye, for styles with round eyes.
///
/// [side] is -1 for the left eye and 1 for the right. The result multiplies
/// the eye width and height.
Size emotionEyeScale(CompanionPose pose, double side) {
  var width = 1.0, height = 1.0;
  final surprised = pose.amountOf(CompanionEmotion.surprised);
  width *= 1 + surprised * 0.3;
  height *= 1 + surprised * 0.3;
  height *= 1 - pose.amountOf(CompanionEmotion.laughing) * 0.7;
  final scared = pose.amountOf(CompanionEmotion.scared);
  width *= 1 - scared * 0.15;
  height *= 1 + scared * 0.15;
  final confused = pose.amountOf(CompanionEmotion.confused);
  height *= 1 + confused * (side < 0 ? 0.2 : -0.4);
  height *= 1 - pose.amountOf(CompanionEmotion.happy) * 0.45;
  return Size(width, height);
}
