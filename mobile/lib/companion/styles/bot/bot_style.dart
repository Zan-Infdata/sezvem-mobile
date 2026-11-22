import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../companion_state.dart';
import '../companion_emotion.dart';
import '../companion_style.dart';
import 'bot_outfit.dart';
import 'bot_shapes.dart';

/// A solid shape with two white rounded-bar eyes, and optional clothes.
///
/// The look follows [bloub](https://bloub.vercel.app). The eyes sit on an
/// imagined sphere inside the body and are pushed out to the outline, so
/// turning the gaze moves them across the body and foreshortens them. Each
/// expression is a set of eye shapes and a gaze direction, and the companion
/// blends between them.
class BotCompanionStyle extends CompanionStyle {
  const BotCompanionStyle({
    this.shape = const BotCircle(),
    this.hat = const NoAccessory(),
    this.top = const NoAccessory(),
  });

  static const shapes = <BotShape>[BotCircle(), BotTriangle()];
  static const hats = <BotAccessory>[NoAccessory(), CatEars(), Cap(), TopHat()];
  static const tops = <BotAccessory>[NoAccessory(), TShirt(), DoctorsCoat()];

  /// Body radius at normal size. Small enough that a top hat still fits the
  /// window while the companion inflates or jumps in surprise.
  static const bodyRadius = 27.0;

  /// Distance from the bottom of the window to the ground line.
  static const groundInset = 10.0;

  /// Backflip jump height. Fits [CompanionStyle.backflipSize].
  static const jumpHeight = 52.0;

  final BotShape shape;
  final BotAccessory hat;
  final BotAccessory top;

  @override
  String get id => 'bot';

  @override
  String get name => 'Bot';

