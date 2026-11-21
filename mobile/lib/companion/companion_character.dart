import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'companion_state.dart';

/// The animated companion character.
///
/// It picks its animation from [state] and [facing] and never moves itself on
/// screen. The current look is a drawn placeholder. A sprite sheet or Rive
/// renderer can replace [CompanionPainter] while keeping this widget's inputs.
class CompanionCharacter extends StatefulWidget {
  const CompanionCharacter({
    super.key,
    required this.state,
    required this.facing,
  });

  final CompanionState state;
  final CompanionFacing facing;

  @override
  State<CompanionCharacter> createState() => _CompanionCharacterState();
}

class _CompanionCharacterState extends State<CompanionCharacter>
    with TickerProviderStateMixin {
  late final _cycle = AnimationController(vsync: this);
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  late final _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final _random = math.Random();
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(CompanionCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimations();
      if (widget.state == CompanionState.reacting) _react.forward(from: 0);
    }
  }

  bool get _isMoving => switch (widget.state) {
    CompanionState.entering ||
    CompanionState.walking ||
    CompanionState.exiting => true,
    _ => false,
  };

  void _syncAnimations() {
    if (widget.state == CompanionState.hidden) {
      _cycle.stop();
      _blinkTimer?.cancel();
      _blinkTimer = null;
      return;
    }
    _cycle.duration = Duration(milliseconds: _isMoving ? 420 : 1800);
    _cycle.repeat();
    if (_blinkTimer == null) _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2000 + _random.nextInt(3000)),
      () async {
        if (!mounted) return;
        await _blink.forward(from: 0);
        if (!mounted) return;
        await _blink.reverse();
        if (mounted && widget.state != CompanionState.hidden) _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _cycle.dispose();
    _blink.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == CompanionState.hidden) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: Listenable.merge([_cycle, _blink, _react]),
      builder: (context, _) {
        final phase = _cycle.value * 2 * math.pi;
        return CustomPaint(
          size: Size.infinite,
          painter: CompanionPainter(
            CompanionPose(
              bob: _isMoving
                  ? math.sin(phase).abs()
                  : (math.sin(phase) + 1) / 2,
              tilt: _isMoving ? math.sin(phase) * 0.08 : 0,
              blink: _blink.value,
              squash: math.sin(_react.value * math.pi),
              facing: widget.facing,
            ),
          ),
        );
      },
    );
  }
}

/// One frame of the character's look. Every value is normalized so a renderer
/// can map it to its own art.
@immutable
class CompanionPose {
  const CompanionPose({
    required this.bob,
    required this.tilt,
    required this.blink,
    required this.squash,
    required this.facing,
  });

  /// Vertical lift, 0 resting to 1 highest.
  final double bob;

  /// Rotation in radians while walking.
  final double tilt;

  /// Eyelid closure, 0 open to 1 closed.
  final double blink;

  /// Tap reaction, 0 none to 1 fully squashed.
  final double squash;
  final CompanionFacing facing;

  @override
  bool operator ==(Object other) =>
      other is CompanionPose &&
      other.bob == bob &&
      other.tilt == tilt &&
      other.blink == blink &&
      other.squash == squash &&
      other.facing == facing;

  @override
  int get hashCode => Object.hash(bob, tilt, blink, squash, facing);
}

/// Placeholder art: a round body with two eyes that look where it faces.
class CompanionPainter extends CustomPainter {
  const CompanionPainter(this.pose);

  final CompanionPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.32;
    final groundY = size.height * 0.9;
    final direction = pose.facing == CompanionFacing.left ? -1.0 : 1.0;
    final lift = pose.bob * radius * 0.18;
    final center = Offset(size.width / 2, groundY - radius - lift);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: radius * (1.6 - pose.bob * 0.3),
        height: radius * 0.28,
      ),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy + radius);
    canvas.rotate(pose.tilt * direction);
    canvas.scale(1 + pose.squash * 0.18, 1 - pose.squash * 0.18);
    canvas.translate(0, -radius);

    final body = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF80CBC4), Color(0xFF00897B)],
        ).createShader(body),
    );

    final look = direction * radius * 0.12;
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(side * radius * 0.36 + look, -radius * 0.12);
      final eyeHeight = radius * 0.5 * (1 - pose.blink * 0.9);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: radius * 0.38, height: eyeHeight),
        Paint()..color = Colors.white,
      );
      if (pose.blink < 0.6) {
        canvas.drawCircle(
          eye + Offset(direction * radius * 0.06, radius * 0.04),
          radius * 0.11,
          Paint()..color = const Color(0xFF263238),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompanionPainter oldDelegate) => oldDelegate.pose != pose;
}
