import 'dart:async';
import 'dart:ui';
import 'companion_actions.dart';
import 'companion_state.dart';
import 'styles/companion_style.dart';

/// Actions for the six companion inputs. Tap opens the chat. The others are
/// tests. Each swipe down plays the next of [moodShowcase].
///
/// Replace these with real behavior by mapping an input to another
/// [CompanionAction].
Map<CompanionInput, CompanionAction> testCompanionActions() {
  var nextMood = 0;
  return {
    CompanionInput.tap: chat,
    CompanionInput.swipeLeft: (context) => leave(context, toLeft: true),
    CompanionInput.swipeRight: (context) => leave(context, toLeft: false),
    CompanionInput.swipeUp: backflip,
    CompanionInput.swipeDown: (context) =>
        moodShowcase[nextMood++ % moodShowcase.length](context),
    CompanionInput.hold: inflate,
  };
}

/// Sadness and then each emotion, in the order swiping down plays them.
final moodShowcase = <CompanionAction>[
  beSad,
  for (final emotion in CompanionEmotion.values)
    (context) => context.animator.emote(emotion),
];

/// How much faster than walking the companion moves to and from the chat.
const chatMoveSpeedFactor = 8.0;

/// Hurries to the top-right corner, opens the chat with the on-device
/// assistant there, and hurries back after the chat closes.
Future<void> chat(CompanionActionContext context) async {
  final movement = context.movement;
  final home = Offset(movement.x, movement.y);
  await _hurryTo(context, movement.chatHeadPoint);
  context.animator.state = CompanionState.idle;
  await context.openChat();
  await _hurryTo(context, home);
}

Future<void> _hurryTo(CompanionActionContext context, Offset target) async {
  final movement = context.movement;
  if (target.dx != movement.x) {
    context.animator.facing = target.dx < movement.x
        ? CompanionFacing.left
        : CompanionFacing.right;
  }
  context.animator.state = CompanionState.walking;
  await movement.walkToPoint(
    target,
    speed: movement.speed * chatMoveSpeedFactor,
  );
}

/// Runs off the left or right edge and closes the companion.
Future<void> leave(
  CompanionActionContext context, {
  required bool toLeft,
}) async {
  context.animator
    ..facing = toLeft ? CompanionFacing.left : CompanionFacing.right
    ..state = CompanionState.exiting;
  await context.movement.walkTo(
    context.movement.offscreenX(left: toLeft),
    speed: context.movement.speed * 4,
  );
  await context.close();
}

/// Jumps and spins backwards once.
Future<void> backflip(CompanionActionContext context) async {
  context.animator.state = CompanionState.reacting;
  await context.withRoom(
    CompanionStyle.backflipSize,
    context.animator.backflip,
  );
}

/// Looks sad for two seconds. Other inputs are ignored meanwhile.
Future<void> beSad(CompanionActionContext context) async {
  await context.animator.setMood(CompanionMood.sad);
  await Future<void>.delayed(const Duration(seconds: 2));
  await context.animator.setMood(CompanionMood.normal);
}

/// How large the hold action lets the character grow.
const inflateLimit = CompanionStyle.maxInflate;

/// How long it takes to grow to [inflateLimit].
const inflateDuration = Duration(seconds: 2);

/// Grows with an inflating sound while held, up to [inflateLimit], and
/// shrinks back when released.
Future<void> inflate(CompanionActionContext context) async {
  await context.withRoom(CompanionStyle.inflateSize, () async {
    context.animator.state = CompanionState.reacting;
    unawaited(context.window.playInflateSound(inflateDuration));
    // Stop the sound when the limit is reached or the finger lifts.
    await Future.any([
      context.animator.inflateTo(inflateLimit, inflateDuration),
      context.released,
    ]);
    unawaited(context.window.stopSound());
    await context.released;
    await context.animator.deflate();
  });
}
