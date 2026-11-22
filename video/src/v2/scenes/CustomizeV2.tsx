// v2 scene "customize" (175 frames): Kevin on a light studio set cycles through
// five looks in ~3 s with pop/morph swaps, then returns to his default look.
import React from "react";
import { AbsoluteFill, Easing, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { JADE, KEVIN, Kevin, KevinLook } from "../../components/Kevin";
import { theme } from "../../theme";
import { Cue, LEVEL, Sfx, SfxName } from "../Sfx";

type Variant = { look: KevinLook; label: string };

const VARIANTS: Variant[] = [
  { look: KEVIN, label: "Orange triangle · Doctor's coat" },
  { look: { shape: "circle", ...JADE, top: "coat" }, label: "Jade circle · Doctor's coat" },
  { look: { shape: "squircle", light: "#C9B6FF", dark: "#6D4AE0", top: "tshirt" }, label: "Violet square · T-shirt" },
  { look: { shape: "triangle", light: "#9ED8FF", dark: "#1E78D2", top: "none" }, label: "Sky triangle" },
  { look: { shape: "circle", light: "#FFB3C7", dark: "#D9467A", top: "tshirt" }, label: "Rose circle · T-shirt" },
  { look: { shape: "squircle", light: "#FFE58A", dark: "#D99A00", top: "coat" }, label: "Sun square · Doctor's coat" },
  { look: KEVIN, label: "Orange triangle · Doctor's coat" },
];

// Swap frames: five variants, then back to the default.
const FIRST_SWAP = 34;
const STEP = 18;
const SWAPS = VARIANTS.slice(1).map((_, i) => FIRST_SWAP + i * STEP); // 34 … 124
const CROSS = 5; // frames the outgoing look takes to shrink away

const GROUND_Y = 800;
const RADIUS = 150;

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

const hexRgb = (hex: string) => {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};
const mixRgb = (a: string, b: string, t: number) => {
  const x = hexRgb(a);
  const y = hexRgb(b);
  return x.map((v, i) => Math.round(v + (y[i] - v) * t));
};

const indexAt = (frame: number) => SWAPS.filter((s) => frame >= s).length;

const TITLE = ["Customize", "Kevin"];

export const CustomizeV2: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const idx = indexAt(frame);
  const swapAt = idx === 0 ? -100 : SWAPS[idx - 1];
  const since = frame - swapAt;
  const cur = VARIANTS[idx];
  const prev = VARIANTS[Math.max(0, idx - 1)];

  // Incoming look pops in with a little overshoot; outgoing one shrinks away.
  const pop = idx === 0 ? 1 : spring({ frame: since, fps, config: { damping: 10, stiffness: 240, mass: 0.7 } });
  const outT = idx === 0 ? 1 : interpolate(since, [0, CROSS], [0, 1], clamp);
  const squash = idx === 0 ? 0 : Math.sin(Math.min(1, since / 10) * Math.PI) * (1 - since / 14);

  // Background tint follows the variant colour.
  const tintT = idx === 0 ? 1 : interpolate(since, [0, 10], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const [tr, tg, tb] = mixRgb(prev.look.dark, cur.look.dark, tintT);

  // Ring burst on each swap.
  const ring = idx === 0 ? 1 : interpolate(since, [0, 16], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });

  // Slow push-in over the whole scene.
  const push = interpolate(frame, [0, 175], [1, 1.03]);

  const cues: Cue[] = SWAPS.map((at, i) => ({ at, name: `swap${i + 1}` as SfxName, volume: LEVEL.ui }));

  const chipIn = spring({ frame: frame - 18, fps, config: { damping: 200 } });

  return (
    <AbsoluteFill style={{ background: "#e9ebee", fontFamily: theme.font, overflow: "hidden" }}>
      {/* Studio set: soft key light from above, darker floor falloff. */}
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 70% 60% at 50% 30%, #ffffff 0%, #f1f2f4 40%, #dcdfe3 100%)" }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 45% 40% at 50% 62%, rgba(${tr},${tg},${tb},0.16) 0%, rgba(${tr},${tg},${tb},0) 100%)` }} />
      <AbsoluteFill style={{ background: "linear-gradient(180deg, transparent 72%, rgba(0,0,0,0.05) 100%)" }} />

      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: "50% 60%" }}>
        {/* Title */}
        <div style={{ position: "absolute", top: 130, width: "100%", textAlign: "center", fontSize: 92, fontWeight: 650, letterSpacing: "-0.025em", color: theme.text }}>
          {TITLE.map((w, i) => {
            const s = spring({ frame: frame - 8 - i * 4, fps, config: { damping: 200 }, durationInFrames: 20 });
            return (
              <span key={w} style={{ display: "inline-block", margin: "0 14px", opacity: s, filter: `blur(${(1 - s) * 12}px)`, transform: `translateY(${(1 - s) * 34}px)` }}>
                {w}
              </span>
            );
          })}
        </div>
        <div
          style={{
            position: "absolute",
            top: 250,
            width: "100%",
            textAlign: "center",
            fontSize: 30,
            fontWeight: 400,
            color: theme.muted,
            letterSpacing: "0.02em",
            opacity: spring({ frame: frame - 18, fps, config: { damping: 200 } }),
          }}
        >
          Shape · Colour · Outfit
        </div>

        {/* Floor shadow, widening slightly with the pop. */}
        <div
          style={{
            position: "absolute",
            left: 960 - 260,
            top: GROUND_Y - 26,
            width: 520,
            height: 52,
            borderRadius: "50%",
            background: "radial-gradient(closest-side, rgba(0,0,0,0.16), rgba(0,0,0,0))",
          }}
        />

        {/* Ring burst */}
        {idx > 0 && ring < 1 ? (
          <div
            style={{
              position: "absolute",
              left: 960 - (120 + ring * 220),
              top: GROUND_Y - 150 - (120 + ring * 220),
              width: 2 * (120 + ring * 220),
              height: 2 * (120 + ring * 220),
              borderRadius: "50%",
              border: `${3 + (1 - ring) * 5}px solid rgba(${tr},${tg},${tb},${0.45 * (1 - ring)})`,
            }}
          />
        ) : null}

        {/* Outgoing look */}
        {idx > 0 && outT < 1 ? (
          <div
            style={{
              position: "absolute",
              inset: 0,
              transformOrigin: `960px ${GROUND_Y}px`,
              transform: `scale(${1 - outT * 0.25})`,
              opacity: 1 - outT,
              filter: `blur(${outT * 6}px)`,
            }}
          >
            <Kevin x={960} y={GROUND_Y} radius={RADIUS} look={prev.look} />
          </div>
        ) : null}

        {/* Current look */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            transformOrigin: `960px ${GROUND_Y}px`,
            transform: `scale(${(0.78 + 0.22 * pop) * (1 + squash * 0.08)}, ${(0.78 + 0.22 * pop) * (1 - squash * 0.08)})`,
            opacity: Math.min(1, pop * 1.5),
          }}
        >
          <Kevin x={960} y={GROUND_Y} radius={RADIUS} look={cur.look} />
        </div>

        {/* Variant label */}
        <div style={{ position: "absolute", top: 860, width: "100%", display: "flex", justifyContent: "center", opacity: chipIn }}>
          <div
            style={{
              position: "relative",
              padding: "14px 30px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.85)",
              boxShadow: "0 8px 28px rgba(0,0,0,0.08), inset 0 0 0 1px rgba(0,0,0,0.04)",
              fontSize: 30,
              fontWeight: 500,
              color: theme.text2,
              display: "flex",
              alignItems: "center",
              gap: 14,
            }}
          >
            <span style={{ width: 16, height: 16, borderRadius: 8, background: `rgb(${tr},${tg},${tb})` }} />
            <span style={{ opacity: idx === 0 ? 1 : interpolate(since, [0, 6], [0.2, 1], clamp) }}>{cur.label}</span>
          </div>
        </div>

        {/* Progress dots for the five variants */}
        <div style={{ position: "absolute", top: 950, width: "100%", display: "flex", justifyContent: "center", gap: 14, opacity: chipIn }}>
          {VARIANTS.slice(1, 6).map((v, i) => {
            const on = idx === i + 1;
            return (
              <div
                key={i}
                style={{
                  width: on ? 34 : 12,
                  height: 12,
                  borderRadius: 6,
                  background: on ? v.look.dark : idx > i + 1 ? "rgba(0,0,0,0.28)" : "rgba(0,0,0,0.12)",
                }}
              />
            );
          })}
        </div>
      </AbsoluteFill>

      <Sfx cues={cues} />
    </AbsoluteFill>
  );
};
