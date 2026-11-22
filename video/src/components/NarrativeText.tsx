// Centered white text lines on black, each revealed with a soft rise.
import React from "react";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../anim";
import { theme } from "../theme";

export type Line = {
  text: React.ReactNode;
  from: number;
  to: number;
  size?: number;
  weight?: number;
  color?: string;
  /** Extra scale-up for an emphasised line. */
  emphasis?: boolean;
};

export const NarrativeText: React.FC<{ lines: Line[]; gap?: number }> = ({ lines, gap = 28 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const visible = lines.filter((l) => frame >= l.from - 1 && frame <= l.to);
  return (
    <AbsoluteFill style={{ background: "#000", alignItems: "center", justifyContent: "center", flexDirection: "column", gap }}>
      {visible.map((l, i) => {
        const s = spring({ frame: frame - l.from, fps, config: { damping: 200 }, durationInFrames: 18 });
        const out = ip(frame, [l.to - 8, l.to], [1, 0]);
        const emph = l.emphasis ? spring({ frame: frame - l.from - 4, fps, config: { damping: 12, mass: 0.7 } }) : 0;
        return (
          <div
            key={i}
            style={{
              fontFamily: theme.font,
              fontSize: l.size ?? 84,
              fontWeight: l.weight ?? 600,
              color: l.color ?? "#fff",
              letterSpacing: -1.5,
              textAlign: "center",
              maxWidth: 1500,
              lineHeight: 1.15,
              opacity: s * out,
              filter: `blur(${(1 - s) * 8}px)`,
              transform: `translateY(${(1 - s) * 28}px) scale(${0.96 + 0.04 * s + emph * 0.1})`,
            }}
          >
            {l.text}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
