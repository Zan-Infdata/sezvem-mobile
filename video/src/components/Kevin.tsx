// Kevin: the IXland companion's Bot style, ported from
// mobile/lib/companion/styles/bot/ (bot_style.dart, bot_shapes.dart,
// bot_outfit.dart). Same shapes, colours, eye model and faces; drawn as SVG.
import React, { useId } from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";

export type Emotion =
  | "resting"
  | "walking"
  | "confused"
  | "scared"
  | "laughing"
  | "happy"
  | "surprised"
  | "typing";

export type ShapeId = "triangle" | "circle" | "squircle";
export type TopId = "coat" | "tshirt" | "none";

export type KevinLook = {
  shape: ShapeId;
  light: string;
  dark: string;
  edge?: string;
  top: TopId;
};

// The app's two body colourings, plus the default Kevin look.
export const ORANGE = { light: "#FFCC80", dark: "#EF6C00" };
export const JADE = { light: "#7ADCC4", dark: "#14917D", edge: "#0B5E54" };
export const KEVIN: KevinLook = { shape: "triangle", ...ORANGE, top: "coat" };

export type MoodKey = { at: number; emotion: Emotion };

type Eye = { w: number; h: number; tilt: number; smile: number };
type Face = { l: Eye; r: Eye; split: number; yaw: number; pitch: number; roll: number };

const eye = (w: number, h: number, tilt = 0, smile = 0): Eye => ({ w, h, tilt, smile });
const both = (e: Eye, split: number, yaw: number, pitch: number, roll: number): Face => ({
  l: e,
  r: e,
  split,
  yaw,
  pitch,
  roll,
});

// Faces copied from _Face in bot_style.dart.
const FACES: Record<Emotion, Face> = {
  resting: both(eye(0.21, 0.44), 16, 4, 5, -4),
  walking: both(eye(0.21, 0.44), 16, 34, 18, -8),
  surprised: both(eye(0.45, 0.47), 19, 3, -3, 0),
  laughing: both(eye(0.4, 0.275, 10, 1), 18, 4, 16, 0),
  scared: both(eye(0.45, 0.47), 20.5, -10, -6, 0),
  confused: {
    l: eye(0.2, 0.44, -18),
    r: eye(0.28, 0.17, 14),
    split: 16.5,
    yaw: -14,
    pitch: 3,
    roll: 8,
  },
  happy: both(eye(0.34, 0.4, 0, 0.85), 17, 8, 12, 0),
  // Looking down at the keyboard.
  typing: both(eye(0.22, 0.36), 16, 10, -14, 0),
};

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const lerpEye = (a: Eye, b: Eye, t: number): Eye => ({
  w: lerp(a.w, b.w, t),
  h: lerp(a.h, b.h, t),
  tilt: lerp(a.tilt, b.tilt, t),
  smile: lerp(a.smile, b.smile, t),
});
const lerpFace = (a: Face, b: Face, t: number): Face => ({
  l: lerpEye(a.l, b.l, t),
  r: lerpEye(a.r, b.r, t),
  split: lerp(a.split, b.split, t),
  yaw: lerp(a.yaw, b.yaw, t),
  pitch: lerp(a.pitch, b.pitch, t),
  roll: lerp(a.roll, b.roll, t),
});
const rad = (d: number) => (d * Math.PI) / 180;

// ---- Shapes (bot_shapes.dart) ----
const CORE = 0.78;
const ROUNDING = 0.34;
const CORNER_ANGLES = [0, 1, 2].map((i) => -Math.PI / 2 + (i * 2 * Math.PI) / 3);
const CORNERS = CORNER_ANGLES.map((a) => [Math.cos(a) * CORE, Math.sin(a) * CORE]);

