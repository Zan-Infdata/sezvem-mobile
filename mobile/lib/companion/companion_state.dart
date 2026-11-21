/// What the companion is doing. The character widget picks its looping
/// animation from this state. The movement controller only decides where the
/// window is.
enum CompanionState { hidden, entering, idle, walking, reacting, exiting }

enum CompanionFacing { left, right }

enum CompanionMood { normal, sad }
