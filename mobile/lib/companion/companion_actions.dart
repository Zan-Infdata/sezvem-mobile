import 'dart:async';
import 'dart:ui';

import 'companion_animator.dart';
import 'companion_movement.dart';
import 'companion_state.dart';
import 'companion_window.dart';
import 'styles/companion_style.dart';

/// The gestures the companion understands.
enum CompanionInput { tap, swipeLeft, swipeRight, swipeUp, swipeDown, hold }

/// Something the companion does in response to an input.
///
/// An action is a plain async function. It can call app code and drive the
/// character through [CompanionActionContext]. The companion runs one action at
/// a time and ignores inputs until the running action completes.
typedef CompanionAction = Future<void> Function(CompanionActionContext context);

/// Normal window size in logical pixels. Must match `WINDOW_SIZE_DP` in
/// `CompanionOverlayService.kt`.
final companionWindowSize = CompanionStyle.onScreen(CompanionStyle.restSize);

/// What an action can use while it runs.
class CompanionActionContext {
  CompanionActionContext({
    required this.animator,
    required this.movement,
    required this.window,
    required this.released,
    required void Function() onClose,
    required bool Function() isClosed,
    required Future<void> Function() openChat,
  }) : _onClose = onClose,
       _isClosed = isClosed,
       _openChat = openChat;

  /// Plays animations and sets the state, mood, and facing.
  final CompanionAnimator animator;

  /// Moves the window across the screen.
  final CompanionMovementController movement;

  /// Native window calls such as alerts, sounds, and closing.
  final CompanionWindow window;

  /// Completes when the input ends. For [CompanionInput.hold] that is when the
  /// finger lifts. For every other input it has already completed.
  final Future<void> released;

  final void Function() _onClose;
  final bool Function() _isClosed;
  final Future<void> Function() _openChat;

  bool get isClosed => _isClosed();

  /// Opens the chat with the on-device assistant and completes when the user
  /// closes it. The window fills the screen meanwhile.
  Future<void> openChat() => _openChat();

  /// Grows the window to fit a style box of [size] in design units, such as
  /// [CompanionStyle.backflipSize], while [body] runs. Then it restores the
  /// normal size. The window grows upward from its bottom center, so the character
  /// stays where it is. Keep the window small: it blocks touches to other apps.
  Future<void> withRoom(Size size, Future<void> Function() body) async {
    movement.updateLayout(await window.resize(CompanionStyle.onScreen(size)));
    try {
      await body();
    } finally {
      movement.updateLayout(await window.resize(companionWindowSize));
    }
  }

  /// Removes the companion and ignores all later inputs.
  Future<void> close() async {
    animator.state = CompanionState.hidden;
    _onClose();
    await window.close();
  }
}

/// Maps inputs to actions and runs one action at a time.
class CompanionActionController {
  CompanionActionController({
    required this.actions,
    required this.animator,
    required this.movement,
    required this.window,
    this.openChat = _noChat,
    this.onIdle,
  });

  static Future<void> _noChat() async {}

  final Map<CompanionInput, CompanionAction> actions;
  final CompanionAnimator animator;
  final CompanionMovementController movement;
  final CompanionWindow window;

  /// Shows the chat until the user closes it. Supplied by the overlay app.
  final Future<void> Function() openChat;
  final void Function()? onIdle;

  bool _busy = false;
  bool _closed = false;

  /// Whether an action is running. Inputs are ignored while it is.
  bool get isBusy => _busy;

  bool get isClosed => _closed;

  /// Runs the action mapped to [input]. Returns false if no action is mapped,
  /// another action is running, or the companion has closed. Pass [released]
  /// for inputs that last, such as a hold.
  bool handle(CompanionInput input, {Future<void>? released}) {
    final action = actions[input];
    if (action == null) return false;
    return run(action, released: released);
  }

  /// Runs [action] directly, for sequences such as the entrance that don't
  /// come from an input. Follows the same one-at-a-time rule as [handle].
  bool run(CompanionAction action, {Future<void>? released}) {
    if (_busy || _closed) return false;
    _busy = true;
    final context = CompanionActionContext(
      animator: animator,
      movement: movement,
      window: window,
      released: released ?? Future.value(),
      onClose: () => _closed = true,
      isClosed: () => _closed,
      openChat: openChat,
    );
    unawaited(_run(action, context));
    return true;
  }

  /// Ignores all later inputs and stops the running action from touching the
  /// companion when it ends. Call it before disposing the animator.
  void dispose() => _closed = true;

  Future<void> _run(
    CompanionAction action,
    CompanionActionContext context,
  ) async {
    try {
      await action(context);
    } finally {
      _busy = false;
      if (!_closed) {
        animator.state = CompanionState.idle;
        onIdle?.call();
      }
    }
  }
}

/// Built-in action: walks in from the right edge to its resting spot.
Future<void> enterFromRight(CompanionActionContext context) async {
  context.animator
    ..facing = CompanionFacing.left
    ..state = CompanionState.entering;
  await context.movement.walkTo(context.movement.restX);
}

/// Built-in action: walks to [uv] in 0 to 1 screen coordinates, facing the
/// way it walks. The main app requests this through `CompanionOverlay.moveTo`.
Future<void> walkToUv(CompanionActionContext context, Offset uv) async {
  final movement = context.movement;
  final target = movement.pointForUv(uv);
  if (target.dx != movement.x) {
    context.animator.facing = target.dx < movement.x
        ? CompanionFacing.left
        : CompanionFacing.right;
  }
  context.animator.state = CompanionState.walking;
  await movement.walkToPoint(target);
}
