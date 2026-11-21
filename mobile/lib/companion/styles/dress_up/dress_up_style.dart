import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../companion_state.dart';
import '../companion_style.dart';
import 'dress_up_parts.dart';

/// A companion put together from a base, a hat, and a top.
///
/// Every base gets the same animations, and accessories are drawn on the body
/// so they move with it. Add a part by adding it to [bases], [hats], or
/// [tops]. The style test then checks it with every other part.
class DressUpCompanionStyle extends CompanionStyle {
  const DressUpCompanionStyle({
    this.base = const CircleBase(),
    this.hat = const NoAccessory(),
    this.top = const NoAccessory(),
  });

  static const bases = <DressUpBase>[CircleBase(), TriangleBase()];
  static const hats = <DressUpAccessory>[
    NoAccessory(),
    PartyHat(),
    Cap(),
    TopHat(),
  ];
  static const tops = <DressUpAccessory>[NoAccessory(), TShirt(), Scarf()];

  /// Body radius at normal size. Smaller than Classic to leave room for hats.
  static const bodyRadius = 23.0;

  /// Distance from the bottom of the window to the ground line.
  static const groundInset = 10.0;

  /// Backflip jump height. Fits [CompanionStyle.backflipSize].
  static const jumpHeight = 52.0;

  final DressUpBase base;
  final DressUpAccessory hat;
  final DressUpAccessory top;

  @override
  String get id => 'dress_up';

  @override
  String get name => 'Dress-up';

  @override
  List<CompanionSlot> get slots => [
    CompanionSlot(
      id: 'base',
      name: 'Base',
      options: [
        for (final part in bases) CompanionOption(id: part.id, name: part.name),
      ],
    ),
    CompanionSlot(
      id: 'hat',
      name: 'Hat',
      options: [
        for (final part in hats) CompanionOption(id: part.id, name: part.name),
      ],
    ),
    CompanionSlot(
      id: 'top',
      name: 'Top',
      options: [
        for (final part in tops) CompanionOption(id: part.id, name: part.name),
      ],
    ),
  ];

  @override
  Map<String, String> get choices => {
    'base': base.id,
    'hat': hat.id,
    'top': top.id,
  };

  @override
  DressUpCompanionStyle customize(Map<String, String> choices) {
    T pick<T>(List<T> parts, String? id, String Function(T) idOf, T current) =>
        parts.firstWhere((part) => idOf(part) == id, orElse: () => current);
    return DressUpCompanionStyle(
      base: pick(bases, choices['base'], (part) => part.id, base),
      hat: pick(hats, choices['hat'], (part) => part.id, hat),
      top: pick(tops, choices['top'], (part) => part.id, top),
    );
  }

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

    final shadow = 1 - jump * 0.6;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: radius * (1.8 - bob * 0.3) * shadow,
        height: radius * 0.3 * shadow,
      ),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-flip * direction);
    canvas.translate(0, radius);
    canvas.rotate(tilt * direction);
    canvas.scale(1 + squash * 0.18, 1 - squash * 0.18);
    canvas.translate(0, -radius);

    final outline = base.outline(radius);
    final body = DressUpBody(
      base: base,
      radius: radius,
      direction: direction,
      sadness: pose.sad,
      outline: outline,
    );

    // sad: the body turns blue-grey.
    canvas.drawPath(
      outline,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(base.light, base.sadLight, pose.sad)!,
            Color.lerp(base.dark, base.sadDark, pose.sad)!,
          ],
        ).createShader(outline.getBounds()),
    );
    top.paint(canvas, body);
    _paintFace(canvas, pose, radius, direction);
    hat.paint(canvas, body);
    canvas.restore();
  }

  void _paintFace(
    Canvas canvas,
    CompanionPose pose,
    double radius,
    double direction,
  ) {
    final look = direction * radius * 0.1 * (1 - pose.sad);
    final dark = Paint()..color = const Color(0xFF263238);
    for (final side in [-1.0, 1.0]) {
      // blink closes the eyes. sad lowers and narrows them.
      final eye = Offset(
        side * radius * base.eyeSpacing + look,
        radius * (base.eyeY + pose.sad * 0.06),
      );
      final eyeHeight =
          radius *
          base.eyeHeight *
          (1 - pose.blink * 0.9) *
          (1 - pose.sad * 0.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: eye,
          width: radius * base.eyeWidth,
          height: eyeHeight,
        ),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      if (pose.blink < 0.6) {
        final pupil =
            eye +
            Offset(
              direction * radius * 0.07 * (1 - pose.sad),
              radius * (0.04 + pose.sad * 0.08),
            );
        canvas.drawCircle(pupil, radius * base.pupil, dark);
        // A shine dot makes the bigger eyes look friendlier.
        canvas.drawCircle(
          pupil +
              Offset(-radius * base.pupil * 0.35, -radius * base.pupil * 0.35),
          radius * base.pupil * 0.32,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
      if (pose.sad > 0) {
        // Brows that rise toward the middle.
        final browY = radius * (base.eyeY - base.eyeHeight * 0.62);
        canvas.drawLine(
          Offset(side * radius * base.eyeSpacing * 0.4, browY - radius * 0.06),
          Offset(side * radius * base.eyeSpacing * 1.4, browY + radius * 0.06),
          Paint()
            ..color = dark.color.withValues(alpha: pose.sad)
            ..strokeWidth = radius * 0.08
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (pose.sad > 0) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(0, radius * base.mouthY),
          width: radius * 0.44,
          height: radius * 0.28,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = dark.color.withValues(alpha: pose.sad)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DressUpCompanionStyle &&
      other.base.id == base.id &&
      other.hat.id == hat.id &&
      other.top.id == top.id;

  @override
  int get hashCode => Object.hash(base.id, hat.id, top.id);
}
