// Central timeline: every scene and its duration in frames (30 fps).
export const TIMELINE = {
  intro: 195,
  pairing: 150,
  monitor: 75,
  irregular: 45,
  rise: 130,
  detect: 195,
  critical: 230,
  goodCard: 45,
  good: 255,
  philosophy: 105,
  customize: 150,
  finale: 210,
} as const;

export const TOTAL = Object.values(TIMELINE).reduce((a, b) => a + b, 0);