function distanceToCore(px: number, py: number) {
  let outside = false;
  let nearest = Infinity;
  for (let i = 0; i < 3; i++) {
    const [ax, ay] = CORNERS[i];
    const [bx, by] = CORNERS[(i + 1) % 3];
    const ex = bx - ax;
    const ey = by - ay;
    if (ex * (py - ay) - ey * (px - ax) < 0) outside = true;
    const t = Math.min(1, Math.max(0, ((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey)));
    nearest = Math.min(nearest, Math.hypot(px - (ax + ex * t), py - (ay + ey * t)));
  }
  return outside ? nearest : 0;
}

type ShapeSpec = {
  bottom: number;
  neckY: number;
  shadowWidth: number;
  radiusAt: (angle: number) => number;
  outline: (r: number) => string;
};

const SQ_N = 4;
const SQ_SIZE = 0.9;
const squircleR = (a: number) =>
  SQ_SIZE / Math.pow(Math.pow(Math.abs(Math.cos(a)), SQ_N) + Math.pow(Math.abs(Math.sin(a)), SQ_N), 1 / SQ_N);

const SHAPES: Record<ShapeId, ShapeSpec> = {
  circle: {
    bottom: 1,
    neckY: 0.45,
    shadowWidth: 1.6,
    radiusAt: () => 1,
    outline: (r) => `M ${-r} 0 A ${r} ${r} 0 1 1 ${r} 0 A ${r} ${r} 0 1 1 ${-r} 0 Z`,
  },
  triangle: {
    bottom: CORE / 2 + ROUNDING,
    neckY: 0.2,
    shadowWidth: 1.7,
    radiusAt: (angle) => {
      const dx = Math.cos(angle);
      const dy = Math.sin(angle);
      let inside = 0;
      let out = CORE + ROUNDING;
      for (let i = 0; i < 24; i++) {
        const m = (inside + out) / 2;
        if (distanceToCore(dx * m, dy * m) <= ROUNDING) inside = m;
        else out = m;
      }
      return inside;
    },
    outline: (r) => {
      const rr = ROUNDING * r;
      let d = "";
      for (let i = 0; i < 3; i++) {
        const cx = CORNERS[i][0] * r;
        const cy = CORNERS[i][1] * r;
        const a0 = CORNER_ANGLES[i] - Math.PI / 3;
        const a1 = CORNER_ANGLES[i] + Math.PI / 3;
        const sx = cx + Math.cos(a0) * rr;
        const sy = cy + Math.sin(a0) * rr;
        const ex = cx + Math.cos(a1) * rr;
        const ey = cy + Math.sin(a1) * rr;
        d += `${i === 0 ? "M" : "L"} ${sx} ${sy} A ${rr} ${rr} 0 0 1 ${ex} ${ey} `;
      }
      return d + "Z";
    },
  },
  // A soft rounded square, an extra shape for the customization showcase.
  squircle: {
    bottom: SQ_SIZE,
    neckY: 0.32,
    shadowWidth: 1.7,
    radiusAt: squircleR,
    outline: (r) => {
      const pts: string[] = [];
      for (let i = 0; i < 72; i++) {
        const a = (i / 72) * Math.PI * 2;
        const k = squircleR(a) * r;
        pts.push(`${(Math.cos(a) * k).toFixed(2)} ${(Math.sin(a) * k).toFixed(2)}`);
      }
      return `M ${pts.join(" L ")} Z`;
    },
  },
};

// ---- Colour helpers ----
function hexToRgb(hex: string) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function mix(hex: string, toward: string, t: number) {
  const a = hexToRgb(hex);
  const b = hexToRgb(toward);
  const c = a.map((v, i) => Math.round(lerp(v, b[i], t)));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}

// ---- Mood timeline ----
const BLEND_FRAMES = 6;

function moodAt(moods: MoodKey[], frame: number, walking: boolean) {
  const base: Emotion = walking ? "walking" : "resting";
  let idx = -1;
  for (let i = 0; i < moods.length; i++) if (moods[i].at <= frame) idx = i;
  const cur = idx >= 0 ? moods[idx].emotion : base;
  const prev = idx > 0 ? moods[idx - 1].emotion : base;
  const since = idx >= 0 ? frame - moods[idx].at : 999;
  const t = Math.min(1, since / BLEND_FRAMES);
  const resolve = (e: Emotion) => (e === "resting" && walking ? "walking" : e);
  return { cur: resolve(cur), prev: resolve(prev), t, since };
}

type Motion = { lift: number; rot: number; dx: number; sx: number; sy: number };
const NONE: Motion = { lift: 0, rot: 0, dx: 0, sx: 1, sy: 1 };

// Body motion per emotion, after EmotionMotion in companion_emotion.dart.
function motionOf(e: Emotion, sec: number): Motion {
  switch (e) {
    case "laughing":
      return {
        lift: Math.abs(Math.sin(sec * Math.PI * 4.4)) * 0.2,
        rot: Math.sin(sec * Math.PI * 2.2) * 0.07,
        dx: 0,
        sx: 1 + Math.sin(sec * Math.PI * 8.8) * 0.03,
        sy: 1 - Math.sin(sec * Math.PI * 8.8) * 0.03,
      };
    case "scared":
      return { lift: 0, rot: 0, dx: Math.sin(sec * Math.PI * 18) * 0.025, sx: 0.95, sy: 1.04 };
    case "confused":
      return { lift: 0, rot: 0.12 + Math.sin(sec * Math.PI * 1.6) * 0.03, dx: 0, sx: 1, sy: 1 };
    case "surprised":
      return { lift: Math.max(0, Math.sin(Math.min(1, sec * 3) * Math.PI)) * 0.35, rot: 0, dx: 0, sx: 0.94, sy: 1.08 };
    case "typing":
      return { lift: Math.abs(Math.sin(sec * Math.PI * 8)) * 0.03, rot: 0.03, dx: 0, sx: 1, sy: 1 };
    default:
      return NONE;
  }
}
const lerpMotion = (a: Motion, b: Motion, t: number): Motion => ({
  lift: lerp(a.lift, b.lift, t),
  rot: lerp(a.rot, b.rot, t),
  dx: lerp(a.dx, b.dx, t),
  sx: lerp(a.sx, b.sx, t),
  sy: lerp(a.sy, b.sy, t),
});

export type KevinProps = {
  /** Ground point (between the feet) in the parent's coordinates. */
  x: number;
  y: number;
  radius: number;
  look?: KevinLook;
  moods?: MoodKey[];
  walking?: boolean;
  facing?: 1 | -1;
  /** Frames to offset the idle/walk/blink cycles, so several Kevins differ. */
  phase?: number;
  style?: React.CSSProperties;
};

export const Kevin: React.FC<KevinProps> = ({
  x,
  y,
  radius: R,
  look = KEVIN,
  moods = [],
  walking = false,
  facing = 1,
  phase = 0,
  style,
}) => {
  const frame = useCurrentFrame() + phase;
  const { fps } = useVideoConfig();
  const uid = useId().replace(/:/g, "");
  const shape = SHAPES[look.shape];
  const dir = facing;

  const mood = moodAt(moods, frame - phase, walking);
  const emotionSec = mood.since / fps;
  const scared = (mood.cur === "scared" ? mood.t : 0) + (mood.prev === "scared" ? 1 - mood.t : 0);

  // idle and walk: bob, and sway while walking.
  const walkPhase = frame / 18;
  const idlePhase = frame / 75;
  const bob = walking ? Math.abs(Math.sin(walkPhase * 2 * Math.PI)) : (Math.sin(idlePhase * 2 * Math.PI) + 1) / 2;
  const tilt = walking ? Math.sin(walkPhase * 2 * Math.PI) * 0.08 : 0;
  const motion = lerpMotion(motionOf(mood.prev, emotionSec + 1), motionOf(mood.cur, emotionSec), mood.t);

  const feet = shape.bottom * R;
  const lift = bob * R * 0.18 + motion.lift * R;
  const shadow = 1 - Math.min(0.7, Math.max(0, motion.lift));

  // Blink every ~3.3 s.
  const bt = frame % 100;
  const blink = bt < 6 ? Math.sin((bt / 6) * Math.PI) : 0;

  // Face: resting/walking blended with the running emotion, plus a wandering gaze.
  let face = lerpFace(FACES[mood.prev], FACES[mood.cur], mood.t);
  const wander = walking ? 0 : 2 * Math.PI * idlePhase;
  const dart = scared * Math.sin(2 * Math.PI * emotionSec * 1.5) * 5;
  face = {
    ...face,
    yaw: (face.yaw + Math.sin(wander) * 4 + dart) * dir,
    pitch: face.pitch + Math.cos(wander) * 3,
    roll: face.roll * dir,
  };

  // Eye model from _eyes(): eyes on a sphere pushed out to the outline.
  const yaw = rad(face.yaw);
  const pitch = rad(face.pitch);
  const roll = rad(face.roll);
  type V = [number, number, number];
  const add = (a: V, b: V): V => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const mul = (a: V, k: number): V => [a[0] * k, a[1] * k, a[2] * k];
  let forward: V = [Math.sin(yaw), 0, Math.cos(yaw)];
  let right: V = [Math.cos(yaw), 0, -Math.sin(yaw)];
  let down: V = [0, 1, 0];
  [forward, down] = [
    add(mul(forward, Math.cos(pitch)), mul(down, -Math.sin(pitch))),
    add(mul(down, Math.cos(pitch)), mul(forward, Math.sin(pitch))),
  ];
  [right, down] = [
    add(mul(right, Math.cos(roll)), mul(down, Math.sin(roll))),
    add(mul(down, Math.cos(roll)), mul(right, -Math.sin(roll))),
  ];

  type EyeDraw = { matrix: string; rot: number; w: number; h: number; smile: number; bottom: number; key: string };
  const eyes: EyeDraw[] = [];
  for (const side of [-1, 1]) {
    const e = side < 0 ? face.l : face.r;
    const split = rad(face.split * side);
    const normal = add(mul(forward, Math.cos(split)), mul(right, Math.sin(split)));
    if (normal[2] <= 0.05) continue;
    const across = add(mul(right, Math.cos(split)), mul(forward, -Math.sin(split)));
    const w = e.w * R;
    const h = Math.max(e.h * R * (1 - blink * 0.9), R * 0.02);
    const angle = rad(e.tilt * -side);
    const reach = R * shape.radiusAt(Math.atan2(normal[1], normal[0]));
    const shake = scared * Math.sin(emotionSec * Math.PI * 22 + side) * 0.02 * R;
    const tx = normal[0] * reach + shake;
    const ty = normal[1] * reach;
    // Lowest transformed corner, for the neckline clearance.
    let bottom = -Infinity;
    for (const [cx, cy] of [
      [-w / 2, -h / 2],
      [w / 2, -h / 2],
      [w / 2, h / 2],
      [-w / 2, h / 2],
    ]) {
      const rx = cx * Math.cos(angle) - cy * Math.sin(angle);
      const ry = cx * Math.sin(angle) + cy * Math.cos(angle);
      bottom = Math.max(bottom, across[1] * rx + down[1] * ry + ty);
    }
    eyes.push({
      matrix: `matrix(${across[0]} ${across[1]} ${down[0]} ${down[1]} ${tx} ${ty})`,
      rot: (angle * 180) / Math.PI,
      w,
      h,
      smile: e.smile,
      bottom,
      key: String(side),
    });
  }
  // White eyes vanish on a white coat: push them above the neckline.
  let eyeShift = 0;
  if (look.top !== "none" && eyes.length) {
    const limit = (shape.neckY - 0.18) * R;
    const overlap = Math.max(...eyes.map((e) => e.bottom)) - limit;
    if (overlap > 0) eyeShift = -overlap;
  }

  const outline = shape.outline(R);
  const light = mix(look.light, "#ffffff", scared * 0.15);
  const dark = mix(look.dark, "#ffffff", scared * 0.15);
  const edge = look.edge ? mix(look.edge, "#ffffff", scared * 0.15) : null;
  const neck = shape.neckY * R;

  const W = R * 4.4;
  const H = R * 4.4;
  const body = `translate(0 ${-feet - lift}) translate(0 ${feet}) rotate(${((tilt + motion.rot) * dir * 180) / Math.PI}) scale(${
    motion.sx
  } ${motion.sy}) translate(${motion.dx * R} 0) translate(0 ${-feet})`;

  return (
    <svg
      width={W}
      height={H}
      viewBox={`${-W / 2} ${-H + R * 0.6} ${W} ${H}`}
      style={{ position: "absolute", left: x - W / 2, top: y - H + R * 0.6, overflow: "visible", ...style }}
    >
      <defs>
        <radialGradient id={`g${uid}`} cx="0.325" cy="0.275" r="0.8">
          <stop offset="0" stopColor={light} />
          <stop offset={edge ? 0.72 : 1} stopColor={dark} />
          {edge ? <stop offset="1" stopColor={edge} /> : null}
        </radialGradient>
        <clipPath id={`c${uid}`}>
          <path d={outline} />
        </clipPath>
      </defs>
      <ellipse
        cx={0}
        cy={0}
        rx={(R * shape.shadowWidth * (1 - bob * 0.15) * shadow) / 2}
        ry={(R * 0.28 * shadow) / 2}
        fill="rgba(0,0,0,0.2)"
      />
      <g transform={body}>
        <path d={outline} fill={`url(#g${uid})`} />
        {look.top === "coat" ? <Coat r={R} neck={neck} dir={dir} clip={`c${uid}`} /> : null}
        {look.top === "tshirt" ? <TShirt r={R} neck={neck} clip={`c${uid}`} /> : null}
        <g transform={`translate(0 ${eyeShift})`}>
          {eyes.map((e) => (
            <g key={e.key} transform={e.matrix}>
              <g transform={`rotate(${e.rot})`}>
                {e.smile > 0.01 ? (
                  <mask id={`m${uid}${e.key}`} maskUnits="userSpaceOnUse" x={-R} y={-R} width={2 * R} height={2 * R}>
                    <rect x={-R} y={-R} width={2 * R} height={2 * R} fill="white" />
                    <ellipse cx={0} cy={e.h * (1.5 - e.smile * 0.8)} rx={(e.w * 1.3) / 2} ry={(e.h * 1.2) / 2} fill="black" />
                  </mask>
                ) : null}
                <rect
                  x={-e.w / 2}
                  y={-e.h / 2}
                  width={e.w}
                  height={e.h}
                  rx={Math.min(e.w, e.h) / 2}
                  fill="#ffffff"
                  mask={e.smile > 0.01 ? `url(#m${uid}${e.key})` : undefined}
                />
              </g>
            </g>
          ))}
        </g>
      </g>
    </svg>
  );
};

// White doctor's coat with lapels, pen and stethoscope (DoctorsCoat).
const Coat: React.FC<{ r: number; neck: number; dir: number; clip: string }> = ({ r, neck, dir, clip }) => {
  const top = neck - r * 0.06;
  const seam = { stroke: "#B0BEC5", strokeWidth: r * 0.05, strokeLinecap: "round" as const, fill: "none" };
  const pocketX = dir * r * 0.42;
  const pocketY = top + r * 0.2;
  const side = -dir;
  const tube = { stroke: "#455A64", strokeWidth: r * 0.06, strokeLinecap: "round" as const, fill: "none" };
  return (
    <>
      <g clipPath={`url(#${clip})`}>
        <rect x={-2 * r} y={top} width={4 * r} height={2 * r} fill="#FAFAFA" />
        <path d={`M ${-r * 0.22} ${top} L 0 ${top + r * 0.32} L ${r * 0.22} ${top} Z`} fill="#80DEEA" />
        <line x1={-r * 0.22} y1={top} x2={0} y2={top + r * 0.32} {...seam} />
        <line x1={r * 0.22} y1={top} x2={0} y2={top + r * 0.32} {...seam} />
        <line x1={0} y1={top + r * 0.32} x2={0} y2={2 * r} {...seam} />
        <line
          x1={pocketX}
          y1={pocketY - r * 0.08}
          x2={pocketX}
          y2={pocketY + r * 0.06}
          stroke="#1E88E5"
          strokeWidth={r * 0.06}
          strokeLinecap="round"
        />
        <rect x={pocketX - r * 0.12} y={pocketY + r * 0.02} width={r * 0.24} height={r * 0.16} {...seam} />
      </g>
      <path d={`M ${-r * 0.3} ${top - r * 0.02} Q 0 ${top + r * 0.16} ${r * 0.3} ${top - r * 0.02}`} {...tube} />
      <path
        d={`M ${side * r * 0.3} ${top - r * 0.02} Q ${side * r * 0.42} ${top + r * 0.18} ${side * r * 0.32} ${top + r * 0.36}`}
        {...tube}
      />
      <circle cx={side * r * 0.32} cy={top + r * 0.36} r={r * 0.07} fill="#90A4AE" />
    </>
  );
};

const TShirt: React.FC<{ r: number; neck: number; clip: string }> = ({ r, neck, clip }) => {
  const stripes: number[] = [];
  for (let y = neck + r * 0.16; y < r; y += r * 0.2) stripes.push(y);
  return (
    <>
      <g clipPath={`url(#${clip})`}>
        <rect x={-2 * r} y={neck} width={4 * r} height={2 * r} fill="#42A5F5" />
        {stripes.map((y) => (
          <rect key={y} x={-2 * r} y={y} width={4 * r} height={r * 0.07} fill="#90CAF9" />
        ))}
      </g>
      <path d={`M ${-r * 0.16} ${neck} L 0 ${neck + r * 0.16} L ${r * 0.16} ${neck} Z`} fill="#ffffff" />
    </>
  );
};
