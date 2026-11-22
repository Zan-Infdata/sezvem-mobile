import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../companion_state.dart';
import 'companion_emotion.dart';
import 'companion_style.dart';

/// A solid shape whose eyes are cut out of it, so whatever is behind the
/// companion shows through them.
///
/// The eyes sit on an imagined sphere inside the body. Turning the gaze moves
/// them across the body and foreshortens them, which makes a flat shape look
/// round. Each expression is a set of eye shapes and a gaze direction, and
/// the companion blends between them.
class BotCompanionStyle extends CompanionStyle {
  const BotCompanionStyle({this.shape = const BotCircle()});

  static const shapes = <BotShape>[BotCircle(), BotTriangle()];

  /// Body radius of the circle at normal size.
  static const bodyRadius = 30.0;

  /// Distance from the bottom of the window to the ground line.
  static const groundInset = 10.0;

  /// Backflip jump height. Fits [CompanionStyle.backflipSize].
  static const jumpHeight = 56.0;

  final BotShape shape;

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
        for (final shape in shapes)
          CompanionOption(id: shape.id, name: shape.name),
      ],
    ),
  ];

  @override
  Map<String, String> get choices => {'shape': shape.id};

  @override
  BotCompanionStyle customize(Map<String, String> choices) {
    final picked = shapes.firstWhere(
      (shape) => shape.id == choices['shape'],
      orElse: () => shape,
    );
    return picked.id == shape.id ? this : BotCompanionStyle(shape: picked);
  }

  @override
  void paint(Canvas canvas, Size size, CompanionPose pose) {
    final direction = pose.facing == CompanionFacing.left ? -1.0 : 1.0;
    final radius = bodyRadius * shape.size * pose.inflate;
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
    final center = Offset(
      size.width / 2 + motion.shiftX * radius,
      groundY - radius - lift,
    );

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
    canvas.translate(0, radius);
    canvas.rotate(tilt * direction);
    canvas.scale(1 + squash * 0.18, 1 - squash * 0.18);
    canvas.translate(0, -radius);
    motion.applyAtFeet(canvas, radius);

    final outline = shape.outline(radius);
    final eyes = _eyes(_face(pose, direction), radius, pose.blink);
    final body = Path.combine(PathOperation.difference, outline, eyes);

    // sad turns the body blue, and fear drains some of its colour.
    final pale = (pose.sad + pose.amountOf(CompanionEmotion.scared) * 0.45)
        .clamp(0.0, 1.0);
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.8,
          colors: [
            Color.lerp(shape.light, shape.sadLight, pale)!,
            Color.lerp(shape.dark, shape.sadDark, pale)!,
          ],
        ).createShader(outline.getBounds()),
    );
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
      yaw:
          (face.yaw + math.sin(phase) * 4 + dart) * direction * shape.gazeScale,
      pitch: face.pitch + math.cos(phase) * 3,
      roll: face.roll * direction,
    );
  }

  /// Both eye holes, in body coordinates.
  Path _eyes(_Face face, double radius, double blink) {
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

    final scale = radius * shape.faceScale;
    final eyes = Path();
    for (final side in [-1.0, 1.0]) {
      final eye = side < 0 ? face.left : face.right;
      final split = _rad(face.split * side);
      final normal = forward * math.cos(split) + right * math.sin(split);
      // An eye turned past the edge of the sphere is out of sight.
      if (normal.z <= 0.05) continue;
      final across = right * math.cos(split) - forward * math.sin(split);

      final eyeScale = scale * shape.eyeSize;
      final hole = eye.path(
        eye.width * eyeScale,
        math.max(eye.height * eyeScale * (1 - blink * 0.9), scale * 0.02),
        _rad(eye.tilt * -side),
      );
      // Lay the flat eye on the sphere's surface at its position.
      final onSphere = _affine(
        across.x,
        across.y,
        down.x,
        down.y,
        normal.x * scale,
        normal.y * scale + shape.faceY * radius,
      );
      eyes.addPath(hole.transform(onSphere), Offset.zero);
    }
    return eyes;
  }

  @override
  bool operator ==(Object other) =>
      other is BotCompanionStyle && other.shape.id == shape.id;

  @override
  int get hashCode => shape.id.hashCode;
}

/// A body shape for [BotCompanionStyle] with its colours and where its face
/// goes. Lengths are multiples of the body radius.
abstract class BotShape {
  const BotShape();

  String get id;
  String get name;

  /// Body colours: highlight and shade, then the same when fully sad.
  Color get light;
  Color get dark;
  Color get sadLight;
  Color get sadDark;

