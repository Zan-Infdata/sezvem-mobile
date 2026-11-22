// Live heart-rate readout, centred on a dark page.
import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../anim";
import { HeartRateMonitor, restingHr } from "../components/HeartRateMonitor";
import { theme } from "../theme";

// Simulated timeline in seconds: the rise starts at RISE_START and lasts RISE_LEN.
export const RISE_START = 4.6;
const RISE_LEN = 3.6;
const smooth = (x: number) => (x <= 0 ? 0 : x >= 1 ? 1 : x * x * (3 - 2 * x));
export const risingHr = (t: number) => restingHr(t) + 44 * smooth((t - RISE_START) / RISE_LEN);

export const Monitor: React.FC<{ simStart: number; rising?: boolean }> = ({ simStart, rising = false }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = simStart + frame / fps;
  const zoom = rising ? ip(frame, [0, 120], [1, 1.06]) : ip(frame, [0, 75], [0.97, 1]);
  return (
    <AbsoluteFill style={{ background: theme.pageBg, alignItems: "center", justifyContent: "center" }}>
      <div style={{ transform: `scale(${zoom})` }}>
        <HeartRateMonitor t={t} hrAt={rising ? risingHr : restingHr} width={1180} />
      </div>
    </AbsoluteFill>
  );
};
