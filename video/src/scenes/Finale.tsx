// "Now", the logo reveal, Kevin laughing, and the inverse circle close.
import React from "react";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../anim";
import { CircleMaskOut } from "../components/CircleMaskOut";
import { Kevin } from "../components/Kevin";
import { SezvemLogo } from "../components/Logo";
import { theme } from "../theme";

export const FINALE = { logoAt: 32, kevinAt: 62, laughAt: 84, maskAt: 186, maskLen: 22 };

export const Finale: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const now = Math.min(ip(frame, [0, 8], [0, 1]), ip(frame, [22, 30], [1, 0]));
  const logo = spring({ frame: frame - FINALE.logoAt, fps, config: { damping: 18, mass: 0.9 } });
  const kx = ip(frame, [FINALE.kevinAt, FINALE.laughAt], [-120, 960]);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", fontFamily: theme.font, fontSize: 150, fontWeight: 700, color: "#fff", letterSpacing: -4, opacity: now, transform: `scale(${0.94 + 0.06 * now})` }}>
        Now
      </AbsoluteFill>
      {frame >= FINALE.logoAt ? (
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
          <SezvemLogo width={760} style={{ opacity: logo, transform: `translateY(${-90 + (1 - logo) * 30}px) scale(${0.86 + 0.14 * logo})`, filter: "drop-shadow(0 30px 80px rgba(30,158,106,0.35))" }} />
        </AbsoluteFill>
      ) : null}
      {frame >= FINALE.kevinAt ? (
        <Kevin x={kx} y={960} radius={78} walking={frame < FINALE.laughAt} facing={1} moods={[{ at: FINALE.laughAt, emotion: "laughing" }]} />
      ) : null}
      <CircleMaskOut from={FINALE.maskAt} duration={FINALE.maskLen} />
    </AbsoluteFill>
  );
};