  /// Radius relative to [BotCompanionStyle.bodyRadius]. A wide shape is
  /// smaller so it fits its window while inflated.
  double get size => 1;

  /// Height of the face center below the body center.
  double get faceY => 0;

  /// Radius of the sphere the eyes sit on.
  double get faceScale => 1;

  /// How far the gaze turns sideways relative to the circle. A narrow face
  /// turns less so its eyes stay on the body.
  double get gazeScale => 1;

  /// Eye size relative to the face sphere.
  double get eyeSize => 1.25;

  /// Shadow width.
  double get shadowWidth => 1.6;

  /// The outline around the body center. The feet are at `y = radius`.
  Path outline(double radius);
}

/// The green circle from the Classic style.
class BotCircle extends BotShape {
  const BotCircle();

  @override
  String get id => 'circle';
  @override
  String get name => 'Green circle';

  @override
  Color get light => const Color(0xFF80CBC4);
  @override
  Color get dark => const Color(0xFF00897B);
  @override
  Color get sadLight => const Color(0xFF9FA8DA);
  @override
  Color get sadDark => const Color(0xFF5C6BC0);

  @override
  Path outline(double radius) =>
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
}

/// The orange triangle from the Dress-up style, with rounded corners.
class BotTriangle extends BotShape {
  const BotTriangle();

  @override
  String get id => 'triangle';
  @override
  String get name => 'Orange triangle';

  @override
  Color get light => const Color(0xFFFFCC80);
  @override
  Color get dark => const Color(0xFFEF6C00);
  @override
  Color get sadLight => const Color(0xFFB0BEC5);
  @override
  Color get sadDark => const Color(0xFF546E7A);

  @override
  double get size => 0.85;
  @override
  double get faceY => 0.3;
  @override
  double get faceScale => 0.72;
  @override
  double get gazeScale => 0.6;
  @override
  double get eyeSize => 1.5;
  @override
  double get shadowWidth => 1.9;

  @override
  Path outline(double radius) {
    final corners = [
      Offset(0, -1.15 * radius),
      Offset(1.1 * radius, radius),
      Offset(-1.1 * radius, radius),
    ];
    final corner = radius * 0.22;
    final path = Path();
    for (var i = 0; i < corners.length; i++) {
      final previous = corners[(i + corners.length - 1) % corners.length];
      final current = corners[i];
      final next = corners[(i + 1) % corners.length];
      final start = current + _toward(current, previous, corner);
      final end = current + _toward(current, next, corner);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }
    return path..close();
  }

  static Offset _toward(Offset from, Offset to, double distance) {
    final delta = to - from;
    return delta / delta.distance * distance;
  }
}

/// One eye's shape. Width and height are multiples of the face sphere
/// radius. [tilt] is in degrees for the left eye; the right eye mirrors it.
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
/// the angle between each eye and the middle of the face.
class _Face {
  const _Face({
    required this.left,
    required this.right,
    this.split = 16,
    this.yaw = 22,
    this.pitch = 10,
    this.roll = 0,
  });

  const _Face.both(
    _Eye eye, {
    double split = 16,
    double yaw = 22,
    double pitch = 10,
    double roll = 0,
  }) : this(
         left: eye,
         right: eye,
         split: split,
         yaw: yaw,
         pitch: pitch,
         roll: roll,
       );

  static const resting = _Face.both(_Eye(0.19, 0.41));
  static const walking = _Face.both(_Eye(0.19, 0.41), yaw: 32, pitch: 4);
  static const sad = _Face.both(
    _Eye(0.21, 0.34, tilt: -24),
    split: 15,
    yaw: 10,
    pitch: -14,
  );

  static _Face of(CompanionEmotion emotion) => switch (emotion) {
    // Wide round eyes, looking straight out.
    CompanionEmotion.surprised => const _Face.both(
      _Eye(0.36, 0.44),
      split: 19,
      yaw: 6,
      pitch: -2,
    ),
    // Eyes squeezed into arches, head thrown back.
    CompanionEmotion.laughing => const _Face.both(
      _Eye(0.32, 0.22, tilt: 10, smile: 1),
      split: 18,
      yaw: 4,
      pitch: 16,
    ),
    // Tall worried eyes, looking down and away.
    CompanionEmotion.scared => const _Face.both(
      _Eye(0.28, 0.52, tilt: -10),
      split: 20,
      yaw: -10,
      pitch: -14,
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
      _Eye(0.27, 0.32, smile: 0.85),
      split: 17,
      yaw: 8,
      pitch: 12,
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
