import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../companion_state.dart';
import 'companion_style.dart';

/// The original look: a round teal body with two eyes that look where it
/// faces. Drawn with the canvas, so it needs no assets.
class ClassicCompanionStyle extends CompanionStyle {
  const ClassicCompanionStyle();

  /// Body radius at normal size.
  static const bodyRadius = 30.0;

  /// Distance from the bottom of the window to the ground line.
  static const groundInset = 10.0;

  /// Backflip jump height. Fits [CompanionStyle.backflipSize].
  static const jumpHeight = 56.0;

  @override
  String get id => 'classic';

  @override
  String get name => 'Classic';

  @override
  void paint(Canvas canvas, Size size, CompanionPose pose) {
    final direction = pose.facing == CompanionFacing.left ? -1.0 : 1.0;
    final radius = bodyRadius * pose.inflate;
    final groundY = size.height - groundInset;

    // idle and walk: bob up and down, and sway while walking. Sadness damps it.
    final bob =
        (pose.walking
            ? math.sin(pose.walk * 2 * math.pi).abs()
            : (math.sin(pose.idle * 2 * math.pi) + 1) / 2) *
        (1 - pose.sad * 0.7);
    final tilt = pose.walking ? math.sin(pose.walk * 2 * math.pi) * 0.08 : 0.0;
    // bounce: squash and stretch.
    final squash = math.sin(pose.bounce * math.pi);
    // backflip: one spin backwards relative to facing while jumping.
    final flip = Curves.easeInOut.transform(pose.backflip) * 2 * math.pi;
    final jump = math.sin(pose.backflip * math.pi);

    final lift = bob * radius * 0.18 + jump * jumpHeight;
    final center = Offset(size.width / 2, groundY - radius - lift);

    // The shadow shrinks as the character leaves the ground.
    final shadow = 1 - jump * 0.6;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: radius * (1.6 - bob * 0.3) * shadow,
        height: radius * 0.28 * shadow,
      ),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-flip * direction);
    // Sway and squash pivot on the feet.
    canvas.translate(0, radius);
    canvas.rotate(tilt * direction);
    canvas.scale(1 + squash * 0.18, 1 - squash * 0.18);
    canvas.translate(0, -radius);

    // sad: the body turns blue.
    final body = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(
              const Color(0xFF80CBC4),
              const Color(0xFF9FA8DA),
              pose.sad,
            )!,
            Color.lerp(
              const Color(0xFF00897B),
              const Color(0xFF5C6BC0),
              pose.sad,
            )!,
          ],
        ).createShader(body),
    );

    final look = direction * radius * 0.12 * (1 - pose.sad);
    final dark = Paint()..color = const Color(0xFF263238);
    for (final side in [-1.0, 1.0]) {
      // blink closes the eyes. sad lowers and narrows them.
      final eye = Offset(
        side * radius * 0.36 + look,
        -radius * (0.12 - pose.sad * 0.06),
      );
      final eyeHeight =
          radius * 0.5 * (1 - pose.blink * 0.9) * (1 - pose.sad * 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: radius * 0.38, height: eyeHeight),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      if (pose.blink < 0.6) {
        canvas.drawCircle(
          eye +
              Offset(
                direction * radius * 0.06 * (1 - pose.sad),
                radius * (0.04 + pose.sad * 0.06),
              ),
          radius * 0.11,
          dark,
        );
      }
      if (pose.sad > 0) {
        // Brows that rise toward the middle.
        canvas.drawLine(
          Offset(side * radius * 0.16, -radius * 0.5),
          Offset(side * radius * 0.56, -radius * 0.36),
          Paint()
            ..color = dark.color.withValues(alpha: pose.sad)
            ..strokeWidth = radius * 0.07
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (pose.sad > 0) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(0, radius * 0.52),
          width: radius * 0.44,
          height: radius * 0.28,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = dark.color.withValues(alpha: pose.sad)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }
}
