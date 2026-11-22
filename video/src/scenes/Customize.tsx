// Customize Kevin: five quick variants on a light studio set, ending on the default.
import React from "react";
import { AbsoluteFill, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { ip } from "../anim";
import { JADE, KEVIN, Kevin, KevinLook } from "../components/Kevin";
import { theme } from "../theme";

export const VARIANTS: { look: KevinLook; label: string }[] = [
  { look: KEVIN, label: "Orange triangle · Doctor's coat" },
  { look: { shape: "circle", ...JADE, top: "coat" }, label: "Jade circle · Doctor's coat" },
  { look: { shape: "squircle", light: "#C9B6FF", dark: "#6D4AE0", top: "tshirt" }, label: "Violet rounded square · T-shirt" },
  { look: { shape: "triangle", light: "#9ED8FF", dark: "#1E78D2", top: "none" }, label: "Sky triangle" },
  { look: { shape: "circle", light: "#FFB3C7", dark: "#D9467A", top: "tshirt" }, label: "Rose circle · T-shirt" },
  { look: { shape: "squircle", light: "#FFE58A", dark: "#E0A800", top: "coat" }, label: "Sun rounded square · Doctor's coat" },
  { look: KEVIN, label: "Orange triangle · Doctor's coat" },
];
const START = 26;
const STEP = 20; // five swaps plus the return to default in 4 s

export const Customize: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const idx = Math.max(0, Math.min(VARIANTS.length - 1, Math.floor((frame - START) / STEP) + 1));
  const since = frame - (START + (idx - 1) * STEP);
  const pop = idx === 0 ? 1 : spring({ frame: since, fps, config: { damping: 11, stiffness: 220 } });
  const title = spring({ frame, fps, config: { damping: 200 } });
  const v = VARIANTS[idx];
  return (
    <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 35%, #ffffff 0%, #eceef1 45%, #d9dce1 100%)", fontFamily: theme.font, opacity: ip(frame, [138, 150], [1, 0]) }}>
      <div style={{ position: "absolute", top: 120, width: "100%", textAlign: "center", fontSize: 84, fontWeight: 650, letterSpacing: -2, color: theme.text, opacity: title, transform: `translateY(${(1 - title) * 20}px)` }}>
        Customize Kevin
      </div>
      <div style={{ position: "absolute", left: 760, top: 830, width: 400, height: 40, borderRadius: "50%", background: "radial-gradient(closest-side, rgba(0,0,0,0.12), transparent)" }} />
      <div style={{ position: "absolute", inset: 0, transformOrigin: "960px 840px", transform: `scale(${0.82 + 0.18 * pop}, ${1.12 - 0.12 * pop})` }}>
        <Kevin x={960} y={840} radius={150} look={v.look} />
      </div>
      <div style={{ position: "absolute", top: 900, width: "100%", display: "flex", justifyContent: "center" }}>
        <div style={{ padding: "12px 26px", borderRadius: 999, background: "rgba(255,255,255,0.8)", boxShadow: "0 6px 20px rgba(0,0,0,0.08)", fontSize: 30, color: theme.text2, fontWeight: 500 }}>
          {v.label}
        </div>
      </div>
      <div style={{ position: "absolute", top: 975, width: "100%", display: "flex", justifyContent: "center", gap: 12 }}>
        {VARIANTS.slice(1, 6).map((_, i) => (
          <div key={i} style={{ width: 12, height: 12, borderRadius: 6, background: idx === i + 1 ? theme.brand : "rgba(0,0,0,0.15)" }} />
        ))}
      </div>
    </AbsoluteFill>
  );
};
