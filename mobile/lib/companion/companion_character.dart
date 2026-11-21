import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'companion_animator.dart';
import 'companion_state.dart';

/// The animated companion character.
///
/// One-shot clips, mood, and size come from [animator]. The widget adds the
/// ambient loops itself: bobbing, walking sway, and blinking. It never moves
/// itself on screen. The current look is a drawn placeholder. A sprite sheet or
/// Rive renderer can replace [CompanionPainter] while keeping the same pose.
class CompanionCharacter extends StatefulWidget {
  const CompanionCharacter({super.key, required this.animator});

  final CompanionAnimator animator;

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
  final _random = math.Random();
  Timer? _blinkTimer;
  CompanionState? _loopState;

  @override
  void initState() {
    super.initState();
    widget.animator.addListener(_syncLoops);
    _syncLoops();
  }

  @override
  void didUpdateWidget(CompanionCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animator != widget.animator) {
      oldWidget.animator.removeListener(_syncLoops);
      widget.animator.addListener(_syncLoops);
      _syncLoops();
    }
  }

  CompanionState get _state => widget.animator.state;

  bool get _isMoving => switch (_state) {
    CompanionState.entering ||
    CompanionState.walking ||
    CompanionState.exiting => true,
    _ => false,
  };

  void _syncLoops() {
    if (_loopState == _state) return;
    _loopState = _state;
    if (_state == CompanionState.hidden) {
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
        if (mounted && _state != CompanionState.hidden) _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    widget.animator.removeListener(_syncLoops);
    _blinkTimer?.cancel();
    _cycle.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animator = widget.animator;
    return AnimatedBuilder(
      animation: Listenable.merge([animator, _cycle, _blink]),
      builder: (context, _) {
        if (animator.state == CompanionState.hidden) {
          return const SizedBox.expand();
        }
        final phase = _cycle.value * 2 * math.pi;
        // Bob less while sad.
        final bobAmount = 1 - animator.sadness * 0.7;
        return CustomPaint(
          size: Size.infinite,
          painter: CompanionPainter(
            CompanionPose(
              bob:
                  (_isMoving
                      ? math.sin(phase).abs()
                      : (math.sin(phase) + 1) / 2) *
                  bobAmount,
              tilt: _isMoving ? math.sin(phase) * 0.08 : 0,
              blink: _blink.value,
              squash: animator.squash,
              flip: animator.flipAngle,
              jump: animator.jump,
              sadness: animator.sadness,
              scale: animator.scale,
              facing: animator.facing,
            ),
          ),
        );
      },
    );
  }
}

/// One frame of the character's look. Values are normalized so a renderer can
/// map them to its own art.
@immutable
class CompanionPose {
  const CompanionPose({
    required this.bob,
    required this.tilt,
    required this.blink,
    required this.squash,
    required this.facing,
    this.flip = 0,
    this.jump = 0,
    this.sadness = 0,
    this.scale = 1,
  });

  /// Vertical lift, 0 resting to 1 highest.
  final double bob;

  /// Sway in radians while walking.
  final double tilt;

  /// Eyelid closure, 0 open to 1 closed.
  final double blink;

  /// Bounce squash, 0 none to 1 fully squashed.
  final double squash;

  /// Backflip rotation in radians.
  final double flip;

  /// Backflip jump height, 0 on the ground to 1 at the top.
  final double jump;

  /// Sad expression, 0 normal to 1 fully sad.
  final double sadness;

  /// Size relative to normal.
  final double scale;

  final CompanionFacing facing;

  @override
  bool operator ==(Object other) =>
      other is CompanionPose &&
      other.bob == bob &&
      other.tilt == tilt &&
      other.blink == blink &&
      other.squash == squash &&
      other.flip == flip &&
      other.jump == jump &&
      other.sadness == sadness &&
      other.scale == scale &&
      other.facing == facing;

  @override
  int get hashCode =>
      Object.hash(bob, tilt, blink, squash, flip, jump, sadness, scale, facing);
}

/// Placeholder art: a round body with two eyes that look where it faces.
///
/// The character keeps a fixed size in logical pixels and stands at the bottom
/// center of its window, so the window can grow for a jump or inflation
/// without the character moving.
class CompanionPainter extends CustomPainter {
  const CompanionPainter(this.pose);

  /// Body radius at normal size, in logical pixels.
  static const bodyRadius = 30.0;

  /// Distance from the bottom of the window to the ground line.
  static const groundInset = 10.0;

  /// Backflip jump height in logical pixels.
  static const jumpHeight = 56.0;

  final CompanionPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = bodyRadius * pose.scale;
    final groundY = size.height - groundInset;
    final direction = pose.facing == CompanionFacing.left ? -1.0 : 1.0;
    final lift = pose.bob * radius * 0.18 + pose.jump * jumpHeight;
    final center = Offset(size.width / 2, groundY - radius - lift);

    // The shadow shrinks as the character leaves the ground.
    final shadow = 1 - pose.jump * 0.6;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, groundY),
        width: radius * (1.6 - pose.bob * 0.3) * shadow,
        height: radius * 0.28 * shadow,
      ),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    // Spin a backflip around the body center: backwards relative to facing.
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pose.flip * direction);
    // Sway and squash pivot on the feet.
    canvas.translate(0, radius);
    canvas.rotate(pose.tilt * direction);
    canvas.scale(1 + pose.squash * 0.18, 1 - pose.squash * 0.18);
    canvas.translate(0, -radius);

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
              pose.sadness,
            )!,
            Color.lerp(
              const Color(0xFF00897B),
              const Color(0xFF5C6BC0),
              pose.sadness,
            )!,
          ],
        ).createShader(body),
    );

    final look = direction * radius * 0.12 * (1 - pose.sadness);
    final dark = Paint()..color = const Color(0xFF263238);
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(
        side * radius * 0.36 + look,
        -radius * (0.12 - pose.sadness * 0.06),
      );
      final eyeHeight =
          radius * 0.5 * (1 - pose.blink * 0.9) * (1 - pose.sadness * 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: radius * 0.38, height: eyeHeight),
        Paint()..color = Colors.white,
      );
      if (pose.blink < 0.6) {
        canvas.drawCircle(
          eye +
              Offset(
                direction * radius * 0.06 * (1 - pose.sadness),
                radius * (0.04 + pose.sadness * 0.06),
              ),
          radius * 0.11,
          dark,
        );
      }
      if (pose.sadness > 0) {
        // Brows that rise toward the middle.
        canvas.drawLine(
          Offset(side * radius * 0.16, -radius * 0.5),
          Offset(side * radius * 0.56, -radius * 0.36),
          Paint()
            ..color = dark.color.withValues(alpha: pose.sadness)
            ..strokeWidth = radius * 0.07
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (pose.sadness > 0) {
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
          ..color = dark.color.withValues(alpha: pose.sadness)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompanionPainter oldDelegate) => oldDelegate.pose != pose;
}
