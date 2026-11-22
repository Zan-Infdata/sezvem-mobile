// Finishing layer over the whole film: soft vignette and fine animated grain.
import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";

export const FilmLook: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 50%, transparent 55%, rgba(0,0,0,0.38) 100%)" }} />
      <svg width="100%" height="100%" style={{ position: "absolute", inset: 0, opacity: 0.07, mixBlendMode: "overlay" }}>
        <filter id="grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed={frame % 12} stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#grain)" />
      </svg>
    </AbsoluteFill>
  );
};

/** Studio backdrop for phone scenes: deep gradient with a soft brand glow behind the device. */
export const StageBackdrop: React.FC<{ glow?: string }> = ({ glow = "rgba(30,158,106,0.22)" }) => (
  <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, #1a2027 0%, #0b0d10 55%, #050607 100%)" }}>
    <AbsoluteFill style={{ background: `radial-gradient(circle at 50% 48%, ${glow} 0%, transparent 38%)` }} />
    <AbsoluteFill style={{ background: "linear-gradient(180deg, transparent 70%, rgba(255,255,255,0.025) 100%)" }} />
  </AbsoluteFill>
);
