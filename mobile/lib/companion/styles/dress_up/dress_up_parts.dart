import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The body a hat or top is drawn on, in body coordinates.
///
/// The origin is the body center and [radius] the body size. The feet are at
/// `y = radius`. [direction] is -1 facing left and 1 facing right. Accessories
/// drawn here move, spin, squash, and grow with the body.
class DressUpBody {
  const DressUpBody({
    required this.base,
    required this.radius,
    required this.direction,
    required this.sadness,
    required this.outline,
  });

  final DressUpBase base;
  final double radius;
  final double direction;

  /// Sadness from 0 to 1.
  final double sadness;

  /// The body outline, for clipping clothes to the body.
  final Path outline;

  /// Center of the hat brim.
  Offset get hatPoint => Offset(0, base.hatY * radius);

  /// Width the hat brim should cover.
  double get hatWidth => base.hatWidth * radius;

  /// Top of the neck, where a top starts.
  double get neckY => base.neckY * radius;
}

/// A body shape with its colors and where the face and accessories go.
///
/// Positions are in multiples of the body radius from the body center. Keep
/// everything within about one radius so the companion fits its window.
abstract class DressUpBase {
  const DressUpBase();

  String get id;
  String get name;

  /// Body colors: highlight and shade, then the same when fully sad.
  Color get light;
  Color get dark;
  Color get sadLight;
  Color get sadDark;

  /// Eye center height and distance from the middle.
  double get eyeY;
  double get eyeSpacing;

  /// Eye width and height, and pupil radius.
  double get eyeWidth;
  double get eyeHeight;
  double get pupil;

  /// Height of the sad mouth.
  double get mouthY;

  /// Top of the neck, where a top starts. Below [mouthY].
  double get neckY;

  /// Center height of the hat brim, and the brim width.
  double get hatY;
  double get hatWidth;

  Path outline(double radius);
}

/// The green circle from the Classic style.
class CircleBase extends DressUpBase {
  const CircleBase();

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
  double get eyeY => -0.2;
  @override
  double get eyeSpacing => 0.4;
  @override
  double get eyeWidth => 0.52;
  @override
  double get eyeHeight => 0.62;
  @override
  double get pupil => 0.16;
  @override
  double get mouthY => 0.4;
  @override
  double get neckY => 0.55;
  @override
  double get hatY => -0.8;
  @override
  double get hatWidth => 1.15;

  @override
  Path outline(double radius) =>
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
}

/// An orange triangle with rounded corners, pointing up.
class TriangleBase extends DressUpBase {
  const TriangleBase();

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
  double get eyeY => 0.15;
  @override
  double get eyeSpacing => 0.32;
  @override
  double get eyeWidth => 0.42;
  @override
  double get eyeHeight => 0.5;
  @override
  double get pupil => 0.13;
  @override
  double get mouthY => 0.5;
  @override
  double get neckY => 0.6;
  @override
  double get hatY => -0.82;
  @override
  double get hatWidth => 0.85;

  @override
  Path outline(double radius) => _roundedPolygon([
    Offset(0, -1.15 * radius),
    Offset(1.1 * radius, radius),
    Offset(-1.1 * radius, radius),
  ], radius * 0.22);
}

/// Something worn on the head or the body.
abstract class DressUpAccessory {
  const DressUpAccessory();

  String get id;
  String get name;

  void paint(Canvas canvas, DressUpBody body);
}

class NoAccessory extends DressUpAccessory {
  const NoAccessory();

  @override
  String get id => 'none';
  @override
  String get name => 'None';

  @override
  void paint(Canvas canvas, DressUpBody body) {}
}

/// Two pointed cat ears in the body color with pink insides.
class CatEars extends DressUpAccessory {
  const CatEars();

  @override
  String get id => 'cat_ears';
  @override
  String get name => 'Cat ears';

  @override
  void paint(Canvas canvas, DressUpBody body) {
    final r = body.radius;
    final base = body.base;
    final fur = Color.lerp(base.dark, base.sadDark, body.sadness)!;
    // Ears droop outward a little when sad.
    final droop = body.sadness * 0.35;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      // The ear root sits just inside the head so it grows out of it.
      canvas.translate(
        side * body.hatWidth * 0.34,
        body.hatPoint.dy + r * 0.12,
      );
      canvas.rotate(side * (0.25 + droop));
      final height = r * 0.55;
      final half = r * 0.24;
      final outer = Path()
        ..moveTo(-half, 0)
        ..quadraticBezierTo(-half * 0.4, -height * 0.7, 0, -height)
        ..quadraticBezierTo(half * 0.4, -height * 0.7, half, 0)
        ..close();
      canvas.drawPath(outer, Paint()..color = fur);
      final inner = Path()
        ..moveTo(-half * 0.55, -r * 0.04)
        ..quadraticBezierTo(-half * 0.2, -height * 0.55, 0, -height * 0.75)
        ..quadraticBezierTo(half * 0.2, -height * 0.55, half * 0.55, -r * 0.04)
        ..close();
      canvas.drawPath(inner, Paint()..color = const Color(0xFFF8BBD0));
      canvas.restore();
    }
  }
}

/// A baseball cap with its bill pointing the way the companion faces.
class Cap extends DressUpAccessory {
  const Cap();

  @override
  String get id => 'cap';
  @override
  String get name => 'Cap';

