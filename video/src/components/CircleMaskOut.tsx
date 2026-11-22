// Inverse circular mask: black closes in from the edges until the frame is black.
import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { ip } from "../anim";

export const CircleMaskOut: React.FC<{ from: number; duration: number; cx?: string; cy?: string }> = ({ from, duration, cx = "50%", cy = "50%" }) => {
  const frame = useCurrentFrame();
  if (frame < from) return null;
  // 1150 px covers the 1920x1080 frame's half-diagonal (~1102 px).
  const r = ip(frame, [from, from + duration], [1150, 0]);
  const bg = r <= 0.5 ? "#000" : `radial-gradient(circle at ${cx} ${cy}, transparent ${r}px, #000 ${r + 1}px)`;
  return <AbsoluteFill style={{ background: bg }} />;
};
