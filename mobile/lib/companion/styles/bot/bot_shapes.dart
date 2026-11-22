import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A body shape for the Bot style, with its colours and where clothes go.
///
/// Lengths are multiples of the body radius from the body center. The
/// shapes follow [bloub](https://bloub.vercel.app): a unit circle, and a
/// triangle whose corners are rounded by a third of the radius.
abstract class BotShape {
  const BotShape();

  String get id;
  String get name;

  /// Body colours: highlight and shade.
  Color get light;
  Color get dark;

  /// The colour at the very edge, for depth. The same as [dark] unless a
  /// shape sets a deeper one.
  Color get edge => dark;

  /// Distance from the center down to the lowest point, where the feet are.
  double get bottom;

  /// Distance from the center to the edge in the screen direction [angle],
  /// in radians with 0 pointing right and positive angles turning down. The
  /// eyes are placed by it, so they follow the outline.
  double radiusAt(double angle);

  /// Center height of a hat brim, and the brim width.
  double get hatY;
  double get hatWidth;

  /// Top of the neck, where a top starts.
  double get neckY;

  /// Shadow width.
  double get shadowWidth;

  /// The outline around the body center at [radius].
  Path outline(double radius);
}

/// The green circle, in a deep jade.
class BotCircle extends BotShape {
  const BotCircle();

  @override
  String get id => 'circle';
  @override
  String get name => 'Green circle';

  @override
  Color get light => const Color(0xFF7ADCC4);
  @override
  Color get dark => const Color(0xFF14917D);
  @override
  Color get edge => const Color(0xFF0B5E54);

  @override
  double get bottom => 1;
  @override
  double radiusAt(double angle) => 1;

  @override
  double get hatY => -0.8;
  @override
  double get hatWidth => 1.15;
  @override
  double get neckY => 0.45;
  @override
  double get shadowWidth => 1.6;

  @override
  Path outline(double radius) =>
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
}

/// The orange triangle, pointing up.
///
/// It is a sharp triangle with corners [core] from the center, widened in
/// every direction by [rounding]. That rounds the corners and leaves the
/// tip 1.12 radii above the center and the base 0.73 below it.
class BotTriangle extends BotShape {
  const BotTriangle();

  /// Distance from the center to each corner of the sharp triangle.
  static const core = 0.78;

  /// How far the sharp triangle is widened.
  static const rounding = 0.34;

  /// Corner directions in radians: up, lower right, lower left.
  static final _cornerAngles = [
    for (var i = 0; i < 3; i++) -math.pi / 2 + i * 2 * math.pi / 3,
  ];

  static final _corners = [
    for (final angle in _cornerAngles)
      Offset(math.cos(angle), math.sin(angle)) * core,
  ];

  @override
  String get id => 'triangle';
  @override
  String get name => 'Orange triangle';

  @override
  Color get light => const Color(0xFFFFCC80);
  @override
  Color get dark => const Color(0xFFEF6C00);

  @override
  double get bottom => core / 2 + rounding;

  @override
  double radiusAt(double angle) {
    // The edge is where the distance to the sharp triangle reaches
    // [rounding]. Search along the ray for it.
    final direction = Offset(math.cos(angle), math.sin(angle));
    var inside = 0.0, outside = core + rounding;
    for (var i = 0; i < 24; i++) {
      final middle = (inside + outside) / 2;
      if (_distanceToCore(direction * middle) <= rounding) {
        inside = middle;
      } else {
        outside = middle;
      }
    }
    return inside;
  }

  static double _distanceToCore(Offset point) {
    var outsideAnyEdge = false;
    var nearest = double.infinity;
    for (var i = 0; i < 3; i++) {
      final a = _corners[i], b = _corners[(i + 1) % 3];
      final edge = b - a;
      // The corners go clockwise on screen, so outside is to the left.
      if (edge.dx * (point.dy - a.dy) - edge.dy * (point.dx - a.dx) < 0) {
        outsideAnyEdge = true;
      }
      final t =
          (((point - a).dx * edge.dx + (point - a).dy * edge.dy) /
                  edge.distanceSquared)
              .clamp(0.0, 1.0);
      nearest = math.min(nearest, (point - (a + edge * t)).distance);
    }
    return outsideAnyEdge ? nearest : 0;
  }

  @override
  double get hatY => -0.78;
  @override
  double get hatWidth => 0.8;
  @override
  double get neckY => 0.2;
  @override
  double get shadowWidth => 1.7;

  @override
  Path outline(double radius) {
    // An arc around each corner, joined by the straight sides.
    final path = Path();
    for (var i = 0; i < 3; i++) {
      path.arcTo(
        Rect.fromCircle(
          center: _corners[i] * radius,
          radius: rounding * radius,
        ),
        _cornerAngles[i] - math.pi / 3,
        2 * math.pi / 3,
        false,
      );
    }
    return path..close();
  }
}