  @override
  void paint(Canvas canvas, DressUpBody body) {
    final r = body.radius;
    final brim = body.hatPoint;
    final width = body.hatWidth * 0.9;
    final blue = Paint()..color = const Color(0xFF1E88E5);
    canvas.drawPath(
      Path()
        ..moveTo(brim.dx - width / 2, brim.dy)
        ..arcTo(
          Rect.fromCenter(center: brim, width: width, height: r * 0.76),
          math.pi,
          math.pi,
          false,
        )
        ..close(),
      blue,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: brim + Offset(body.direction * width * 0.55, 0),
        width: width * 0.62,
        height: r * 0.14,
      ),
      Paint()..color = const Color(0xFF1565C0),
    );
    canvas.drawCircle(
      brim + Offset(0, -r * 0.38),
      r * 0.06,
      Paint()..color = const Color(0xFF1565C0),
    );
  }
}

/// A tall black hat with a red band.
class TopHat extends DressUpAccessory {
  const TopHat();

  @override
  String get id => 'top_hat';
  @override
  String get name => 'Top hat';

  @override
  void paint(Canvas canvas, DressUpBody body) {
    final r = body.radius;
    final brim = body.hatPoint;
    final black = Paint()..color = const Color(0xFF212121);
    final crown = body.hatWidth * 0.62;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          brim.dx - crown / 2,
          brim.dy - r * 0.56,
          brim.dx + crown / 2,
          brim.dy,
        ),
        Radius.circular(r * 0.05),
      ),
      black,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        brim.dx - crown / 2,
        brim.dy - r * 0.18,
        brim.dx + crown / 2,
        brim.dy - r * 0.06,
      ),
      Paint()..color = const Color(0xFFE53935),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: brim,
        width: body.hatWidth * 1.05,
        height: r * 0.14,
      ),
      black,
    );
  }
}

/// A striped shirt covering the body below the neck.
class TShirt extends DressUpAccessory {
  const TShirt();

  @override
  String get id => 'tshirt';
  @override
  String get name => 'T-shirt';

  @override
  void paint(Canvas canvas, DressUpBody body) {
    final r = body.radius;
    final top = body.neckY;
    canvas.save();
    canvas.clipPath(body.outline);
    canvas.drawRect(
      Rect.fromLTRB(-2 * r, top, 2 * r, 2 * r),
      Paint()..color = const Color(0xFF42A5F5),
    );
    final stripe = Paint()..color = const Color(0xFF90CAF9);
    for (var y = top + r * 0.16; y < r; y += r * 0.2) {
      canvas.drawRect(Rect.fromLTRB(-2 * r, y, 2 * r, y + r * 0.07), stripe);
    }
    canvas.restore();
    // Collar.
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.16, top)
        ..lineTo(0, top + r * 0.16)
        ..lineTo(r * 0.16, top)
        ..close(),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}

/// A white doctor's coat with lapels, a pen in the pocket, and a
/// stethoscope around the neck.
class DoctorsCoat extends DressUpAccessory {
  const DoctorsCoat();

  @override
  String get id => 'doctor_coat';
  @override
  String get name => "Doctor's coat";

  @override
  void paint(Canvas canvas, DressUpBody body) {
    final r = body.radius;
    final top = body.neckY - r * 0.06;
    final white = Paint()..color = const Color(0xFFFAFAFA);
    final seam = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipPath(body.outline);
    canvas.drawRect(Rect.fromLTRB(-2 * r, top, 2 * r, 2 * r), white);
    // A light blue scrub top shows in the V of the open coat.
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.22, top)
        ..lineTo(0, top + r * 0.32)
        ..lineTo(r * 0.22, top)
        ..close(),
      Paint()..color = const Color(0xFF80DEEA),
    );
    // Lapels and the front edge.
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * r * 0.22, top),
        Offset(0, top + r * 0.32),
        seam,
      );
    }
    canvas.drawLine(Offset(0, top + r * 0.32), Offset(0, 2 * r), seam);
    // Breast pocket with a pen, on the side it faces.
    final pocket = Offset(body.direction * r * 0.42, top + r * 0.2);
    canvas.drawLine(
      pocket + Offset(0, -r * 0.08),
      pocket + Offset(0, r * 0.06),
      Paint()
        ..color = const Color(0xFF1E88E5)
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: pocket + Offset(0, r * 0.1),
        width: r * 0.24,
        height: r * 0.16,
      ),
      seam,
    );
    canvas.restore();
    // Stethoscope: tubing around the neck down to a chest piece.
    final tube = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round;
    final side = -body.direction;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.3, top - r * 0.02)
        ..quadraticBezierTo(0, top + r * 0.16, r * 0.3, top - r * 0.02),
      tube,
    );
    final chest = Offset(side * r * 0.32, top + r * 0.36);
    canvas.drawPath(
      Path()
        ..moveTo(side * r * 0.3, top - r * 0.02)
        ..quadraticBezierTo(
          side * r * 0.42,
          top + r * 0.18,
          chest.dx,
          chest.dy,
        ),
      tube,
    );
    canvas.drawCircle(
      chest,
      r * 0.07,
      Paint()..color = const Color(0xFF90A4AE),
    );
  }
}

/// A closed polygon through [points] with each corner rounded by [corner].
Path _roundedPolygon(List<Offset> points, double corner) {
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final previous = points[(i - 1 + points.length) % points.length];
    final current = points[i];
    final next = points[(i + 1) % points.length];
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

Offset _toward(Offset from, Offset to, double distance) {
  final delta = to - from;
  return delta / delta.distance * distance;
}