  @override
  List<CompanionSlot> get slots => [
    CompanionSlot(
      id: 'shape',
      name: 'Shape',
      options: [
        for (final part in shapes)
          CompanionOption(id: part.id, name: part.name),
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
    'shape': shape.id,
    'hat': hat.id,
    'top': top.id,
  };

  @override
  BotCompanionStyle customize(Map<String, String> choices) {
    T pick<T>(List<T> parts, String? id, String Function(T) idOf, T current) =>
        parts.firstWhere((part) => idOf(part) == id, orElse: () => current);
    final customized = BotCompanionStyle(
      shape: pick(shapes, choices['shape'], (part) => part.id, shape),
      hat: pick(hats, choices['hat'], (part) => part.id, hat),
      top: pick(tops, choices['top'], (part) => part.id, top),
    );
    return customized == this ? this : customized;
  }

  @override
  void paint(Canvas canvas, Size size, CompanionPose pose) {
    final direction = pose.facing == CompanionFacing.left ? -1.0 : 1.0;
    final radius = bodyRadius * pose.inflate;
    final feet = shape.bottom * radius;
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
    final motion = EmotionMotion.of(pose, direction);

    final lift = bob * radius * 0.18 + jump * jumpHeight + motion.lift * radius;
    final center = Offset(size.width / 2, groundY - feet - lift);

    // The shadow shrinks as the character leaves the ground.
    final shadow = 1 - (jump * 0.6 + motion.lift).clamp(0.0, 0.7);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: radius * shape.shadowWidth * (1 - bob * 0.15) * shadow,
        height: radius * 0.28 * shadow,
      ),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-flip * direction);
    // Sway, squash, and emotions pivot on the feet.
    canvas.translate(0, feet);
    canvas.rotate(tilt * direction);
    canvas.scale(1 + squash * 0.18, 1 - squash * 0.18);
    canvas.translate(0, -feet);
    motion.applyAtFeet(canvas, feet);

    final outline = shape.outline(radius);
    // Moods only shift the shade: sadness dulls it and fear makes it paler.
    final scared = pose.amountOf(CompanionEmotion.scared);
    final dark = _shade(shape.dark, pose.sad, scared);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.8,
          colors: [_shade(shape.light, pose.sad, scared), dark],
        ).createShader(outline.getBounds()),
    );
    final body = BotBody(
      shape: shape,
      radius: radius,
      direction: direction,
      sadness: pose.sad,
      outline: outline,
      fur: dark,
    );
    top.paint(canvas, body);
    canvas.drawPath(
      _eyes(_face(pose, direction), radius, pose),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    hat.paint(canvas, body);
    canvas.restore();
  }

  /// The face for [pose]: the resting face blended with the mood and the
  /// running emotion.
  _Face _face(CompanionPose pose, double direction) {
    var face = pose.walking ? _Face.walking : _Face.resting;
    face = face.lerp(_Face.sad, pose.sad);
    final emotion = pose.emotion;
    if (emotion != null) {
      face = face.lerp(_Face.of(emotion), pose.emotionAmount);
    }

    // The gaze wanders a little while idle. Fear makes it dart around.
    final phase = 2 * math.pi * (pose.walking ? 0 : pose.idle);
    final dart =
        pose.amountOf(CompanionEmotion.scared) *
        math.sin(2 * math.pi * pose.emotionTime * 1.5) *
        12;
    return face.copyWith(
      yaw: (face.yaw + math.sin(phase) * 4 + dart) * direction,
      pitch: face.pitch + math.cos(phase) * 3,
      roll: face.roll * direction,
    );
  }

  /// [color] a little duller for [sad] and a little paler for [scared],
  /// both from 0 to 1. The hue stays the same.
  static Color _shade(Color color, double sad, double scared) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(
          (hsl.saturation * (1 - sad * 0.35 - scared * 0.3)).clamp(0.0, 1.0),
        )
        .withLightness(
          (hsl.lightness - sad * 0.06 + scared * 0.1).clamp(0.0, 1.0),
        )
        .toColor();
  }

  /// Both eyes, in body coordinates.
  Path _eyes(_Face face, double radius, CompanionPose pose) {
    // Turn the face: yaw around the vertical axis, pitch up and down, then
    // roll. Screen x points right, y down, and z toward the viewer.
    final yaw = _rad(face.yaw),
        pitch = _rad(face.pitch),
        roll = _rad(face.roll);
    var forward = _Vec(math.sin(yaw), 0, math.cos(yaw));
    var right = _Vec(math.cos(yaw), 0, -math.sin(yaw));
    var down = const _Vec(0, 1, 0);
    (forward, down) = (
      forward * math.cos(pitch) - down * math.sin(pitch),
      down * math.cos(pitch) + forward * math.sin(pitch),
    );
    (right, down) = (
      right * math.cos(roll) + down * math.sin(roll),
      down * math.cos(roll) - right * math.sin(roll),
    );

    final eyes = Path();
    for (final side in [-1.0, 1.0]) {
      final eye = side < 0 ? face.left : face.right;
      final split = _rad(face.split * side);
      final normal = forward * math.cos(split) + right * math.sin(split);
      // An eye turned past the edge of the sphere is out of sight.
      if (normal.z <= 0.05) continue;
      final across = right * math.cos(split) - forward * math.sin(split);

      final eyePath = eye.path(
        eye.width * radius,
        math.max(eye.height * radius * (1 - pose.blink * 0.9), radius * 0.02),
        _rad(eye.tilt * -side),
      );
      // The sphere point, pushed out to the outline in its direction so the
      // eyes follow a triangle as they do a circle.
      final reach = radius * shape.radiusAt(math.atan2(normal.y, normal.x));
      // scared: each eye trembles on its own.
      final shake = emotionEyeShake(pose, side) * radius;
      final onSphere = _affine(
        across.x,
        across.y,
        down.x,
        down.y,
        normal.x * reach + shake.dx,
        normal.y * reach + shake.dy,
      );
      eyes.addPath(eyePath.transform(onSphere), Offset.zero);
    }
    return eyes;
  }

  @override
  bool operator ==(Object other) =>
      other is BotCompanionStyle &&
      other.shape.id == shape.id &&
      other.hat.id == hat.id &&
      other.top.id == top.id;

  @override
  int get hashCode => Object.hash(shape.id, hat.id, top.id);
}

/// One eye's shape. Width and height are multiples of the body radius. [tilt] is in degrees for the left eye; the right eye mirrors it.
/// [smile] from 0 to 1 hollows the bottom into an arch.
class _Eye {
  const _Eye(this.width, this.height, {this.tilt = 0, this.smile = 0});

  final double width;
  final double height;
  final double tilt;
  final double smile;

  _Eye lerp(_Eye other, double t) => _Eye(
    _lerp(width, other.width, t),
    _lerp(height, other.height, t),
    tilt: _lerp(tilt, other.tilt, t),
    smile: _lerp(smile, other.smile, t),
  );

