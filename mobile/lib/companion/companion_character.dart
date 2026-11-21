import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'companion_animator.dart';
import 'companion_state.dart';
import 'styles/companion_style.dart';

/// The animated companion character.
///
/// One-shot clips, mood, and size come from [animator]. The widget runs the
/// looping animations itself: the idle and walk cycles and blinking. It turns
/// both into a [CompanionPose] and lets [style] draw it. It never moves itself
/// on screen.
class CompanionCharacter extends StatefulWidget {
  const CompanionCharacter({
    super.key,
    required this.animator,
    required this.style,
  });

  final CompanionAnimator animator;
  final CompanionStyle style;

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
        final moving = _isMoving;
        return CustomPaint(
          size: Size.infinite,
          painter: _StylePainter(
            widget.style,
            CompanionPose(
              idle: moving ? 0 : _cycle.value,
              walk: moving ? _cycle.value : 0,
              walking: moving,
              blink: _blink.value,
              bounce: animator.bounceProgress,
              backflip: animator.backflipProgress,
              sad: animator.sadness,
              inflate: animator.scale,
              facing: animator.facing,
            ),
          ),
        );
      },
    );
  }
}

class _StylePainter extends CustomPainter {
  const _StylePainter(this.style, this.pose);

  final CompanionStyle style;
  final CompanionPose pose;

  @override
  void paint(Canvas canvas, Size size) => style.paint(canvas, size, pose);

  @override
  bool shouldRepaint(_StylePainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.pose != pose;
}
