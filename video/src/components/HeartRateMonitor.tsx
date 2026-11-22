// Heart-rate readout after the reference UI's div.readout: dark surface,
// status word, big mono figure, bounds line and a live trace.
import React from "react";
import { theme } from "../theme";

export type Thresholds = { warning: number; critical: number };
export type HrState = "normal" | "warning" | "critical";

export const DEMO_THRESHOLDS: Thresholds = { warning: 100, critical: 115 };

export const stateOf = (bpm: number, th: Thresholds): HrState =>
  bpm >= th.critical ? "critical" : bpm >= th.warning ? "warning" : "normal";

const COLOR: Record<HrState, string> = { normal: theme.normal, warning: theme.warning, critical: theme.critical };
const LABEL: Record<HrState, string> = { normal: "Normal", warning: "Warning", critical: "Critical" };

/** Deterministic simulated WHOOP heart rate, around 80 bpm. */
export const restingHr = (t: number) =>
  80 + 2.2 * Math.sin(1.3 * t) + 1.1 * Math.sin(3.7 * t + 1) + 0.6 * Math.sin(7.9 * t + 2);

const WINDOW = 8; // seconds of history on the trace
const DT = 0.1;
const VW = 600;
const VH = 160;
const MIN = 55;
const MAX = 140;
const yOf = (v: number) => VH - ((v - MIN) / (MAX - MIN)) * VH;

export const HeartRateMonitor: React.FC<{
  t: number;
  hrAt: (t: number) => number;
  thresholds?: Thresholds;
  width?: number;
}> = ({ t, hrAt, thresholds = DEMO_THRESHOLDS, width = 1100 }) => {
  const bpm = hrAt(t);
  const state = stateOf(bpm, thresholds);
  const color = COLOR[state];

  const pts: [number, number][] = [];
  const first = Math.floor((t - WINDOW) / DT) * DT;
  for (let s = first; s <= t + 1e-6; s += DT) {
    pts.push([((s - (t - WINDOW)) / WINDOW) * VW, yOf(hrAt(s))]);
  }
  pts.push([VW, yOf(bpm)]);
  const line = pts.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
  const area = `0,${VH} ${line} ${VW},${VH}`;
  const pulse = 0.5 + 0.5 * Math.sin(t * Math.PI * 2 * (bpm / 60));

  const s = width / 1100;
  return (
    <div
      style={{
        width,
        background: theme.readoutSurface,
        borderRadius: 28 * s,
        padding: `${36 * s}px ${44 * s}px`,
        fontFamily: theme.font,
        color: theme.readoutText,
        boxShadow: `0 30px 90px rgba(0,0,0,0.5), 0 0 0 ${2 * s}px ${state === "normal" ? "rgba(232,234,237,0.06)" : color + "55"}`,
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 12 * s, fontSize: 24 * s, fontWeight: 600, color, textTransform: "uppercase", letterSpacing: 2 * s }}>
          <span style={{ width: 14 * s, height: 14 * s, borderRadius: "50%", background: color, boxShadow: `0 0 ${12 * s * pulse}px ${color}` }} />
          {LABEL[state]}
        </span>
        <span style={{ fontFamily: theme.mono, fontSize: 20 * s, color: theme.readoutMuted }}>WHOOP 4.0 · live</span>
      </div>
      <div style={{ display: "flex", alignItems: "baseline", gap: 24 * s, marginTop: 20 * s }}>
        <span style={{ fontFamily: theme.mono, fontSize: 150 * s, fontWeight: 500, letterSpacing: -4 * s, color: state === "normal" ? theme.readoutText : color, lineHeight: 1 }}>
          {Math.round(bpm)}
        </span>
        <span style={{ fontSize: 30 * s, color: theme.readoutSecondary }}>
          Heart rate <span style={{ color: theme.readoutMuted }}>bpm</span>
        </span>
      </div>
      <p style={{ fontFamily: theme.mono, fontSize: 19 * s, color: theme.readoutMuted, margin: `${14 * s}px 0 ${22 * s}px` }}>
        normal &lt; {thresholds.warning} · warning {thresholds.warning} – {thresholds.critical} · critical ≥ {thresholds.critical} · demo thresholds
      </p>
      <svg viewBox={`0 0 ${VW} ${VH}`} preserveAspectRatio="none" style={{ width: "100%", height: 300 * s, display: "block" }}>
        <defs>
          <linearGradient id="hr-area" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={color} stopOpacity="0.28" />
            <stop offset="1" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <line x1="0" x2={VW} y1={yOf(thresholds.warning)} y2={yOf(thresholds.warning)} stroke={theme.warning} strokeOpacity="0.55" strokeDasharray="6 6" strokeWidth="1" vectorEffect="non-scaling-stroke" />
        <line x1="0" x2={VW} y1={yOf(thresholds.critical)} y2={yOf(thresholds.critical)} stroke={theme.critical} strokeOpacity="0.6" strokeDasharray="6 6" strokeWidth="1" vectorEffect="non-scaling-stroke" />
        <polygon points={area} fill="url(#hr-area)" />
        <polyline points={line} fill="none" stroke={color} strokeWidth="3" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      </svg>
      <div style={{ display: "flex", justifyContent: "space-between", fontFamily: theme.mono, fontSize: 17 * s, color: theme.readoutMuted, marginTop: 8 * s }}>
        <span>−{WINDOW} s</span>
        <span style={{ color: theme.warning }}>warning {thresholds.warning}</span>
        <span style={{ color: theme.critical }}>critical {thresholds.critical}</span>
        <span>now</span>
      </div>
    </div>
  );
};
