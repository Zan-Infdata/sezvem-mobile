// Deterministic simulated WHOOP heart rate for the v2 monitor scenes.
// Simulated time is continuous across Monitor -> "Any irregularities?" -> Rise.
import { restingHr, Thresholds } from "../../../components/HeartRateMonitor";
import timeline from "../../timeline.json";

export const FPS = timeline.fps;
export const THRESHOLDS: Thresholds = { warning: 100, critical: 115 };

const dur = (id: string) => timeline.scenes.find((s) => s.id === id)!.duration;
/** Rise's frame 0 is this many frames after Monitor's frame 0 (15-frame overlaps included). */
const RISE_OFFSET = dur("monitor") - timeline.transition + dur("irregular") - timeline.transition;

export const MONITOR_SIM_START = 2;
export const RISE_SIM_START = MONITOR_SIM_START + RISE_OFFSET / FPS;

// The rise: +42 bpm eased over RISE_LEN seconds, starting shortly into Rise.
const RISE_AT = RISE_SIM_START + 0.5;
const RISE_LEN = 5;
const smooth = (x: number) => (x <= 0 ? 0 : x >= 1 ? 1 : x * x * (3 - 2 * x));
export const hrAt = (t: number) => restingHr(t) + 42 * smooth((t - RISE_AT) / RISE_LEN);

const DT = 1 / 240;

/** First simulated time the rate reaches `bpm` (latched, so noise can't flicker the state). */
function firstCrossing(bpm: number) {
  for (let t = RISE_AT; t < RISE_AT + RISE_LEN + 2; t += DT) if (hrAt(t) >= bpm) return t;
  return Infinity;
}
export const T_WARN = firstCrossing(THRESHOLDS.warning);
export const T_CRIT = firstCrossing(THRESHOLDS.critical);

export type State = "normal" | "warning" | "critical";
export const stateAt = (t: number): State => (t >= T_CRIT ? "critical" : t >= T_WARN ? "warning" : "normal");

/** Heartbeat times: where the integral of hr/60 crosses a whole number. */
export const BEATS: number[] = (() => {
  const beats: number[] = [];
  let phase = 0;
  for (let t = 0; t < RISE_SIM_START + 10; t += DT) {
    const next = phase + (hrAt(t) / 60) * DT;
    if (Math.floor(next) > Math.floor(phase)) beats.push(t);
    phase = next;
  }
  return beats;
})();

/** 0..1 glow that peaks on each beat and decays. */
export function beatPulse(t: number) {
  let last = -Infinity;
  for (const b of BEATS) {
    if (b > t) break;
    last = b;
  }
  return Math.exp(-(t - last) * 7);
}
