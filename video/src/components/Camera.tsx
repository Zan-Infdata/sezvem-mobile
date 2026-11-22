// Virtual camera: x/y is the stage point brought to the frame centre.
import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";
import { W, H } from "../theme";

export type CamKey = { at: number; x: number; y: number; zoom: number };

export const WIDE: Omit<CamKey, "at"> = { x: W / 2, y: H / 2, zoom: 1 };

/** Camera position at `frame`: eased moves between keyframes, holding in between. */
export function cameraAt(frame: number, keys: CamKey[]) {
  if (keys.length === 1) return keys[0];
  const opts = {
    extrapolateLeft: "clamp" as const,
    extrapolateRight: "clamp" as const,
    easing: Easing.inOut(Easing.cubic),
  };
  const at = keys.map((k) => k.at);
  // Zoom eases in log space so in and out feel equally fast.
  return {
    at: frame,
    x: interpolate(frame, at, keys.map((k) => k.x), opts),
    y: interpolate(frame, at, keys.map((k) => k.y), opts),
    zoom: Math.exp(interpolate(frame, at, keys.map((k) => Math.log(k.zoom)), opts)),
  };
}

export const Camera: React.FC<{ keys?: CamKey[]; view?: { x: number; y: number; zoom: number }; children: React.ReactNode }> = ({
  keys,
  view,
  children,
}) => {
  const frame = useCurrentFrame();
  const c = view ?? cameraAt(frame, keys ?? [{ at: 0, ...WIDE }]);
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          width: W,
          height: H,
          transformOrigin: "0 0",
          transform: `translate(${W / 2 - c.x * c.zoom}px, ${H / 2 - c.y * c.zoom}px) scale(${c.zoom})`,
        }}
      >
        {children}
      </div>
    </div>
  );
};