  /// A rounded bar of [w] by [h] around the origin, turned by [angle].
  Path path(double w, double h, double angle) {
    var eye = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(math.min(w, h) / 2),
        ),
      );
    if (smile > 0.01) {
      // An oval rising from below cuts the bottom away, leaving an arch.
      final cut = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(0, h * (1.5 - smile * 0.8)),
            width: w * 1.3,
            height: h * 1.2,
          ),
        );
      eye = Path.combine(PathOperation.difference, eye, cut);
    }
    final cos = math.cos(angle), sin = math.sin(angle);
    return eye.transform(_affine(cos, sin, -sin, cos, 0, 0));
  }
}

/// Where the eyes are and what they look like. Angles are in degrees: [yaw]
/// turns toward the facing side, positive [pitch] looks up, and [split] is
/// the angle between each eye and the middle of the face. The resting face
/// and the sad, surprised, and confused faces use bloub's values.
class _Face {
  const _Face({
    required this.left,
    required this.right,
    this.split = 15.46,
    this.yaw = 28.49,
    this.pitch = 28.62,
    this.roll = -13,
  });

  const _Face.both(
    _Eye eye, {
    double split = 15.46,
    double yaw = 28.49,
    double pitch = 28.62,
    double roll = -13,
  }) : this(
         left: eye,
         right: eye,
         split: split,
         yaw: yaw,
         pitch: pitch,
         roll: roll,
       );

  static const resting = _Face.both(_Eye(0.186, 0.412));
  static const walking = _Face.both(
    _Eye(0.186, 0.412),
    yaw: 34,
    pitch: 18,
    roll: -8,
  );
  static const sad = _Face.both(
    _Eye(0.22, 0.4, tilt: -28),
    split: 16,
    yaw: 3,
    pitch: -13,
    roll: 0,
  );

  static _Face of(CompanionEmotion emotion) => switch (emotion) {
    // Wide round eyes, looking straight out.
    CompanionEmotion.surprised => const _Face.both(
      _Eye(0.45, 0.47),
      split: 19,
      yaw: 3,
      pitch: -3,
      roll: 0,
    ),
    // Eyes squeezed into arches, head thrown back.
    CompanionEmotion.laughing => const _Face.both(
      _Eye(0.4, 0.275, tilt: 10, smile: 1),
      split: 18,
      yaw: 4,
      pitch: 16,
      roll: 0,
    ),
    // Big round worried eyes, looking down and away.
    CompanionEmotion.scared => const _Face.both(
      _Eye(0.45, 0.5, tilt: -10),
      split: 20.5,
      yaw: -10,
      pitch: -14,
      roll: 0,
    ),
    // One eye open, one squinting, glancing away with a tilt.
    CompanionEmotion.confused => const _Face(
      left: _Eye(0.2, 0.44, tilt: -18),
      right: _Eye(0.28, 0.17, tilt: 14),
      split: 16.5,
      yaw: -14,
      pitch: 3,
      roll: 8,
    ),
    // Smiling arches, looking up.
    CompanionEmotion.happy => const _Face.both(
      _Eye(0.34, 0.4, smile: 0.85),
      split: 17,
      yaw: 8,
      pitch: 12,
      roll: 0,
    ),
  };

  final _Eye left;
  final _Eye right;
  final double split;
  final double yaw;
  final double pitch;
  final double roll;

  _Face lerp(_Face other, double t) => _Face(
    left: left.lerp(other.left, t),
    right: right.lerp(other.right, t),
    split: _lerp(split, other.split, t),
    yaw: _lerp(yaw, other.yaw, t),
    pitch: _lerp(pitch, other.pitch, t),
    roll: _lerp(roll, other.roll, t),
  );

  _Face copyWith({double? yaw, double? pitch, double? roll}) => _Face(
    left: left,
    right: right,
    split: split,
    yaw: yaw ?? this.yaw,
    pitch: pitch ?? this.pitch,
    roll: roll ?? this.roll,
  );
}

class _Vec {
  const _Vec(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vec operator +(_Vec other) => _Vec(x + other.x, y + other.y, z + other.z);
  _Vec operator -(_Vec other) => _Vec(x - other.x, y - other.y, z - other.z);
  _Vec operator *(double factor) => _Vec(x * factor, y * factor, z * factor);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A 2D transform taking x to ([ax], [ay]) and y to ([bx], [by]), then
/// moving by ([dx], [dy]), as the column-major 4x4 matrix [Path.transform]
/// expects.
Float64List _affine(
  double ax,
  double ay,
  double bx,
  double by,
  double dx,
  double dy,
) => Float64List.fromList([
  ax, ay, 0, 0, //
  bx, by, 0, 0, //
  0, 0, 1, 0, //
  dx, dy, 0, 1, //
]);

double _rad(double degrees) => degrees * math.pi / 180;
