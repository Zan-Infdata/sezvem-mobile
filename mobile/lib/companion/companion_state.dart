/// What the companion is doing. The character widget picks its looping
/// animation from this state. The movement controller only decides where the
/// window is.
enum CompanionState { hidden, entering, idle, walking, reacting, exiting }

enum CompanionFacing { left, right }

enum CompanionMood { normal, sad }

/// A short emotional reaction. The animator plays one at a time, for a few
/// seconds, on top of the current mood.
enum CompanionEmotion { surprised, laughing, scared, confused, happy }
