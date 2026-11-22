import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'bot_shapes.dart';

/// The body a hat or top is drawn on, in body coordinates.
///
/// The origin is the body center and [radius] the body size. [direction] is
/// -1 facing left and 1 facing right. Clothes drawn here move, spin, squash,
/// and grow with the body.
class BotBody {
  const BotBody({
    required this.shape,
    required this.radius,
    required this.direction,
    required this.sadness,
    required this.outline,
    required this.fur,
  });

  final BotShape shape;
  final double radius;
  final double direction;

  /// Sadness from 0 to 1.
  final double sadness;

  /// The body outline, for clipping clothes to the body.
  final Path outline;

  /// The body's darker colour in its current shade, for parts such as ears.
  final Color fur;

  /// Center of the hat brim.
  Offset get hatPoint => Offset(0, shape.hatY * radius);

  /// Width the hat brim should cover.
  double get hatWidth => shape.hatWidth * radius;

  /// Top of the neck, where a top starts.
  double get neckY => shape.neckY * radius;
}

/// Something worn on the head or the body.
abstract class BotAccessory {
  const BotAccessory();

  String get id;
  String get name;

  void paint(Canvas canvas, BotBody body);
}

class NoAccessory extends BotAccessory {
  const NoAccessory();

  @override
  String get id => 'none';
  @override
  String get name => 'None';

  @override
  void paint(Canvas canvas, BotBody body) {}
}

/// Two pointed cat ears in the body color with pink insides.
class CatEars extends BotAccessory {
  const CatEars();

  @override
  String get id => 'cat_ears';
  @override
  String get name => 'Cat ears';

  @override
  void paint(Canvas canvas, BotBody body) {
    final r = body.radius;
    final fur = body.fur;
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
class Cap extends BotAccessory {
  const Cap();

  @override
  String get id => 'cap';
  @override
  String get name => 'Cap';

  @override
  void paint(Canvas canvas, BotBody body) {
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
class TopHat extends BotAccessory {
  const TopHat();

  @override
  String get id => 'top_hat';
  @override
  String get name => 'Top hat';

  @override
  void paint(Canvas canvas, BotBody body) {
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
class TShirt extends BotAccessory {
  const TShirt();

  @override
  String get id => 'tshirt';
  @override
  String get name => 'T-shirt';

  @override
  void paint(Canvas canvas, BotBody body) {
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
class DoctorsCoat extends BotAccessory {
  const DoctorsCoat();

  @override
  String get id => 'doctor_coat';
  @override
  String get name => "Doctor's coat";

  @override
  void paint(Canvas canvas, BotBody body) {
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
