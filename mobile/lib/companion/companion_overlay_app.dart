import 'dart:async';

import 'package:flutter/widgets.dart';

import 'companion_character.dart';
import 'companion_movement.dart';
import 'companion_state.dart';
import 'companion_window.dart';

enum SwipeDirection { left, right }

/// Classifies the end of a horizontal drag as a dismiss swipe, or null for a
/// small drag that should snap back. [distance] is in logical pixels and
/// [velocity] in logical pixels per second.
SwipeDirection? classifySwipe({
  required double distance,
  required double velocity,
}) {
  const minVelocity = 400.0;
  const minDistance = 32.0;
  if (velocity.abs() >= minVelocity) {
    return velocity < 0 ? SwipeDirection.left : SwipeDirection.right;
  }
  if (distance.abs() >= minDistance) {
    return distance < 0 ? SwipeDirection.left : SwipeDirection.right;
  }
  return null;
}

/// Root widget of the overlay engine. It runs inside the small native window
/// and decides when the companion enters, reacts, and leaves.
class CompanionOverlayApp extends StatefulWidget {
  const CompanionOverlayApp({super.key, this.window});

  final CompanionWindow? window;

  @override
  State<CompanionOverlayApp> createState() => _CompanionOverlayAppState();
}

class _CompanionOverlayAppState extends State<CompanionOverlayApp>
    with SingleTickerProviderStateMixin {
  late final _window = widget.window ?? CompanionWindow();
  CompanionMovementController? _movement;
  var _state = CompanionState.hidden;
  var _facing = CompanionFacing.left;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_enter());
  }

  Future<void> _enter() async {
    final layout = await _window.getLayout();
    if (!mounted) return;
    final movement = _movement = CompanionMovementController(
      window: _window,
      layout: layout,
      vsync: this,
    );
    _window.onLayoutChanged(movement.updateLayout);
    setState(() {
      _state = CompanionState.entering;
      _facing = CompanionFacing.left;
    });
    await movement.walkTo(movement.restX);
    if (mounted && _state == CompanionState.entering) {
      setState(() => _state = CompanionState.idle);
    }
  }

  Future<void> _onTap() async {
    if (_state != CompanionState.idle) return;
    setState(() => _state = CompanionState.reacting);
    await _window.showAlert(title: 'IXLand', message: 'Hello world');
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted && _state == CompanionState.reacting) {
      setState(() => _state = CompanionState.idle);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_acceptsGestures) return;
    setState(() => _dragDistance += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_acceptsGestures) return;
    final direction = classifySwipe(
      distance: _dragDistance,
      velocity: details.primaryVelocity ?? 0,
    );
    setState(() => _dragDistance = 0);
    if (direction != null) unawaited(_exit(direction));
  }

  bool get _acceptsGestures =>
      _state != CompanionState.hidden && _state != CompanionState.exiting;

  Future<void> _exit(SwipeDirection direction) async {
    final movement = _movement;
    if (movement == null) return;
    final left = direction == SwipeDirection.left;
    setState(() {
      _state = CompanionState.exiting;
      _facing = left ? CompanionFacing.left : CompanionFacing.right;
    });
    await movement.walkTo(
      movement.offscreenX(left: left),
      speed: movement.speed * 4,
    );
    if (!mounted) return;
    setState(() => _state = CompanionState.hidden);
    await _window.close();
  }

  @override
  void dispose() {
    _movement?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        button: true,
        label: 'IXLand companion. Tap to talk. Swipe sideways to dismiss.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Transform.translate(
            // Follow the finger a little inside the window as drag feedback.
            offset: Offset(_dragDistance.clamp(-16.0, 16.0), 0),
            child: CompanionCharacter(state: _state, facing: _facing),
          ),
        ),
      ),
    );
  }
}
