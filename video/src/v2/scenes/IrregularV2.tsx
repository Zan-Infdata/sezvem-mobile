// v2 "Any irregularities?" (60 frames): tense card with a warning-orange trace.
import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { theme } from "../../theme";
import { KineticText } from "../KineticText";

// A short ECG-like stroke that spikes out of a flat line.
const TRACE = "M 0 40 L 150 40 L 175 40 L 190 14 L 205 66 L 220 4 L 236 52 L 250 40 L 420 40";

export const IrregularV2: React.FC = () => {
  const frame = useCurrentFrame();
  const draw = interpolate(frame, [18, 42], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const out = interpolate(frame, [44, 54], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <AbsoluteFill>
      <KineticText duration={60} lines={[{ segments: ["Any irregularities?"], from: 8, to: 54, size: 96 }]} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <svg width={420} height={80} viewBox="0 0 420 80" style={{ transform: "translateY(110px)", opacity: out, overflow: "visible" }}>
          <path
            d={TRACE}
            fill="none"
            stroke={theme.warning}
            strokeWidth={4}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - draw}
            style={{ filter: `drop-shadow(0 0 10px ${theme.warning}aa)` }}
          />
        </svg>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
