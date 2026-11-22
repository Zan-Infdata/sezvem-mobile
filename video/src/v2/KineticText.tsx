// Cinematic narrative text for v2: words rise out of a blur one after another,
// accent words in brand green, and a slow push-in on the whole card.
import React from "react";
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";
import { Cue, LEVEL, Sfx } from "./Sfx";

export type Segment = string | { text: string; accent?: boolean };

export type KLine = {
  segments: Segment[];
  from: number;
  to: number;
  size?: number;
  weight?: number;
  color?: string;
  /** Scale pop and a low hit for the key line. */
  emphasis?: boolean;
  /** Frames between words. */
  stagger?: number;
};

const words = (segs: Segment[]) =>
  segs.flatMap((s) => {
    const text = typeof s === "string" ? s : s.text;
    const accent = typeof s === "string" ? false : !!s.accent;
    return text.split(/(\s+)/).filter((w) => w.length).map((w) => ({ w, accent }));
  });

export const KineticText: React.FC<{ lines: KLine[]; duration: number; gap?: number; sound?: boolean }> = ({
  lines,
  duration,
  gap = 22,
  sound = true,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const push = interpolate(frame, [0, duration], [1, 1.035]);
  const cues: Cue[] = sound
    ? lines.flatMap((l) => [
        { at: l.from, name: "whoosh_soft" as const, volume: LEVEL.transition * 0.8 },
        ...(l.emphasis ? [{ at: l.from + 3, name: "hit" as const, volume: LEVEL.impact * 0.6 }] : []),
      ])
    : [];
  return (
    <AbsoluteFill style={{ background: "#000", alignItems: "center", justifyContent: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap, transform: `scale(${push})` }}>
        {lines
          .filter((l) => frame >= l.from - 1 && frame <= l.to)
          .map((l, li) => {
            const out = interpolate(frame, [l.to - 10, l.to], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.in(Easing.cubic) });
            const emph = l.emphasis ? spring({ frame: frame - l.from - 6, fps, config: { damping: 14, mass: 0.8 } }) : 0;
            let wi = 0;
            return (
              <div
                key={li}
                style={{
                  fontFamily: theme.font,
                  fontSize: l.size ?? 88,
                  fontWeight: l.weight ?? 600,
                  color: l.color ?? "#fff",
                  letterSpacing: "-0.025em",
                  lineHeight: 1.12,
                  textAlign: "center",
                  maxWidth: 1560,
                  opacity: out,
                  filter: `blur(${(1 - out) * 10}px)`,
                  transform: `translateY(${(1 - out) * -16}px) scale(${1 + emph * 0.06})`,
                  whiteSpace: "pre-wrap",
                }}
              >
                {words(l.segments).map((w, i) => {
                  if (/^\s+$/.test(w.w)) return <span key={i}>{w.w}</span>;
                  const s = spring({ frame: frame - l.from - wi++ * (l.stagger ?? 3), fps, config: { damping: 200 }, durationInFrames: 20 });
                  return (
                    <span
                      key={i}
                      style={{
                        display: "inline-block",
                        opacity: s,
                        filter: `blur(${(1 - s) * 12}px)`,
                        transform: `translateY(${(1 - s) * 34}px)`,
                        color: w.accent ? theme.brand : undefined,
                        textShadow: w.accent ? `0 0 ${30 * s}px rgba(30,158,106,0.45)` : undefined,
                      }}
                    >
                      {w.w}
                    </span>
                  );
                })}
              </div>
            );
          })}
      </div>
      <Sfx cues={cues} />
    </AbsoluteFill>
  );
};
