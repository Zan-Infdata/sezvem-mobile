import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../companion_state.dart';

/// Every animation a companion style must show.
///
/// Adding a value here makes the style test fail for each style that doesn't
/// draw it yet. Give [CompanionPose] a field for it and an [CompanionPose.example].
enum CompanionAnimation {
  /// Breathing loop while standing still.
  idle,

  /// Step cycle while the window moves.
  walk,

  /// Eyes closing and opening.
  blink,

  /// Squash and stretch after a tap.
  bounce,

  /// Jump with one backwards spin.
  backflip,

  /// Sad expression.
  sad,

  /// Growing while held.
  inflate,
}

/// The progress of every [CompanionAnimation] for one frame.
///
/// Values are normalized so each style maps them to its own art, whether it
/// draws with a canvas, plays sprite sheet frames, or drives a Rive state
/// machine. Several animations can be active at once, such as blinking while
/// walking and sad.
@immutable
class CompanionPose {
  const CompanionPose({
    this.idle = 0,
    this.walk = 0,
    this.walking = false,
    this.blink = 0,
    this.bounce = 0,
    this.backflip = 0,
    this.sad = 0,
    this.inflate = 1,
    this.facing = CompanionFacing.left,
  });

  /// A pose with only [animation] active at a clearly visible point.
  factory CompanionPose.example(CompanionAnimation animation) =>
      switch (animation) {
        CompanionAnimation.idle => const CompanionPose(idle: 0.25),
        CompanionAnimation.walk => const CompanionPose(
          walking: true,
          walk: 0.25,
        ),
        CompanionAnimation.blink => const CompanionPose(blink: 1),
        CompanionAnimation.bounce => const CompanionPose(bounce: 0.5),
        CompanionAnimation.backflip => const CompanionPose(backflip: 0.5),
        CompanionAnimation.sad => const CompanionPose(sad: 1),
        CompanionAnimation.inflate => const CompanionPose(inflate: 1.8),
      };

  /// Idle loop phase from 0 to 1. It repeats while the companion stands.
  final double idle;

  /// Walk cycle phase from 0 to 1. It repeats while [walking].
  final double walk;

  /// Whether the companion is moving across the screen.
  final bool walking;

  /// Eyelid closure, 0 open to 1 closed.
  final double blink;

  /// Bounce progress from 0 to 1. Strongest at 0.5.
  final double bounce;

  /// Backflip progress from 0 to 1. Highest and upside down at 0.5.
  final double backflip;

  /// Sadness, 0 normal to 1 fully sad.
  final double sad;

  /// Size relative to normal, from 1 to [CompanionStyle.maxInflate].
  final double inflate;

  /// Which way the companion looks and walks.
  final CompanionFacing facing;

  @override
  bool operator ==(Object other) =>
      other is CompanionPose &&
      other.idle == idle &&
      other.walk == walk &&
      other.walking == walking &&
      other.blink == blink &&
      other.bounce == bounce &&
      other.backflip == backflip &&
      other.sad == sad &&
      other.inflate == inflate &&
      other.facing == facing;

  @override
  int get hashCode => Object.hash(
    idle,
    walk,
    walking,
    blink,
    bounce,
    backflip,
    sad,
    inflate,
    facing,
  );
}

/// One choice for a [CompanionSlot], such as a particular hat.
@immutable
class CompanionOption {
  const CompanionOption({required this.id, required this.name});

  /// Stable ID saved in settings. Never change it after release.
  final String id;

  /// Name shown in settings.
  final String name;
}

/// Something a person can customize on a style, such as its hat.
@immutable
class CompanionSlot {
  const CompanionSlot({
    required this.id,
    required this.name,
    required this.options,
  });

  /// Stable ID saved in settings. Never change it after release.
  final String id;

  /// Name shown in settings.
  final String name;

  /// The choices, in settings order. The first one is the default.
  final List<CompanionOption> options;
}

/// A look for the companion.
///
/// A style draws one frame from a [CompanionPose] and must show every
/// [CompanionAnimation]. It draws inside the overlay window, standing at the
/// bottom center, in logical pixels. The window is [restSize] most of the time
/// and grows upward to [backflipSize] or [inflateSize] only during those
/// animations, so each one has to fit its size. Register new styles in
/// `companion_styles.dart`.
abstract class CompanionStyle {
  const CompanionStyle();

  /// Window size while no large animation runs.
  static const restSize = Size(96, 96);

  /// Window size during a backflip: 64 more above the companion.
  static const backflipSize = Size(96, 160);

  /// Window size while inflating.
  static const inflateSize = Size(136, 136);

  /// The largest [CompanionPose.inflate] value.
  static const maxInflate = 1.8;

  /// Stable ID saved in settings. Never change it after release.
  String get id;

  /// Name shown in settings.
  String get name;

  /// What a person can customize on this style. Empty for a fixed style.
  List<CompanionSlot> get slots => const [];

  /// The chosen option ID for each slot in [slots].
  Map<String, String> get choices => const {};

  /// This style with [choices] applied, mapping slot IDs to option IDs.
  /// Slots that are missing or unknown keep their current option.
  CompanionStyle customize(Map<String, String> choices) => this;

  void paint(Canvas canvas, Size size, CompanionPose pose);
}
