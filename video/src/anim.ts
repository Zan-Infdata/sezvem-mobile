import { Easing, interpolate } from "remotion";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Clamped, eased interpolation. */
export const ip = (f: number, input: number[], output: number[], easing = Easing.inOut(Easing.cubic)) =>
  interpolate(f, input, output, { ...clamp, easing });

/** Fade in over [a, a+d] and out over [b-d, b]. */
export const fadeInOut = (f: number, a: number, b: number, d = 10) =>
  Math.min(ip(f, [a, a + d], [0, 1]), ip(f, [b - d, b], [1, 0]));

/** Keyframed value: each key holds until the next and eases over `ease` frames before it. */
export type Key<T> = { at: number } & T;
