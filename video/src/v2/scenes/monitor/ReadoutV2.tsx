// v2 readout after the reference div.readout: dark surface, status word,
// big mono figure, bounds line and a live trace coloured per reading.
import React from "react";
import { theme } from "../../../theme";
import { beatPulse, hrAt, State, stateAt, THRESHOLDS } from "./sim";

const COLOR: Record<State, string> = { normal: theme.normal, warning: theme.warning, critical: theme.critical };
const LABEL: Record<State, string> = { normal: "Normal", warning: "Warning", critical: "Critical" };

const WINDOW = 8;
const DT = 0.1;
const VW = 600;
const VH = 160;
const MIN = 55;
const MAX = 135;
const yOf = (v: number) => VH - ((v - MIN) / (MAX - MIN)) * VH;

export const ReadoutV2: React.FC<{ t: number; flash: number; flashColor: string; width?: number }> = ({
  t,
  flash,
  flashColor,
  width = 1180,
}) => {
  const bpm = hrAt(t);
  const state = stateAt(t);
  const color = COLOR[state];
  const pulse = beatPulse(t);
  const s = width / 1100;

  // Trace points on a fixed time grid so the line scrolls smoothly.
  const pts: { x: number; y: number; st: State }[] = [];
  const first = Math.floor((t - WINDOW) / DT) * DT;
  for (let k = 0; ; k++) {
    const ts = first + k * DT;
    if (ts > t) break;
    pts.push({ x: ((ts - (t - WINDOW)) / WINDOW) * VW, y: yOf(hrAt(ts)), st: stateAt(ts) });
  }
  pts.push({ x: VW, y: yOf(bpm), st: state });
  // Split into runs of the same state; each run starts at the previous run's last point.
  const runs: { st: State; pts: typeof pts }[] = [];
  for (const p of pts) {
    const last = runs[runs.length - 1];
    if (!last || last.st !== p.st) runs.push({ st: p.st, pts: last ? [last.pts[last.pts.length - 1], p] : [p] });
    else last.pts.push(p);
  }
  const line = pts.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ");
  const area = `0,${VH} ${line} ${VW},${VH}`;
  const end = pts[pts.length - 1];

  const mean = Math.round(hrAt(t - 2) * 0.5 + hrAt(t - 4) * 0.5);
  const ring = state === "normal" ? "rgba(232,234,237,0.07)" : `${color}66`;

  return (
    <div
      style={{
        width,
        background: `linear-gradient(180deg, #1a1e23 0%, ${theme.readoutSurface} 40%)`,
        borderRadius: 30 * s,
        padding: `${38 * s}px ${46 * s}px ${30 * s}px`,
        fontFamily: theme.font,
        color: theme.readoutText,
        boxShadow: [
          `0 40px 120px rgba(0,0,0,0.6)`,
          `0 0 0 ${1.5 * s}px ${ring}`,
          `0 0 ${(60 + 40 * pulse) * s}px ${state === "normal" ? "rgba(74,222,128,0.05)" : color + "22"}`,
          flash > 0 ? `0 0 0 ${(2 + 26 * (1 - flash)) * s}px ${flashColor}${Math.round(flash * 120).toString(16).padStart(2, "0")}` : "",
        ]
          .filter(Boolean)
          .join(", "),
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 14 * s, fontSize: 23 * s, fontWeight: 600, color, textTransform: "uppercase", letterSpacing: 2.5 * s }}>
          <span style={{ position: "relative", width: 14 * s, height: 14 * s }}>
            <span style={{ position: "absolute", inset: 0, borderRadius: "50%", background: color, transform: `scale(${1 + 0.25 * pulse})`, boxShadow: `0 0 ${18 * s * pulse}px ${color}` }} />
            <span style={{ position: "absolute", inset: 0, borderRadius: "50%", border: `${2 * s}px solid ${color}`, transform: `scale(${1 + 2.2 * (1 - pulse)})`, opacity: pulse * 0.6 }} />
          </span>
          {LABEL[state]}
        </span>
        <span style={{ fontFamily: theme.mono, fontSize: 19 * s, color: theme.readoutMuted }}>WHOOP 4.0 · live · updated now</span>
      </div>
      <div style={{ display: "flex", alignItems: "baseline", gap: 26 * s, marginTop: 18 * s }}>
        <span style={{ fontFamily: theme.mono, fontSize: 160 * s, fontWeight: 500, letterSpacing: -6 * s, color: state === "normal" ? theme.readoutText : color, lineHeight: 1, fontVariantNumeric: "tabular-nums" }}>
          {Math.round(bpm)}
        </span>
        <span style={{ fontSize: 30 * s, color: theme.readoutSecondary }}>
          Heart rate <span style={{ color: theme.readoutMuted }}>bpm</span>
        </span>
      </div>
      <p style={{ fontFamily: theme.mono, fontSize: 18 * s, color: theme.readoutMuted, margin: `${14 * s}px 0 ${20 * s}px` }}>
        normal &lt; {THRESHOLDS.warning} · warning {THRESHOLDS.warning} – {THRESHOLDS.critical} · critical ≥ {THRESHOLDS.critical} · demo thresholds
      </p>
      <div style={{ position: "relative" }}>
        <svg viewBox={`0 0 ${VW} ${VH}`} preserveAspectRatio="none" style={{ width: "100%", height: 290 * s, display: "block", overflow: "visible" }}>
          <defs>
            <linearGradient id="hr2-area" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor={color} stopOpacity="0.26" />
              <stop offset="1" stopColor={color} stopOpacity="0" />
            </linearGradient>
          </defs>
          {[70, 85, 130].map((v) => (
            <line key={v} x1="0" x2={VW} y1={yOf(v)} y2={yOf(v)} stroke="rgba(232,234,237,0.05)" strokeWidth="1" vectorEffect="non-scaling-stroke" />
          ))}
          <line x1="0" x2={VW} y1={yOf(THRESHOLDS.warning)} y2={yOf(THRESHOLDS.warning)} stroke={theme.warning} strokeOpacity="0.5" strokeDasharray="5 7" strokeWidth="1.2" vectorEffect="non-scaling-stroke" />
          <line x1="0" x2={VW} y1={yOf(THRESHOLDS.critical)} y2={yOf(THRESHOLDS.critical)} stroke={theme.critical} strokeOpacity="0.55" strokeDasharray="5 7" strokeWidth="1.2" vectorEffect="non-scaling-stroke" />
          <polygon points={area} fill="url(#hr2-area)" />
          {runs.map((r, i) => (
            <polyline
              key={i}
              points={r.pts.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ")}
              fill="none"
              stroke={COLOR[r.st]}
              strokeWidth="3.2"
              strokeLinejoin="round"
              strokeLinecap="round"
              vectorEffect="non-scaling-stroke"
            />
          ))}
        </svg>
        {/* Leading point: drawn in HTML so it stays round despite the stretched SVG. */}
        <div
          style={{
            position: "absolute",
            left: `calc(100% - ${8 * s}px)`,
            top: (end.y / VH) * 290 * s - 8 * s,
            width: 16 * s,
            height: 16 * s,
            borderRadius: "50%",
            background: color,
            boxShadow: `0 0 ${(10 + 22 * pulse) * s}px ${color}`,
          }}
        />
        <span style={{ position: "absolute", left: 0, top: (yOf(THRESHOLDS.warning) / VH) * 290 * s - 26 * s, fontFamily: theme.mono, fontSize: 15 * s, color: theme.warning, opacity: 0.8 }}>
          warning {THRESHOLDS.warning}
        </span>
        <span style={{ position: "absolute", left: 0, top: (yOf(THRESHOLDS.critical) / VH) * 290 * s - 26 * s, fontFamily: theme.mono, fontSize: 15 * s, color: theme.critical, opacity: 0.85 }}>
          critical {THRESHOLDS.critical}
        </span>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", fontFamily: theme.mono, fontSize: 16 * s, color: theme.readoutMuted, marginTop: 8 * s }}>
        <span>−{WINDOW} s</span>
        <span>now</span>
      </div>
      <div style={{ display: "flex", gap: 56 * s, marginTop: 22 * s, paddingTop: 20 * s, borderTop: `1px solid rgba(232,234,237,0.08)` }}>
        {[
          ["Mean heart rate", `${mean} bpm`],
          ["Resting heart rate", "58 bpm"],
          ["Source", "WHOOP 4.0"],
        ].map(([k, v]) => (
          <div key={k} style={{ display: "flex", flexDirection: "column", gap: 4 * s }}>
            <span style={{ fontSize: 16 * s, color: theme.readoutMuted }}>{k}</span>
            <span style={{ fontFamily: theme.mono, fontSize: 22 * s, color: theme.readoutSecondary }}>{v}</span>
          </div>
        ))}
      </div>
    </div>
  );
};
