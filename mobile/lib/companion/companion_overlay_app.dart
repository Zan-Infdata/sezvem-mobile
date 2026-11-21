import 'dart:async';

import 'package:flutter/widgets.dart';

import 'companion_actions.dart';
import 'companion_animator.dart';
import 'companion_character.dart';
import 'companion_movement.dart';
import 'companion_test_actions.dart';
import 'companion_window.dart';

/// Classifies the end of a drag as a swipe input, or null for a small drag
/// that should snap back. The larger axis decides the direction. [distance] is
/// in logical pixels and [velocity] in logical pixels per second.
CompanionInput? classifySwipe({
  required Offset distance,
  required Offset velocity,
}) {
  const minVelocity = 400.0;
  const minDistance = 32.0;
  final Offset vector;
  if (velocity.distance >= minVelocity) {
    vector = velocity;
  } else if (distance.distance >= minDistance) {
    vector = distance;
  } else {
    return null;
  }
  if (vector.dx.abs() >= vector.dy.abs()) {
    return vector.dx < 0 ? CompanionInput.swipeLeft : CompanionInput.swipeRight;
  }
  return vector.dy < 0 ? CompanionInput.swipeUp : CompanionInput.swipeDown;
}

/// Root widget of the overlay engine. It turns gestures into
/// [CompanionInput]s for the action controller.
class CompanionOverlayApp extends StatefulWidget {
  const CompanionOverlayApp({super.key, this.window, this.actions});

  final CompanionWindow? window;

  /// Defaults to [testCompanionActions].
  final Map<CompanionInput, CompanionAction>? actions;

  @override
  State<CompanionOverlayApp> createState() => _CompanionOverlayAppState();
}

class _CompanionOverlayAppState extends State<CompanionOverlayApp>
    with TickerProviderStateMixin {
  late final _window = widget.window ?? CompanionWindow();
  late final _animator = CompanionAnimator(vsync: this);
  CompanionMovementController? _movement;
  CompanionActionController? _actions;
  Completer<void>? _hold;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final layout = await _window.getLayout();
    if (!mounted) return;
    final movement = _movement = CompanionMovementController(
      window: _window,
      layout: layout,
      vsync: this,
    );
    _window.onLayoutChanged(movement.updateLayout);
    final actions = _actions = CompanionActionController(
      actions: widget.actions ?? testCompanionActions(),
      animator: _animator,
      movement: movement,
      window: _window,
    );
    actions.run(enterFromRight);
  }

  bool _accepts() {
    final actions = _actions;
    return actions != null && !actions.isBusy && !actions.isClosed;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_accepts()) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final input = classifySwipe(
      distance: _drag,
      velocity: details.velocity.pixelsPerSecond,
    );
    setState(() => _drag = Offset.zero);
    if (input != null) _actions?.handle(input);
  }

  void _onHoldStart(LongPressStartDetails details) {
    final hold = _hold = Completer<void>();
    if (_actions?.handle(CompanionInput.hold, released: hold.future) != true) {
      _endHold();
    }
  }

  void _endHold() {
    final hold = _hold;
    _hold = null;
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  @override
  void dispose() {
    _endHold();
    _movement?.dispose();
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        button: true,
        label:
            'IXLand companion. Tap, hold, or swipe in any direction to interact.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _actions?.handle(CompanionInput.tap),
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onLongPressStart: _onHoldStart,
          onLongPressEnd: (_) => _endHold(),
          onLongPressCancel: _endHold,
          child: Transform.translate(
            // Follow the finger a little inside the window as drag feedback.
            offset: Offset(
              _drag.dx.clamp(-16.0, 16.0),
              _drag.dy.clamp(-16.0, 16.0),
            ),
            child: CompanionCharacter(animator: _animator),
          ),
        ),
      ),
    );
  }
}
