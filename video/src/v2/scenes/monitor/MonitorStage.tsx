// Shared stage for the two monitor scenes: backdrop, camera push, beats and alerts.
import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { theme } from "../../../theme";
import { Cue, LEVEL, Sfx } from "../../Sfx";
import { ReadoutV2 } from "./ReadoutV2";
import { BEATS, FPS, stateAt, T_CRIT, T_WARN } from "./sim";

const STATE_GLOW = { normal: "rgba(74,222,128,0.07)", warning: "rgba(251,146,60,0.12)", critical: "rgba(239,68,68,0.14)" };

export const MonitorStage: React.FC<{
  simStart: number;
  duration: number;
  zoom: [number, number];
  drift?: number;
}> = ({ simStart, duration, zoom, drift = 0 }) => {
  const frame = useCurrentFrame();
  const t = simStart + frame / FPS;
  const simEnd = simStart + duration / FPS;
  const ease = Easing.inOut(Easing.sin);
  const z = interpolate(frame, [0, duration], zoom, { easing: ease });
  const y = interpolate(frame, [0, duration], [0, -drift], { easing: ease });

  // One-time ring flash when a threshold is crossed.
  const since = (tc: number) => (t >= tc ? (t - tc) * FPS : Infinity);
  const sw = since(T_WARN);
  const sc = since(T_CRIT);
  const fw = sw < 24 ? 1 - sw / 24 : 0;
  const fc = sc < 30 ? 1 - sc / 30 : 0;
  const flash = Math.max(fw, fc);
  const flashColor = fc > 0 ? theme.critical : theme.warning;

  const frameOf = (ts: number) => Math.round((ts - simStart) * FPS);
  const cues: Cue[] = [];
  for (const b of BEATS) {
    if (b < simStart || b > simEnd) continue;
    const f = frameOf(b);
    if (f < 4 || f > duration - 6) continue;
    const st = stateAt(b);
    cues.push({ at: f, name: st === "critical" ? "beep_crit" : st === "warning" ? "beep_warn" : "beep_normal", volume: LEVEL.monitor });
  }
  if (T_WARN >= simStart && T_WARN < simEnd) cues.push({ at: frameOf(T_WARN), name: "alert_warn", volume: LEVEL.alert });
  if (T_CRIT >= simStart && T_CRIT < simEnd) cues.push({ at: frameOf(T_CRIT), name: "alert_crit", volume: LEVEL.alert });

  return (
    <AbsoluteFill style={{ background: `radial-gradient(ellipse at 50% 50%, #14181d 0%, ${theme.pageBg} 60%, #060708 100%)` }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle at 50% 52%, ${STATE_GLOW[stateAt(t)]} 0%, transparent 45%)` }} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <div style={{ transform: `translateY(${y}px) scale(${z})` }}>
          <ReadoutV2 t={t} flash={flash} flashColor={flashColor} />
        </div>
      </AbsoluteFill>
      <Sfx cues={cues} />
    </AbsoluteFill>
  );
};
